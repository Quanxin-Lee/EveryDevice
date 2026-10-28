import Darwin

public struct CPUSampler {
    private var previousTicks: [UInt32] = []
    private var lastUsage = CPUUsage()

    public init() {}

    public mutating func sample() -> CPUUsage {
        var cpuCount: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0

        let result = host_processor_info(
            MachHost.host,
            PROCESSOR_CPU_LOAD_INFO,
            &cpuCount,
            &info,
            &infoCount
        )

        guard result == KERN_SUCCESS, let info, infoCount > 0 else {
            return lastUsage
        }

        defer {
            vm_deallocate(
                mach_task_self_,
                vm_address_t(bitPattern: info),
                vm_size_t(infoCount) * vm_size_t(MemoryLayout<integer_t>.size)
            )
        }

        let count = Int(infoCount)
        var ticks = [UInt32](repeating: 0, count: count)
        for index in 0..<count {
            ticks[index] = UInt32(bitPattern: info[index])
        }

        defer { previousTicks = ticks }

        guard previousTicks.count == ticks.count else {
            lastUsage = CPUUsage(
                total: 0,
                cores: Array(repeating: 0, count: Int(cpuCount)),
                loadAverage: readLoadAverage()
            )
            return lastUsage
        }

        let usage = CPUTicks.usage(previous: previousTicks, current: ticks)
        lastUsage = CPUUsage(total: usage.total, cores: usage.cores, loadAverage: readLoadAverage())
        return lastUsage
    }

    public mutating func reset() {
        previousTicks = []
        lastUsage = CPUUsage()
    }

    private func readLoadAverage() -> Double {
        var values = [Double](repeating: 0, count: 3)
        guard getloadavg(&values, 3) > 0 else { return 0 }
        return values[0]
    }
}
