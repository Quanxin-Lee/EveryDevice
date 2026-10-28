import Foundation
import IOKit

public struct DiskSampler {
    private static let capacityRefreshInterval: TimeInterval = 30

    private var previous: (read: UInt64, write: UInt64)?
    private var previousTime: Date?
    private var lastCapacityRefresh: Date?
    private var cachedTotalBytes: UInt64 = 0
    private var cachedFreeBytes: UInt64 = 0
    private let volumeURL = URL(fileURLWithPath: "/")

    public init() {}

    public mutating func sample(at date: Date = Date()) -> DiskUsage {
        let counters = readIOCounters()
        var usage = DiskUsage()

        if let previous, let previousTime {
            let elapsed = date.timeIntervalSince(previousTime)
            if elapsed > 0 {
                usage.readBytesPerSec = Double(
                    RateCalculator.delta(current: counters.read, previous: previous.read)
                ) / elapsed
                usage.writeBytesPerSec = Double(
                    RateCalculator.delta(current: counters.write, previous: previous.write)
                ) / elapsed
            }
        }

        previous = counters
        previousTime = date

        // Important-usage capacity can synchronously round-trip to CacheDelete,
        // so it is refreshed infrequently instead of on every sample.
        let capacityIsStale = lastCapacityRefresh.map {
            date.timeIntervalSince($0) >= Self.capacityRefreshInterval
        } ?? true
        if capacityIsStale {
            if let values = try? volumeURL.resourceValues(
                forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]
            ) {
                cachedTotalBytes = UInt64(max(0, values.volumeTotalCapacity ?? 0))
                if let free = values.volumeAvailableCapacityForImportantUsage {
                    cachedFreeBytes = UInt64(max(0, free))
                }
            }
            lastCapacityRefresh = date
        }

        usage.totalBytes = cachedTotalBytes
        usage.freeBytes = cachedFreeBytes
        return usage
    }

    public mutating func reset() {
        previous = nil
        previousTime = nil
        lastCapacityRefresh = nil
    }

    private func readIOCounters() -> (read: UInt64, write: UInt64) {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching("IOBlockStorageDriver"),
            &iterator
        ) == KERN_SUCCESS else {
            return (0, 0)
        }
        defer { IOObjectRelease(iterator) }

        var read: UInt64 = 0
        var write: UInt64 = 0

        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            guard let statistics = IORegistryEntryCreateCFProperty(
                service,
                "Statistics" as CFString,
                kCFAllocatorDefault,
                0
            )?.takeRetainedValue() as? [String: Any] else { continue }

            if let value = statistics["Bytes (Read)"] as? NSNumber {
                read &+= value.uint64Value
            }
            if let value = statistics["Bytes (Write)"] as? NSNumber {
                write &+= value.uint64Value
            }
        }

        return (read, write)
    }
}
