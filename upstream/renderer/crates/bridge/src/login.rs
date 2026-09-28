use std::{
    sync::{Arc, Mutex, PoisonError},
    time::{Duration, Instant},
};

use objc2_foundation::NSBundle;
use objc2_service_management::{SMAppService, SMAppServiceStatus};

use crate::api::BridgeError;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum LaunchAtLoginStatus {
    Available { enabled: bool },
    Unavailable,
}

/// How long a status read stays current.
///
/// Every snapshot the bridge returns carries the status, and reading it is a
/// round trip to the system's service manager that costs far more than the
/// rest of a snapshot. Read per snapshot, it held every queued bridge request
/// behind it. The status changes through `set_enabled`, which records its own
/// result, or in System Settings, which a read this recent still reflects.
const STATUS_FRESHNESS: Duration = Duration::from_secs(2);

#[derive(Clone)]
pub struct LaunchAtLoginController {
    implementation: Arc<dyn LaunchAtLoginImpl>,
    /// The last status read and when it was taken, shared by every clone.
    last_read: Arc<Mutex<Option<(Instant, LaunchAtLoginStatus)>>>,
}

trait LaunchAtLoginImpl: Send + Sync {
    fn status(&self) -> Result<LaunchAtLoginStatus, BridgeError>;
    fn set_enabled(&self, enabled: bool) -> Result<LaunchAtLoginStatus, BridgeError>;
}

impl Default for LaunchAtLoginController {
    fn default() -> Self {
        Self::new(Arc::new(SystemLaunchAtLogin))
    }
}

impl LaunchAtLoginController {
    fn new(implementation: Arc<dyn LaunchAtLoginImpl>) -> Self {
        Self {
            implementation,
            last_read: Arc::new(Mutex::new(None)),
        }
    }

    #[must_use]
    pub fn status(&self) -> LaunchAtLoginStatus {
        self.status_at(Instant::now())
    }

    fn status_at(&self, now: Instant) -> LaunchAtLoginStatus {
        let mut last_read = self.last_read.lock().unwrap_or_else(PoisonError::into_inner);
        if let Some((read_at, status)) = *last_read
            && now.saturating_duration_since(read_at) < STATUS_FRESHNESS
        {
            return status;
        }
        let status = self
            .implementation
            .status()
            .unwrap_or(LaunchAtLoginStatus::Unavailable);
        *last_read = Some((now, status));
        status
    }

    /// # Errors
    ///
    /// Returns an error when launch at login is unavailable or when the
    /// system service manager rejects the requested state.
    pub fn set_enabled(&self, enabled: bool) -> Result<LaunchAtLoginStatus, BridgeError> {
        let result = self.implementation.set_enabled(enabled);
        // A rejected change may still have moved the system state, so only a
        // confirmed one is remembered; otherwise the next read asks again.
        *self.last_read.lock().unwrap_or_else(PoisonError::into_inner) =
            result.as_ref().ok().map(|status| (Instant::now(), *status));
        result
    }

    #[cfg(test)]
    #[must_use]
    pub fn fake(status: LaunchAtLoginStatus) -> Self {
        Self::new(Arc::new(FakeLaunchAtLogin {
            status: Mutex::new(status),
        }))
    }
}

struct SystemLaunchAtLogin;

impl LaunchAtLoginImpl for SystemLaunchAtLogin {
    fn status(&self) -> Result<LaunchAtLoginStatus, BridgeError> {
        let bundle = NSBundle::mainBundle();
        let Some(bundle_path) = bundle
            .bundleURL()
            .path()
            .map(|path| std::path::PathBuf::from(path.to_string()))
        else {
            return Ok(LaunchAtLoginStatus::Unavailable);
        };

        let installed_in_system_applications = bundle_path.starts_with("/Applications");
        let installed_in_user_applications =
            dirs::home_dir().is_some_and(|home| bundle_path.starts_with(home.join("Applications")));
        if !installed_in_system_applications && !installed_in_user_applications {
            return Ok(LaunchAtLoginStatus::Unavailable);
        }

        let service = unsafe { SMAppService::mainAppService() };
        let status = unsafe { service.status() };
        Ok(LaunchAtLoginStatus::Available {
            enabled: status == SMAppServiceStatus::Enabled,
        })
    }

