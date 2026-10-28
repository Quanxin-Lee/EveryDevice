import Foundation

/// Battery capacity changes slowly, so it keeps a fixed cadence independent of
/// the user-facing refresh interval. Every other metric follows the tick.
public struct SampleCadence: Sendable {
    public static let batteryInterval: TimeInterval = 30

    private var lastBattery: Date?

    public init() {}

    public func isBatteryDue(at now: Date) -> Bool {
        guard let last = lastBattery else { return true }
        guard now >= last else { return true }
        return now.timeIntervalSince(last) >= Self.batteryInterval - 0.001
    }

    public mutating func markBattery(at now: Date) {
        lastBattery = now
    }

    public mutating func reset() {
        lastBattery = nil
    }
}
