import Foundation
import IOKit
import IOKit.ps

public struct BatterySampler {
    public init() {}

    public func sample() -> BatteryInfo {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let rawList = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() else {
            return BatteryInfo()
        }

        let list = rawList as NSArray

        for element in list {
            let source = element as AnyObject
            guard let raw = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue(),
                  let description = raw as? [String: Any] else { continue }
            guard let type = description[kIOPSTypeKey as String] as? String,
                  type == (kIOPSInternalBatteryType as String) else { continue }

            var info = BatteryInfo(isPresent: true)
            let current = description[kIOPSCurrentCapacityKey as String] as? Int ?? 0
            let maximum = description[kIOPSMaxCapacityKey as String] as? Int ?? 100
            if maximum > 0 {
                info.percentage = Double(current) / Double(maximum)
            }

            info.isCharging = description[kIOPSIsChargingKey as String] as? Bool ?? false
            info.isFullyCharged = description[kIOPSIsChargedKey as String] as? Bool ?? false
            if let state = description[kIOPSPowerSourceStateKey as String] as? String {
                info.isPluggedIn = state == (kIOPSACPowerValue as String)
            }

            // The per-source keys are documented in minutes (-1 while calculating) and
            // are only meaningful in their matching power state.
            if !info.isPluggedIn,
               let minutes = description[kIOPSTimeToEmptyKey as String] as? Int,
               minutes > 0 {
                info.timeRemainingSeconds = minutes * 60
            }
            if info.isCharging,
               let minutes = description[kIOPSTimeToFullChargeKey as String] as? Int,
               minutes > 0 {
                info.timeToFullSeconds = minutes * 60
            }

            if info.timeRemainingSeconds == nil, !info.isPluggedIn {
                let estimate = IOPSGetTimeRemainingEstimate()
                if estimate >= 0 {
                    info.timeRemainingSeconds = Int(estimate)
                }
            }

            return info
        }

        return BatteryInfo()
    }
}
