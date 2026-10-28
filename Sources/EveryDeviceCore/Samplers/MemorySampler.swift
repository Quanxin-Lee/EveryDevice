import Darwin

public struct MemorySampler {
    public init() {}

    public func sample() -> MemoryUsage {
        var stats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size
        )

        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                host_statistics64(MachHost.host, HOST_VM_INFO64, rebound, &count)
            }
        }

        var usage = MemoryUsage(totalBytes: MachHost.totalMemoryBytes)

        if result == KERN_SUCCESS {
            let page = UInt64(MachHost.pageSize)
            let internalPages = UInt64(stats.internal_page_count)
            let purgeablePages = UInt64(stats.purgeable_count)
            usage.appBytes = (internalPages > purgeablePages ? internalPages - purgeablePages : 0) * page
            usage.wiredBytes = UInt64(stats.wire_count) * page
            usage.compressedBytes = UInt64(stats.compressor_page_count) * page
        }

        var swap = xsw_usage()
        var swapSize = MemoryLayout<xsw_usage>.size
        if sysctlbyname("vm.swapusage", &swap, &swapSize, nil, 0) == 0 {
            usage.swapUsedBytes = swap.xsu_used
        }

        return usage
    }
}
