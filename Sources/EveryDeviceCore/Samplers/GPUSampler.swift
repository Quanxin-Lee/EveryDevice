import Foundation
import IOKit

public struct GPUSampler {
    private var last = GPUUsage()

    public init() {}

    public mutating func sample() -> GPUUsage {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching("IOAccelerator"),
            &iterator
        ) == KERN_SUCCESS else {
            return markMissing()
        }
        defer { IOObjectRelease(iterator) }

        var bestUtilization: Double?
        var bestRenderer: Double?
        var bestMemory: UInt64?
        var found = false

        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            guard let statistics = IORegistryEntryCreateCFProperty(
                service,
                "PerformanceStatistics" as CFString,
                kCFAllocatorDefault,
                0
            )?.takeRetainedValue() as? [String: Any] else { continue }

            let utilization = (statistics["Device Utilization %"] as? NSNumber)?.doubleValue
            let renderer = (statistics["Renderer Utilization %"] as? NSNumber)?.doubleValue
            let memory = (statistics["In use system memory"] as? NSNumber)?.uint64Value

            if let utilization {
                found = true
                bestUtilization = max(bestUtilization ?? 0, utilization)
            }
            if let renderer {
                found = true
                bestRenderer = max(bestRenderer ?? 0, renderer)
            }
            if let memory {
                bestMemory = max(bestMemory ?? 0, memory)
            }
        }

        guard found else { return markMissing() }

        let usage = GPUUsage(
            utilization: bestUtilization.map { min(1, max(0, $0 / 100)) }
                ?? bestRenderer.map { min(1, max(0, $0 / 100)) },
            memoryInUseBytes: bestMemory,
            isStale: false
        )
        last = usage
        return usage
    }

    private mutating func markMissing() -> GPUUsage {
        guard last.utilization != nil else { return GPUUsage() }

        var stale = last
        stale.isStale = true
        last = stale
        return stale
    }
}
