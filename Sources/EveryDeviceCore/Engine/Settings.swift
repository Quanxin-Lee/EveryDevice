import Combine
import Foundation

public final class AppSettings: ObservableObject {
    private enum Key {
        static let ringMetric = "ringMetric"
        static let showsValueText = "showsValueText"
        static let refreshInterval = "refreshInterval"
        static let historyRetentionHours = "historyRetentionHours"
        static let recordsHistoryToDisk = "recordsHistoryToDisk"
        static let showsProcesses = "showsProcesses"
        static let showsTemperature = "showsTemperature"
        static let preventsSleep = "preventsSleep"
        static let accentTheme = "accentTheme"
        static let panelWidth = "panelWidth"
        static let panelDensity = "panelDensity"
        static let panelCardOrder = "panelCardOrder"
        static let hiddenPanelCards = "hiddenPanelCards"
        static let appLanguage = "appLanguage"
        static let appAppearance = "appAppearance"
    }

    @Published public var ringMetric: MetricKind {
        didSet { defaults.set(ringMetric.rawValue, forKey: Key.ringMetric) }
    }

    @Published public var showsValueText: Bool {
        didSet { defaults.set(showsValueText, forKey: Key.showsValueText) }
    }

    @Published public var refreshInterval: Double {
        didSet { defaults.set(refreshInterval, forKey: Key.refreshInterval) }
    }

    @Published public var historyRetentionHours: Int {
        didSet { defaults.set(historyRetentionHours, forKey: Key.historyRetentionHours) }
    }

    @Published public var recordsHistoryToDisk: Bool {
        didSet { defaults.set(recordsHistoryToDisk, forKey: Key.recordsHistoryToDisk) }
    }

    @Published public var showsProcesses: Bool {
        didSet { defaults.set(showsProcesses, forKey: Key.showsProcesses) }
    }

    @Published public var showsTemperature: Bool {
        didSet { defaults.set(showsTemperature, forKey: Key.showsTemperature) }
    }

    @Published public var preventsSleep: Bool {
        didSet { defaults.set(preventsSleep, forKey: Key.preventsSleep) }
    }

    @Published public var accentTheme: AccentTheme {
        didSet { defaults.set(accentTheme.rawValue, forKey: Key.accentTheme) }
    }

    @Published public var panelWidth: PanelWidth {
        didSet { defaults.set(panelWidth.rawValue, forKey: Key.panelWidth) }
    }

    @Published public var panelDensity: PanelDensity {
        didSet { defaults.set(panelDensity.rawValue, forKey: Key.panelDensity) }
    }

    @Published public var panelCardOrder: [String] {
        didSet { defaults.set(panelCardOrder, forKey: Key.panelCardOrder) }
    }

    @Published public var hiddenPanelCards: [String] {
        didSet { defaults.set(hiddenPanelCards, forKey: Key.hiddenPanelCards) }
    }

    @Published public var appLanguage: AppLanguage {
        didSet {
            defaults.set(appLanguage.rawValue, forKey: Key.appLanguage)
            L10n.setLanguage(appLanguage)
        }
    }

    @Published public var appAppearance: AppAppearance {
        didSet { defaults.set(appAppearance.rawValue, forKey: Key.appAppearance) }
    }

    public var orderedPanelCards: [PanelCardKind] {
        panelCardOrder.compactMap(PanelCardKind.init(rawValue:))
    }

    public var visiblePanelCards: [PanelCardKind] {
        orderedPanelCards.filter { !hiddenPanelCards.contains($0.rawValue) }
    }

    public func isPanelCardVisible(_ card: PanelCardKind) -> Bool {
        !hiddenPanelCards.contains(card.rawValue)
    }

    public func setPanelCard(_ card: PanelCardKind, visible: Bool) {
        if visible {
            hiddenPanelCards.removeAll { $0 == card.rawValue }
        } else if !hiddenPanelCards.contains(card.rawValue) {
            hiddenPanelCards.append(card.rawValue)
        }
    }

