import Foundation

public enum RateCalculator {
    public static func delta(current: UInt64, previous: UInt64) -> UInt64 {
        current >= previous ? current - previous : 0
    }
}

public enum CPUTicks {
    public static func delta(_ current: UInt32, _ previous: UInt32) -> UInt32 {
        current &- previous
    }

    /// Tick arrays are flattened as four entries per core: user, system, idle, nice.
    public static func usage(previous: [UInt32], current: [UInt32]) -> (total: Double, cores: [Double]) {
        guard previous.count == current.count, current.count % 4 == 0 else {
            return (0, [])
        }

        var totalBusy = 0.0
        var totalAll = 0.0
        var cores: [Double] = []
        var index = 0

        while index + 3 < current.count {
            let user = Double(delta(current[index], previous[index]))
            let system = Double(delta(current[index + 1], previous[index + 1]))
            let idle = Double(delta(current[index + 2], previous[index + 2]))
            let nice = Double(delta(current[index + 3], previous[index + 3]))
            let busy = user + system + nice
            let all = busy + idle
            cores.append(all > 0 ? busy / all : 0)
            totalBusy += busy
            totalAll += all
            index += 4
        }

        return (totalAll > 0 ? totalBusy / totalAll : 0, cores)
    }
}
