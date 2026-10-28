import Foundation

public struct SampleMask: OptionSet, Sendable, Codable, Hashable {
    public let rawValue: UInt16

    public init(rawValue: UInt16) {
        self.rawValue = rawValue
    }

    public static let cpu = SampleMask(rawValue: 1 << 0)
    public static let gpu = SampleMask(rawValue: 1 << 1)
    public static let memory = SampleMask(rawValue: 1 << 2)
    public static let network = SampleMask(rawValue: 1 << 3)
    public static let disk = SampleMask(rawValue: 1 << 4)
    public static let thermal = SampleMask(rawValue: 1 << 5)
    public static let process = SampleMask(rawValue: 1 << 6)
    public static let battery = SampleMask(rawValue: 1 << 7)
}

public struct MetricsUpdate: Sendable {
    public var snapshot: MetricsSnapshot
    public var fresh: SampleMask
    /// The first collection after launch/wake only establishes sampler baselines.
    public var isWarmup: Bool

    public init(snapshot: MetricsSnapshot, fresh: SampleMask, isWarmup: Bool = false) {
        self.snapshot = snapshot
        self.fresh = fresh
        self.isWarmup = isWarmup
    }
}