    public func movePanelCard(fromOffsets source: IndexSet, toOffset destination: Int) {
        var items = panelCardOrder
        let moving = source.sorted().compactMap { items.indices.contains($0) ? items[$0] : nil }
        guard !moving.isEmpty else { return }

        for index in source.sorted(by: >) where items.indices.contains(index) {
            items.remove(at: index)
        }
        let removedBefore = source.filter { $0 < destination }.count
        let insertion = max(0, min(items.count, destination - removedBefore))
        items.insert(contentsOf: moving, at: insertion)
        panelCardOrder = items
    }

    public static func normalizedPanelCardOrder(_ stored: [String]?) -> [String] {
        var seen: Set<String> = []
        var result: [String] = []

        for raw in stored ?? [] {
            guard let card = PanelCardKind(rawValue: raw), seen.insert(raw).inserted else { continue }
            result.append(card.rawValue)
        }
        for card in PanelCardKind.allCases where !seen.contains(card.rawValue) {
            result.append(card.rawValue)
        }
        return result
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if defaults === UserDefaults.standard {
            Self.migrateLegacyDefaults(into: defaults)
        }
        ringMetric = MetricKind(rawValue: defaults.string(forKey: Key.ringMetric) ?? "") ?? .cpu
        showsValueText = defaults.object(forKey: Key.showsValueText) as? Bool ?? true
        let storedInterval = defaults.double(forKey: Key.refreshInterval)
        refreshInterval = storedInterval > 0 ? storedInterval : 1
        let storedRetention = defaults.integer(forKey: Key.historyRetentionHours)
        historyRetentionHours = (1...24).contains(storedRetention) ? storedRetention : 24
        recordsHistoryToDisk = defaults.object(forKey: Key.recordsHistoryToDisk) as? Bool ?? false
        showsProcesses = defaults.object(forKey: Key.showsProcesses) as? Bool ?? true
        showsTemperature = defaults.object(forKey: Key.showsTemperature) as? Bool ?? true
        preventsSleep = defaults.object(forKey: Key.preventsSleep) as? Bool ?? false
        accentTheme = AccentTheme(rawValue: defaults.string(forKey: Key.accentTheme) ?? "") ?? .blue
        panelWidth = PanelWidth(rawValue: defaults.integer(forKey: Key.panelWidth)) ?? .standard
        panelDensity = PanelDensity(rawValue: defaults.string(forKey: Key.panelDensity) ?? "") ?? .standard
        panelCardOrder = Self.normalizedPanelCardOrder(defaults.stringArray(forKey: Key.panelCardOrder))
        hiddenPanelCards = (defaults.stringArray(forKey: Key.hiddenPanelCards) ?? [])
            .filter { PanelCardKind(rawValue: $0) != nil }
        let language = AppLanguage(rawValue: defaults.string(forKey: Key.appLanguage) ?? "") ?? .system
        appLanguage = language
        L10n.setLanguage(language)
        appAppearance = AppAppearance(rawValue: defaults.string(forKey: Key.appAppearance) ?? "") ?? .system
    }

    public var effectiveInterval: TimeInterval {
        let multiplier = ProcessInfo.processInfo.isLowPowerModeEnabled ? 3.0 : 1.0
        return max(0.5, refreshInterval * multiplier)
    }

    private static func migrateLegacyDefaults(into defaults: UserDefaults) {
        let domains = ["com.leo.everydevice", "com.leo.MacTool"]
        let keys = [
            Key.ringMetric,
            Key.showsValueText,
            Key.refreshInterval,
            Key.showsProcesses,
            Key.showsTemperature,
            "deviceModelIdentifier",
            "deviceModelName"
        ]

        for domain in domains {
            guard let legacy = defaults.persistentDomain(forName: domain) else { continue }
            for key in keys where defaults.object(forKey: key) == nil {
                if let value = legacy[key] {
                    defaults.set(value, forKey: key)
                }
            }
        }
    }
}
