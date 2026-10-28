import Foundation

/// Keeps the last five minutes of samples and resamples them into 120 equal
/// time buckets for the panel. Bucket values are averaged; an empty bucket
/// holds the previous value so slow refresh settings still produce a full line.
public struct MetricHistory {
    public static let window: TimeInterval = 300
    public static let pointCount = 120

    private struct Sample {
        var time: Date
        var value: Double
    }

    private var cpu: [Sample] = []
    private var gpu: [Sample] = []
    private var download: [Sample] = []
    private var upload: [Sample] = []
    private var temperature: [Sample] = []

    public init() {}

    public mutating func append(_ snapshot: MetricsSnapshot, fresh: SampleMask) {
        let now = snapshot.timestamp
        if fresh.contains(.cpu) {
            Self.push(&cpu, now, snapshot.cpu.total)
        }
        if fresh.contains(.gpu), let utilization = snapshot.gpu.utilization, !snapshot.gpu.isStale {
            Self.push(&gpu, now, utilization)
        }
        if fresh.contains(.network) {
            Self.push(&download, now, snapshot.network.downloadBytesPerSec)
            Self.push(&upload, now, snapshot.network.uploadBytesPerSec)
        }
        if fresh.contains(.thermal), let celsius = snapshot.thermal.cpuCelsius, celsius.isFinite {
            Self.push(&temperature, now, celsius)
        }

        Self.prune(&cpu, now: now)
        Self.prune(&gpu, now: now)
        Self.prune(&download, now: now)
        Self.prune(&upload, now: now)
        Self.prune(&temperature, now: now)
    }

    public func cpuValues(endingAt now: Date) -> [Double] {
        Self.resample(cpu, now: now)
    }

    public func gpuValues(endingAt now: Date) -> [Double] {
        Self.resample(gpu, now: now)
    }

    public func downloadValues(endingAt now: Date) -> [Double] {
        Self.resample(download, now: now)
    }

    public func uploadValues(endingAt now: Date) -> [Double] {
        Self.resample(upload, now: now)
    }

    public func temperatureValues(endingAt now: Date) -> [Double] {
        Self.resample(temperature, now: now)
    }

    public func networkPeak(endingAt now: Date) -> Double {
        let start = now.addingTimeInterval(-Self.window)
        var peak: Double = 0
        for sample in download where sample.time >= start {
            peak = max(peak, sample.value)
        }
        for sample in upload where sample.time >= start {
            peak = max(peak, sample.value)
        }
        return peak
    }

    public func temperaturePeak(endingAt now: Date) -> Double {
        let start = now.addingTimeInterval(-Self.window)
        var peak: Double = 0
        for sample in temperature where sample.time >= start {
            peak = max(peak, sample.value)
        }
        return peak
    }

    public mutating func reset() {
        cpu.removeAll(keepingCapacity: false)
        gpu.removeAll(keepingCapacity: false)
        download.removeAll(keepingCapacity: false)
        upload.removeAll(keepingCapacity: false)
        temperature.removeAll(keepingCapacity: false)
    }

    private static func push(_ samples: inout [Sample], _ time: Date, _ value: Double) {
        samples.append(Sample(time: time, value: value))
    }

    private static func prune(_ samples: inout [Sample], now: Date) {
        let start = now.addingTimeInterval(-window)
        guard let first = samples.first, first.time < start else { return }

        var drop = 0
        while drop < samples.count, samples[drop].time < start {
            drop += 1
        }
        samples.removeFirst(drop)
    }

    private static func resample(_ samples: [Sample], now: Date) -> [Double] {
        guard !samples.isEmpty else { return [] }

        let start = now.addingTimeInterval(-window)
        let bucketWidth = window / Double(pointCount)
        var values: [Double] = []
        values.reserveCapacity(pointCount)

        var index = 0
        while index < samples.count, samples[index].time < start {
            index += 1
        }

        var lastValue: Double?
        for bucket in 0..<pointCount {
            let lower = start.addingTimeInterval(Double(bucket) * bucketWidth)
            let upper = bucket == pointCount - 1
                ? now
                : lower.addingTimeInterval(bucketWidth)

            var sum = 0.0
            var count = 0
            while index < samples.count, samples[index].time <= upper {
                sum += samples[index].value
                count += 1
                index += 1
            }

            if count > 0 {
                lastValue = sum / Double(count)
            }
            if let lastValue {
                values.append(lastValue)
            }
        }

        return values
    }
}
