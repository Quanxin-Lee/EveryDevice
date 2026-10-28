import Darwin

public enum MachHost {
    public static let host: mach_port_t = mach_host_self()

    public static let pageSize: Int = {
        var size: vm_size_t = 0
        host_page_size(mach_host_self(), &size)
        return Int(size)
    }()

    public static let totalMemoryBytes: UInt64 = {
        var value: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &value, &size, nil, 0)
        return value
    }()

}