    fn set_enabled(&self, enabled: bool) -> Result<LaunchAtLoginStatus, BridgeError> {
        match self.status()? {
            LaunchAtLoginStatus::Available { enabled: current } if current == enabled => {
                return Ok(LaunchAtLoginStatus::Available { enabled });
            }
            LaunchAtLoginStatus::Available { .. } => {}
            LaunchAtLoginStatus::Unavailable => {
                return Err(BridgeError::invalid_input(
                    "launch at login is available only when the app is installed in Applications",
                ));
            }
        }

        let service = unsafe { SMAppService::mainAppService() };
        let result = if enabled {
            unsafe { service.registerAndReturnError() }
        } else {
            unsafe { service.unregisterAndReturnError() }
        };
        result.map_err(|error| BridgeError::engine(error.localizedDescription().to_string()))?;
        self.status()
    }
}

#[cfg(test)]
struct FakeLaunchAtLogin {
    status: Mutex<LaunchAtLoginStatus>,
}

#[cfg(test)]
impl LaunchAtLoginImpl for FakeLaunchAtLogin {
    fn status(&self) -> Result<LaunchAtLoginStatus, BridgeError> {
        Ok(*self.status.lock().expect("fake status lock poisoned"))
    }

    fn set_enabled(&self, enabled: bool) -> Result<LaunchAtLoginStatus, BridgeError> {
        let mut status = self.status.lock().expect("fake status lock poisoned");
        match *status {
            LaunchAtLoginStatus::Available { .. } => {
                *status = LaunchAtLoginStatus::Available { enabled };
                Ok(*status)
            }
            LaunchAtLoginStatus::Unavailable => Err(BridgeError::invalid_input(
                "launch at login is available only when the app is installed in Applications",
            )),
        }
    }
}

#[cfg(test)]
mod tests {
    use std::sync::atomic::{AtomicUsize, Ordering};

    use super::*;

    /// The service manager: the status System Settings shows, and how often it
    /// was asked for it.
    struct CountingLaunchAtLogin {
        status: Mutex<LaunchAtLoginStatus>,
        reads: AtomicUsize,
    }

    impl LaunchAtLoginImpl for CountingLaunchAtLogin {
        fn status(&self) -> Result<LaunchAtLoginStatus, BridgeError> {
            self.reads.fetch_add(1, Ordering::SeqCst);
            Ok(*self.status.lock().unwrap())
        }

        fn set_enabled(&self, enabled: bool) -> Result<LaunchAtLoginStatus, BridgeError> {
            let status = LaunchAtLoginStatus::Available { enabled };
            *self.status.lock().unwrap() = status;
            Ok(status)
        }
    }

    fn controller(enabled: bool) -> (LaunchAtLoginController, Arc<CountingLaunchAtLogin>) {
        let system = Arc::new(CountingLaunchAtLogin {
            status: Mutex::new(LaunchAtLoginStatus::Available { enabled }),
            reads: AtomicUsize::new(0),
        });
        (LaunchAtLoginController::new(system.clone()), system)
    }

    #[test]
    fn a_burst_of_snapshots_asks_the_service_manager_once() {
        let (controller, system) = controller(true);
        let start = Instant::now();

        for step in 0..100 {
            assert_eq!(
                controller.status_at(start + Duration::from_millis(step * 10)),
                LaunchAtLoginStatus::Available { enabled: true }
            );
        }

        assert_eq!(system.reads.load(Ordering::SeqCst), 1);
    }

    #[test]
    fn a_change_made_in_system_settings_shows_once_the_last_read_has_aged() {
        let (controller, system) = controller(false);
        let start = Instant::now();
        assert_eq!(
            controller.status_at(start),
            LaunchAtLoginStatus::Available { enabled: false }
        );

        *system.status.lock().unwrap() = LaunchAtLoginStatus::Available { enabled: true };

        assert_eq!(
            controller.status_at(start + STATUS_FRESHNESS),
            LaunchAtLoginStatus::Available { enabled: true }
        );
    }

    #[test]
    fn a_change_made_in_the_app_shows_at_once() {
        let (controller, _system) = controller(false);
        assert_eq!(
            controller.status(),
            LaunchAtLoginStatus::Available { enabled: false }
        );

        controller.set_enabled(true).unwrap();

        assert_eq!(
            controller.status(),
            LaunchAtLoginStatus::Available { enabled: true }
        );
    }
}
