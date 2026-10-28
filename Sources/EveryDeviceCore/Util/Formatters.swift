import Foundation

public enum Format {
    private static let units = ["B", "KB", "MB", "GB", "TB", "PB"]

    public static func percent(_ fraction: Double?) -> String {
        guard let fraction, fraction.isFinite else { return "—" }
        return "\(Int((clamp(fraction) * 100).rounded()))%"
    }

    /// For per-process CPU, where a multi-threaded process can exceed 100%.
    public static func percentUnclamped(_ fraction: Double?) -> String {
        guard let fraction, fraction.isFinite else { return "—" }
        return "\(Int((max(0, fraction) * 100).rounded()))%"
    }

    /// Always four characters, right aligned, so the status item never changes width.
    public static func percentFixed(_ fraction: Double?) -> String {
        guard let fraction, fraction.isFinite else { return "   —" }
        return String(format: "%3d%%", Int((clamp(fraction) * 100).rounded()))
    }

    public static func bytes(_ value: Double) -> String {
        guard value.isFinite, value > 0 else { return "0 B" }
        let (amount, index) = scaled(value)
        guard index > 0 else { return "\(Int(amount)) B" }
        return amount < 10
            ? String(format: "%.1f %@", amount, units[index])
            : String(format: "%.0f %@", amount, units[index])
    }

    public static func rate(_ bytesPerSecond: Double) -> String {
        bytes(bytesPerSecond) + "/s"
    }

    /// Exactly five characters, used next to the status ring.
    public static func compactRate(_ bytesPerSecond: Double) -> String {
        guard bytesPerSecond.isFinite, bytesPerSecond > 0 else { return "   0B" }
        let (amount, index) = scaled(bytesPerSecond)
        let number: String
        if index == 0 {
            number = String(format: "%.0f", amount)
        } else if amount < 10 {
            number = String(format: "%.1f", amount)
        } else {
            number = String(format: "%.0f", amount)
        }
        let core = number + units[index].prefix(1)
        return String(repeating: " ", count: max(0, 5 - core.count)) + core
    }

    public static func temperature(_ celsius: Double?) -> String {
        guard let celsius, celsius.isFinite else { return "—" }
        return L10n.tr("format.temperature", celsius)
    }

    public static func duration(seconds: Int?) -> String {
        guard let seconds, seconds > 0 else { return "—" }
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 { return L10n.tr("format.duration.hours", hours, minutes) }
        if minutes > 0 { return L10n.tr("format.duration.minutes", minutes) }
        return L10n.tr("format.duration.lessThanMinute")
    }

    public static func menuBarText(metric: MetricKind, snapshot: MetricsSnapshot) -> String {
        switch metric {
        case .network:
            let down = snapshot.network.downloadBytesPerSec
            let up = snapshot.network.uploadBytesPerSec
            return "↑" + compactRate(up) + "\n↓" + compactRate(down)
        case .temperature:
            guard let celsius = snapshot.thermal.cpuCelsius else { return "   —" }
            return String(format: "%3.0f°", celsius)
        default:
            return percentFixed(metric.fraction(in: snapshot))
        }
    }

    private static func scaled(_ value: Double) -> (amount: Double, unit: Int) {
        var amount = value
        var index = 0
        while amount >= 1024, index < units.count - 1 {
            amount /= 1024
            index += 1
        }
        return (amount, index)
    }

    private static func clamp(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}
