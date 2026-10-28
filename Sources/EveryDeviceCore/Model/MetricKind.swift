import Foundation

public enum MetricKind: String, CaseIterable, Sendable, Codable, Identifiable {
    case cpu
    case gpu
    case memory
    case network
    case disk
    case battery
    case temperature

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .cpu: return L10n.tr("metric.cpu.title")
        case .gpu: return L10n.tr("metric.gpu.title")
        case .memory: return L10n.tr("metric.memory.title")
        case .network: return L10n.tr("metric.network.title")
        case .disk: return L10n.tr("metric.disk.title")
        case .battery: return L10n.tr("metric.battery.title")
        case .temperature: return L10n.tr("metric.temperature.title")
        }
    }

    public func fraction(in snapshot: MetricsSnapshot) -> Double? {
        switch self {
        case .cpu:
            return snapshot.cpu.total
        case .gpu:
            return snapshot.gpu.utilization
        case .memory:
            return snapshot.memory.usedFraction
        case .network:
            return nil
        case .disk:
            return snapshot.disk.usedFraction
        case .battery:
            return snapshot.battery.percentage
        case .temperature:
            guard let celsius = snapshot.thermal.cpuCelsius else { return nil }
            return min(1, max(0, (celsius - 30) / 70))
        }
    }
}
