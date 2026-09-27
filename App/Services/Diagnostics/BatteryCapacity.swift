import Foundation
import IOKit

/// Full-charge energy of the Mac's internal battery, so a power figure can be put as a
/// share of a charge. Read from the `AppleSmartBattery` registry entry, which needs no
/// privileges; a Mac without a battery has no such entry.
enum BatteryCapacity {
  /// Lithium-ion cells are rated at about 3.85 V: a MacBook Pro sold as 100 Wh reports
  /// 8,579 mAh across three cells, which gives 99 Wh.
  static let nominalCellVolts = 3.85

  static func fullChargeWattHours() -> Double? {
    let service = IOServiceGetMatchingService(
      kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
    guard service != IO_OBJECT_NULL else { return nil }
    defer { IOObjectRelease(service) }
    var unmanaged: Unmanaged<CFMutableDictionary>?
    guard
      IORegistryEntryCreateCFProperties(service, &unmanaged, kCFAllocatorDefault, 0)
        == KERN_SUCCESS,
      let properties = unmanaged?.takeRetainedValue() as? [String: Any]
    else { return nil }
    return wattHours(properties)
  }

  /// `AppleRawMaxCapacity` is today's full charge in mAh; the rated `DesignCapacity`
  /// stands in when it is missing. Cell count comes from the per-cell voltages; failing
  /// that, the pack's present voltage is used, which reads a few percent high when full.
  static func wattHours(_ properties: [String: Any]) -> Double? {
    guard properties["BatteryInstalled"] as? Bool != false,
      let milliampHours = (properties["AppleRawMaxCapacity"] ?? properties["DesignCapacity"])
        as? Int, milliampHours > 0
    else { return nil }
    let volts: Double
    if let cells = ((properties["BatteryData"] as? [String: Any])?["CellVoltage"] as? [Int])?
      .count, cells > 0
    {
      volts = Double(cells) * nominalCellVolts
    } else if let millivolts = properties["Voltage"] as? Int, millivolts > 0 {
      volts = Double(millivolts) / 1000
    } else {
      return nil
    }
    return Double(milliampHours) * volts / 1000
  }
}
