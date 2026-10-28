import Foundation

public struct CPUUsage: Sendable, Codable, Equatable {
    public var total: Double
    public var cores: [Double]
    public var loadAverage: Double

    public init(total: Double = 0, cores: [Double] = [], loadAverage: Double = 0) {
        self.total = total
        self.cores = cores
        self.loadAverage = loadAverage
    }
}

public struct MemoryUsage: Sendable, Codable, Equatable {
    public var totalBytes: UInt64
    public var appBytes: UInt64
    public var wiredBytes: UInt64
    public var compressedBytes: UInt64
    public var swapUsedBytes: UInt64

    public init(
        totalBytes: UInt64 = 0,
        appBytes: UInt64 = 0,
        wiredBytes: UInt64 = 0,
        compressedBytes: UInt64 = 0,
        swapUsedBytes: UInt64 = 0
    ) {
        self.totalBytes = totalBytes
        self.appBytes = appBytes
        self.wiredBytes = wiredBytes
        self.compressedBytes = compressedBytes
        self.swapUsedBytes = swapUsedBytes
    }

    public var usedBytes: UInt64 {
        let (appPlusWired, firstOverflow) = appBytes.addingReportingOverflow(wiredBytes)
        guard !firstOverflow else { return totalBytes }

        let (total, secondOverflow) = appPlusWired.addingReportingOverflow(compressedBytes)
        guard !secondOverflow else { return totalBytes }

        return min(totalBytes, total)
    }

    public var usedFraction: Double {
        totalBytes > 0 ? Double(usedBytes) / Double(totalBytes) : 0
    }
}

public struct NetworkRate: Sendable, Codable, Equatable {
    public var downloadBytesPerSec: Double
    public var uploadBytesPerSec: Double

    public init(downloadBytesPerSec: Double = 0, uploadBytesPerSec: Double = 0) {
        self.downloadBytesPerSec = downloadBytesPerSec
        self.uploadBytesPerSec = uploadBytesPerSec
    }
}

public struct DiskUsage: Sendable, Codable, Equatable {
    public var readBytesPerSec: Double
    public var writeBytesPerSec: Double
    public var totalBytes: UInt64
    public var freeBytes: UInt64

    public init(
        readBytesPerSec: Double = 0,
        writeBytesPerSec: Double = 0,
        totalBytes: UInt64 = 0,
        freeBytes: UInt64 = 0
    ) {
        self.readBytesPerSec = readBytesPerSec
        self.writeBytesPerSec = writeBytesPerSec
        self.totalBytes = totalBytes
        self.freeBytes = freeBytes
    }

    public var usedFraction: Double {
        guard totalBytes > 0 else { return 0 }
        let used = totalBytes > freeBytes ? totalBytes - freeBytes : 0
        return Double(used) / Double(totalBytes)
    }
}

public struct GPUUsage: Sendable, Codable, Equatable {
    public var utilization: Double?
    public var memoryInUseBytes: UInt64?
    public var isStale: Bool

    public init(
        utilization: Double? = nil,
        memoryInUseBytes: UInt64? = nil,
        isStale: Bool = false
    ) {
        self.utilization = utilization
        self.memoryInUseBytes = memoryInUseBytes
        self.isStale = isStale
    }
}

public struct BatteryInfo: Sendable, Codable, Equatable {
    public var isPresent: Bool
    public var percentage: Double?
    public var isCharging: Bool
    public var isPluggedIn: Bool
    public var isFullyCharged: Bool
    public var timeRemainingSeconds: Int?
    public var timeToFullSeconds: Int?

    public init(
        isPresent: Bool = false,
        percentage: Double? = nil,
        isCharging: Bool = false,
        isPluggedIn: Bool = false,
        isFullyCharged: Bool = false,
        timeRemainingSeconds: Int? = nil,
        timeToFullSeconds: Int? = nil
    ) {
        self.isPresent = isPresent
        self.percentage = percentage
        self.isCharging = isCharging
        self.isPluggedIn = isPluggedIn
        self.isFullyCharged = isFullyCharged
        self.timeRemainingSeconds = timeRemainingSeconds
        self.timeToFullSeconds = timeToFullSeconds
    }
}

public enum ThermalPressure: String, Sendable, Codable, CaseIterable {
    case nominal
    case fair
    case serious
    case critical

    public var title: String {
        switch self {
        case .nominal: return L10n.tr("thermal.nominal")
        case .fair: return L10n.tr("thermal.fair")
        case .serious: return L10n.tr("thermal.serious")
        case .critical: return L10n.tr("thermal.critical")
        }
    }
}

public struct ThermalInfo: Sendable, Codable, Equatable {
    public var cpuCelsius: Double?
    public var gpuCelsius: Double?
    public var sensorAvailable: Bool
    public var pressure: ThermalPressure

    public init(
        cpuCelsius: Double? = nil,
        gpuCelsius: Double? = nil,
        sensorAvailable: Bool = false,
        pressure: ThermalPressure = .nominal
    ) {
        self.cpuCelsius = cpuCelsius
        self.gpuCelsius = gpuCelsius
        self.sensorAvailable = sensorAvailable
        self.pressure = pressure
    }
}

public struct ProcessUsage: Sendable, Codable, Equatable, Identifiable {
    public var pid: Int32
    public var name: String
    public var cpuFraction: Double
    public var memoryBytes: UInt64

    public var id: Int32 { pid }

    public init(pid: Int32, name: String, cpuFraction: Double, memoryBytes: UInt64) {
        self.pid = pid
        self.name = name
        self.cpuFraction = cpuFraction
        self.memoryBytes = memoryBytes
    }
}

public struct MetricsSnapshot: Sendable, Codable, Equatable {
    public var timestamp: Date
    public var cpu: CPUUsage
    public var memory: MemoryUsage
    public var network: NetworkRate
    public var disk: DiskUsage
    public var gpu: GPUUsage
    public var battery: BatteryInfo
    public var thermal: ThermalInfo
    public var processes: [ProcessUsage]
    public var unreadableProcessCount: Int

    public init(
        timestamp: Date = .distantPast,
        cpu: CPUUsage = CPUUsage(),
        memory: MemoryUsage = MemoryUsage(),
        network: NetworkRate = NetworkRate(),
        disk: DiskUsage = DiskUsage(),
        gpu: GPUUsage = GPUUsage(),
        battery: BatteryInfo = BatteryInfo(),
        thermal: ThermalInfo = ThermalInfo(),
        processes: [ProcessUsage] = [],
        unreadableProcessCount: Int = 0
    ) {
        self.timestamp = timestamp
        self.cpu = cpu
        self.memory = memory
        self.network = network
        self.disk = disk
        self.gpu = gpu
        self.battery = battery
        self.thermal = thermal
        self.processes = processes
        self.unreadableProcessCount = unreadableProcessCount
    }
}
