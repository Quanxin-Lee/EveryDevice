import Combine
import Foundation

public enum AlertKind: String, CaseIterable, Codable, Sendable, Identifiable {
    case cpu
    case memory
    case temperature
    case diskFree

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .cpu: return L10n.tr("alert.cpu.title")
        case .memory: return L10n.tr("alert.memory.title")
        case .temperature: return L10n.tr("alert.temperature.title")
        case .diskFree: return L10n.tr("alert.diskFree.title")
        }
    }

    public var alertTitle: String {
        switch self {
        case .cpu: return L10n.tr("alert.cpu.notification")
        case .memory: return L10n.tr("alert.memory.notification")
        case .temperature: return L10n.tr("alert.temperature.notification")
        case .diskFree: return L10n.tr("alert.diskFree.notification")
        }
    }

    public var triggersBelow: Bool {
        self == .diskFree
    }

    public var isFraction: Bool {
        self != .temperature
    }

    public var defaultThreshold: Double {
        switch self {
        case .cpu: return 0.90
        case .memory: return 0.90
        case .temperature: return 95
        case .diskFree: return 0.10
        }
    }

    public var defaultConsecutiveSamples: Int {
        switch self {
        case .cpu, .memory, .diskFree: return 5
        case .temperature: return 3
        }
    }

    public var defaultHysteresis: Double {
        switch self {
        case .cpu, .memory: return 0.05
        case .temperature: return 5
        case .diskFree: return 0.02
        }
    }

    public var defaultCooldown: TimeInterval {
        switch self {
        case .cpu, .memory, .temperature: return 900
        case .diskFree: return 3_600
        }
    }

    /// Editable threshold bounds in the units shown to the user (percent or °C).
    public var displayThresholdRange: ClosedRange<Double> {
        switch self {
        case .cpu, .memory: return 50...99
        case .temperature: return 60...110
        case .diskFree: return 1...50
        }
    }

    /// Editable hysteresis bounds in the units shown to the user (percent or °C).
    public var displayHysteresisRange: ClosedRange<Double> {
        switch self {
        case .cpu, .memory, .diskFree: return 1...20
        case .temperature: return 1...15
        }
    }

    public var consecutiveSamplesRange: ClosedRange<Double> {
        1...30
    }

    public var cooldownMinutesRange: ClosedRange<Double> {
        1...120
    }

    public func format(_ value: Double) -> String {
        if isFraction {
            return "\(Int((min(1, max(0, value)) * 100).rounded()))%"
        }
        return L10n.tr("format.temperature", value)
    }

    public func displayThreshold(_ threshold: Double) -> Double {
        isFraction ? threshold * 100 : threshold
    }

    public func threshold(fromDisplay value: Double) -> Double {
        isFraction ? value / 100 : value
    }

    public func displayHysteresis(_ hysteresis: Double) -> Double {
        isFraction ? hysteresis * 100 : hysteresis
    }

    public func hysteresis(fromDisplay value: Double) -> Double {
        isFraction ? value / 100 : value
    }
}

public struct AlertRule: Codable, Sendable, Equatable, Identifiable {
    public var kind: AlertKind
    public var enabled: Bool
    public var threshold: Double
    public var consecutiveSamples: Int
    public var hysteresis: Double
    public var cooldown: TimeInterval

    public var id: String { kind.rawValue }

    public init(
        kind: AlertKind,
        enabled: Bool,
        threshold: Double,
        consecutiveSamples: Int,
        hysteresis: Double,
        cooldown: TimeInterval
    ) {
        self.kind = kind
        self.enabled = enabled
        self.threshold = threshold
        self.consecutiveSamples = consecutiveSamples
        self.hysteresis = hysteresis
        self.cooldown = cooldown
    }

    public static func defaultRule(for kind: AlertKind) -> AlertRule {
        AlertRule(
            kind: kind,
            enabled: false,
            threshold: kind.defaultThreshold,
            consecutiveSamples: kind.defaultConsecutiveSamples,
            hysteresis: kind.defaultHysteresis,
            cooldown: kind.defaultCooldown
        )
    }

    public var usesDefaultParameters: Bool {
        let defaults = AlertRule.defaultRule(for: kind)
        return threshold == defaults.threshold
            && consecutiveSamples == defaults.consecutiveSamples
            && hysteresis == defaults.hysteresis
            && cooldown == defaults.cooldown
    }
}

public final class AlertSettings: ObservableObject {
    private enum Key {
        static let rules = "alertRules.v1"
    }

    @Published public var rules: [AlertRule] {
        didSet { persist() }
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        rules = Self.load(from: defaults)
    }

    public func rule(for kind: AlertKind) -> AlertRule? {
        rules.first { $0.kind == kind }
    }

    public func update(_ rule: AlertRule) {
        guard let index = rules.firstIndex(where: { $0.kind == rule.kind }) else { return }
        var next = rules
        next[index] = rule
        rules = next
    }

    public var hasCustomParameters: Bool {
        rules.contains { !$0.usesDefaultParameters }
    }

    public func restoreDefaultParameters() {
        rules = rules.map { rule in
            var restored = AlertRule.defaultRule(for: rule.kind)
            restored.enabled = rule.enabled
            return restored
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(rules) else { return }
        defaults.set(data, forKey: Key.rules)
    }

    private static func load(from defaults: UserDefaults) -> [AlertRule] {
        let fallback = AlertKind.allCases.map(AlertRule.defaultRule)
        guard let data = defaults.data(forKey: Key.rules),
              let decoded = try? JSONDecoder().decode([AlertRule].self, from: data) else {
            return fallback
        }

        var merged = decoded
        for kind in AlertKind.allCases where !merged.contains(where: { $0.kind == kind }) {
            merged.append(AlertRule.defaultRule(for: kind))
        }

        let order = Dictionary(
            uniqueKeysWithValues: AlertKind.allCases.enumerated().map { ($0.element, $0.offset) }
        )
        return merged.sorted { (order[$0.kind] ?? 0) < (order[$1.kind] ?? 0) }
    }
}
