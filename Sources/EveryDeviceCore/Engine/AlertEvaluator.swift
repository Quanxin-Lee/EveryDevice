import Foundation

public struct AlertEvent: Sendable, Equatable {
    public var kind: AlertKind
    public var value: Double
    public var threshold: Double
    public var duration: TimeInterval

    public init(kind: AlertKind, value: Double, threshold: Double, duration: TimeInterval) {
        self.kind = kind
        self.value = value
        self.threshold = threshold
        self.duration = duration
    }

    public var title: String {
        kind.alertTitle
    }

    public var body: String {
        L10n.tr(
            "alert.body",
            kind.format(value),
            kind.format(threshold),
            Self.durationText(duration)
        )
    }

    private static func durationText(_ seconds: TimeInterval) -> String {
        let value = max(0, seconds)
        if value < 60 {
            return L10n.tr("alert.duration.seconds", Int(value.rounded()))
        }
        let minutes = Int(value / 60)
        if minutes < 60 {
            return L10n.tr("alert.duration.minutes", minutes)
        }
        return L10n.tr("alert.duration.hours", minutes / 60, minutes % 60)
    }
}

public final class AlertEvaluator {
    private struct State {
        var consecutive = 0
        var since: Date?
        var recovery = 0
        var latched = false
        var lastFired: Date?
    }

    private var states: [AlertKind: State] = [:]

    public init() {}

    public func reset() {
        states.removeAll()
    }

    public func evaluate(
        snapshot: MetricsSnapshot,
        fresh: SampleMask,
        rules: [AlertRule],
        now: Date
    ) -> [AlertEvent] {
        var events: [AlertEvent] = []

        for rule in rules where rule.enabled {
            guard isFresh(rule.kind, in: fresh) else { continue }
            guard let value = value(for: rule.kind, in: snapshot), value.isFinite else { continue }

            var state = states[rule.kind] ?? State()
            let triggered = rule.kind.triggersBelow
                ? value < rule.threshold
                : value >= rule.threshold

            if triggered {
                if state.since == nil { state.since = now }
                state.consecutive += 1
                state.recovery = 0

                if !state.latched, state.consecutive >= max(1, rule.consecutiveSamples) {
                    let cooling = state.lastFired.map {
                        now.timeIntervalSince($0) < rule.cooldown
                    } ?? false

                    if !cooling {
                        events.append(
                            AlertEvent(
                                kind: rule.kind,
                                value: value,
                                threshold: rule.threshold,
                                duration: max(0, now.timeIntervalSince(state.since ?? now))
                            )
                        )
                        state.lastFired = now
                        state.latched = true
                    }
                }
            } else {
                state.consecutive = 0
                state.since = nil

                let recovered = rule.kind.triggersBelow
                    ? value >= rule.threshold + rule.hysteresis
                    : value <= rule.threshold - rule.hysteresis

                if recovered {
                    state.recovery += 1
                    if state.recovery >= 2 {
                        state.latched = false
                        state.recovery = 0
                    }
                } else {
                    state.recovery = 0
                }
            }

            states[rule.kind] = state
        }

        return events
    }

    private func isFresh(_ kind: AlertKind, in mask: SampleMask) -> Bool {
        switch kind {
        case .cpu: return mask.contains(.cpu)
        case .memory: return mask.contains(.memory)
        case .temperature: return mask.contains(.thermal)
        case .diskFree: return mask.contains(.disk)
        }
    }

    private func value(for kind: AlertKind, in snapshot: MetricsSnapshot) -> Double? {
        switch kind {
        case .cpu:
            return snapshot.cpu.total
        case .memory:
            return snapshot.memory.usedFraction
        case .temperature:
            return snapshot.thermal.cpuCelsius
        case .diskFree:
            guard snapshot.disk.totalBytes > 0 else { return nil }
            return Double(snapshot.disk.freeBytes) / Double(snapshot.disk.totalBytes)
        }
    }
}
