import Foundation

public enum AppAppearance: String, CaseIterable, Codable, Identifiable, Sendable {
    case system
    case light
    case dark

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .system: return L10n.tr("appearance.system")
        case .light: return L10n.tr("appearance.light")
        case .dark: return L10n.tr("appearance.dark")
        }
    }
}

public enum AccentTheme: String, CaseIterable, Identifiable, Sendable {
    case system
    case blue
    case green
    case orange
    case purple
    case graphite
    case ocean
    case rose

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .system: return L10n.tr("theme.system")
        case .blue: return L10n.tr("theme.blue")
        case .green: return L10n.tr("theme.green")
        case .orange: return L10n.tr("theme.orange")
        case .purple: return L10n.tr("theme.purple")
        case .graphite: return L10n.tr("theme.graphite")
        case .ocean: return L10n.tr("theme.ocean")
        case .rose: return L10n.tr("theme.rose")
        }
    }
}

public enum PanelWidth: Int, CaseIterable, Identifiable, Sendable {
    case narrow = 340
    case standard = 360
    case wide = 400

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .narrow: return L10n.tr("panel.width.narrow")
        case .standard: return L10n.tr("panel.width.standard")
        case .wide: return L10n.tr("panel.width.wide")
        }
    }
}

public enum PanelDensity: String, CaseIterable, Identifiable, Sendable {
    case compact
    case standard

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .compact: return L10n.tr("panel.density.compact")
        case .standard: return L10n.tr("panel.density.standard")
        }
    }
}

public enum PanelCardKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case cpu
    case gpu
    case memory
    case network
    case disk
    case battery

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .cpu: return L10n.tr("metric.cpu.title")
        case .gpu: return L10n.tr("metric.gpu.title")
        case .memory: return L10n.tr("metric.memory.title")
        case .network: return L10n.tr("metric.network.title")
        case .disk: return L10n.tr("metric.disk.title")
        case .battery: return L10n.tr("metric.battery.title")
        }
    }
}
