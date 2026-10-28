import AppKit
import EveryDeviceCore
import SwiftUI

enum Theme {
    static let accentSecondary = Color(red: 0.56, green: 0.62, blue: 0.72)
    static let cardRadius: CGFloat = 14

    private static let levelNormal = Color(red: 0.20, green: 0.73, blue: 0.44)
    private static let levelWarning = Color(red: 0.94, green: 0.68, blue: 0.10)
    private static let levelCritical = Color(red: 0.95, green: 0.30, blue: 0.26)

    static func cardHairline(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.09) : Color.black.opacity(0.06)
    }

    static func fractionColor(_ fraction: Double?) -> Color {
        guard let fraction else { return .secondary }
        if fraction >= 0.85 { return levelCritical }
        if fraction >= 0.60 { return levelWarning }
        return levelNormal
    }

    static func temperatureColor(_ celsius: Double?) -> Color {
        guard let celsius else { return .secondary }
        if celsius >= 90 { return levelCritical }
        if celsius >= 70 { return levelWarning }
        return levelNormal
    }

    static func batteryColor(_ percentage: Double?) -> Color {
        guard let percentage else { return .secondary }
        if percentage < 0.15 { return levelCritical }
        if percentage < 0.30 { return levelWarning }
        return levelNormal
    }

    /// Idle processes should read as neutral instead of green.
    static func processCPUColor(_ fraction: Double?) -> Color {
        guard let fraction, fraction.isFinite, fraction > 0.005 else { return .secondary }
        if fraction >= 0.75 { return levelCritical }
        if fraction >= 0.40 { return levelWarning }
        return .primary
    }

    static func statusColor(metric: MetricKind, snapshot: MetricsSnapshot) -> NSColor {
        switch metric {
        case .network:
            return .controlAccentColor
        case .temperature:
            return NSColor(temperatureColor(snapshot.thermal.cpuCelsius))
        case .battery:
            return NSColor(batteryColor(snapshot.battery.percentage))
        default:
            return NSColor(fractionColor(metric.fraction(in: snapshot)))
        }
    }
}

extension AppAppearance {
    var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }
}

extension AccentTheme {
    var color: Color {
        tint
    }

    var tint: Color {
        switch self {
        case .system: return Color(nsColor: .controlAccentColor)
        case .blue: return Color(red: 0.36, green: 0.60, blue: 0.94)
        case .green: return Color(red: 0.24, green: 0.68, blue: 0.45)
        case .orange: return Color(red: 0.91, green: 0.52, blue: 0.18)
        case .purple: return Color(red: 0.56, green: 0.42, blue: 0.90)
        case .graphite: return Color(red: 0.45, green: 0.49, blue: 0.57)
        case .ocean: return Color(red: 0.16, green: 0.58, blue: 0.62)
        case .rose: return Color(red: 0.90, green: 0.38, blue: 0.52)
        }
    }

    func washColors(for scheme: ColorScheme) -> [Color] {
        let top = scheme == .dark ? 0.22 : 0.14
        let bottom = scheme == .dark ? 0.08 : 0.05
        return [tint.opacity(top), tint.opacity(bottom)]
    }
}

enum Motion {
    static var value: Animation {
        .easeOut(duration: 0.12)
    }
}

struct PanelWash: View {
    let theme: AccentTheme

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        LinearGradient(
            colors: theme.washColors(for: scheme),
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
