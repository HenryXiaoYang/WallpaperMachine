//! On-disk persistence.

use serde::Deserialize;

pub mod app;
pub mod store;
pub mod wallpaper;
pub mod writer;

pub use app::{
    AppConfig, BatteryModeCfg, FilterCfg, GeneralCfg, MonitorCfg, MonitorSettingsCfg, PowerCfg,
    QualityCfg, QualityProfileCfg, SceneRendererModeCfg, SerializedSelector, UiCfg,
    VideoBackendModeCfg, WindowGeom, clamp_render_scale,
};
pub use store::{ConfigLoad, ConfigStore};
pub use wallpaper::{AudioCfg, MonitorRender, WallpaperConfig};

/// The rate older builds wrote when the user had never chosen one.
///
/// Indistinguishable from an untouched value, so loading it means "follow the
/// display" rather than "the user asked for 60".
pub(crate) const LEGACY_DEFAULT_FRAME_RATE: u32 = 60;

/// Resolves a saved rate against the display refresh.
///
/// `None` follows the native refresh. A saved rate is never below 1 and never
/// above what the display can present.
#[must_use]
pub(crate) fn resolve_frame_rate(frame_rate: Option<u32>, refresh_hz: u32) -> u32 {
    let max = refresh_hz.max(1);
    frame_rate.map_or(max, |fps| fps.max(1).min(max))
}

/// A request at or above the display refresh is stored as "follow native".
/// Anything lower is an explicit cap, never below 1 fps.
#[must_use]
pub(crate) fn stored_frame_rate(requested: u32, refresh_hz: u32) -> Option<u32> {
    let max = refresh_hz.max(1);
    if requested >= max {
        None
    } else {
        Some(requested.max(1))
    }
}

/// `explicit` is `Some` when the new key was present, including a JSON null,
/// so a legacy key cannot override a choice this build (or a hand edit) wrote.
#[must_use]
pub(crate) fn frame_rate_from_legacy(
    explicit: Option<Option<u32>>,
    legacy: Option<u32>,
) -> Option<u32> {
    explicit.unwrap_or_else(|| match legacy {
        Some(LEGACY_DEFAULT_FRAME_RATE) | None => None,
        Some(rate) => Some(rate.max(1)),
    })
}

/// Distinguishes a missing field from a present one, including JSON null.
///
/// `#[serde(default)]` alone collapses both to `None`, which would let a
/// legacy key override an explicit `frame_rate` of null.
pub(crate) fn deserialize_present<'de, T, D>(deserializer: D) -> Result<Option<T>, D::Error>
where
    T: Deserialize<'de>,
    D: serde::Deserializer<'de>,
{
    T::deserialize(deserializer).map(Some)
}
