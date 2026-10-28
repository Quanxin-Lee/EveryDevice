import Foundation

/// Process enumeration is the only sampler that still depends on visibility.
public struct SamplingDemand: Sendable, Equatable {
    public var processes: Bool

    public init(processes: Bool = true) {
        self.processes = processes
    }

    public static let all = SamplingDemand()
}

public final class SnapshotCollector {
    private var cpuSampler = CPUSampler()
    private var memorySampler = MemorySampler()
    private var networkSampler = NetworkSampler()
    private var diskSampler = DiskSampler()
    private var gpuSampler = GPUSampler()
    private let batterySampler = BatterySampler()
    private let thermalSampler = ThermalSampler()
    private var processSampler = ProcessSampler()

    private var snapshot = MetricsSnapshot()
    private var cadence = SampleCadence()
    private var isWarmup = true
    private var processDemandActive = false

    public var demand = SamplingDemand.all

    public init() {}

    public func collect(now: Date = Date()) -> MetricsUpdate {
        var fresh: SampleMask = [.network]
        snapshot.timestamp = now
        snapshot.network = networkSampler.sample(at: now)

        snapshot.cpu = cpuSampler.sample()
        snapshot.memory = memorySampler.sample()
        snapshot.gpu = gpuSampler.sample()
        snapshot.disk = diskSampler.sample(at: now)
        fresh.formUnion([.cpu, .memory, .gpu, .disk])

        snapshot.thermal = thermalSampler.sample(includeGPU: true)
        fresh.insert(.thermal)

        if demand.processes {
            if !processDemandActive {
                processSampler.reset()
                processDemandActive = true
            }
            let processes = processSampler.sample(at: now)
            snapshot.processes = processes.processes
            snapshot.unreadableProcessCount = processes.unreadable
            fresh.insert(.process)
        } else {
            processDemandActive = false
        }

        if cadence.isBatteryDue(at: now) {
            snapshot.battery = batterySampler.sample()
            cadence.markBattery(at: now)
            fresh.insert(.battery)
        }

        let warmup = isWarmup
        isWarmup = false
        return MetricsUpdate(snapshot: snapshot, fresh: fresh, isWarmup: warmup)
    }

    public func resetBaselines() {
        cpuSampler.reset()
        networkSampler.reset()
        diskSampler.reset()
        processSampler.reset()
        cadence.reset()
        isWarmup = true
    }
}
