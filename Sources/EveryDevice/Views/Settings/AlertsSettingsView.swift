import EveryDeviceCore
import SwiftUI
import UserNotifications

struct AlertsSettingsView: View {
    @ObservedObject var alertSettings: AlertSettings
    @ObservedObject var notifications: NotificationCoordinator

    var body: some View {
        Form {
            Section {
                permissionRow
            } header: {
                Text(L10n.tr("settings.section.notifications"))
            }

            ForEach(AlertKind.allCases) { kind in
                alertSection(kind)
            }

            Section {
                Text(L10n.tr("settings.alerts.footnote"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button(L10n.tr("settings.alerts.restore")) {
                    alertSettings.restoreDefaultParameters()
                }
                .disabled(!alertSettings.hasCustomParameters)

                Text(L10n.tr("settings.alerts.restore.note"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollEdgeEffectStyle(.soft, for: .top)
        .onAppear {
            notifications.refreshStatus()
        }
    }

    @ViewBuilder
    private var permissionRow: some View {
        switch notifications.status {
        case .authorized, .provisional:
            Label(L10n.tr("settings.notifications.allowed"), systemImage: "checkmark.circle")
                .foregroundStyle(.secondary)
        case .denied:
            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.tr("settings.notifications.denied"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button(L10n.tr("settings.notifications.openSystem")) {
                    notifications.openSystemSettings()
                }
                .buttonStyle(.bordered)
            }
        default:
            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.tr("settings.notifications.hint"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button(L10n.tr("settings.notifications.request")) {
                    notifications.requestPermission()
                }
                .buttonStyle(.bordered)
            }
        }
    }

    @ViewBuilder
    private func alertSection(_ kind: AlertKind) -> some View {
        if let rule = alertSettings.rule(for: kind) {
            Section {
                Toggle(L10n.tr("settings.alert.enable"), isOn: enabledBinding(kind))
                    .toggleStyle(.switch)

                if rule.enabled {
                    alertRow(
                        L10n.tr("settings.alert.threshold"),
                        value: kind.format(rule.threshold),
                        binding: thresholdBinding(kind),
                        range: kind.displayThresholdRange
                    )
                    alertRow(
                        L10n.tr("settings.alert.samples"),
                        value: L10n.tr("settings.alert.samplesValue", rule.consecutiveSamples),
                        binding: samplesBinding(kind),
                        range: kind.consecutiveSamplesRange
                    )
                    alertRow(
                        L10n.tr("settings.alert.hysteresis"),
                        value: kind.format(rule.hysteresis),
                        binding: hysteresisBinding(kind),
                        range: kind.displayHysteresisRange
                    )
                    alertRow(
                        L10n.tr("settings.alert.cooldown"),
                        value: L10n.tr("settings.alert.minutesValue", Int((rule.cooldown / 60).rounded())),
                        binding: cooldownBinding(kind),
                        range: kind.cooldownMinutesRange
                    )
                }
            } header: {
                Text(kind.title)
            }
        }
    }

    private func alertRow(
        _ title: String,
        value: String,
        binding: Binding<Double>,
        range: ClosedRange<Double>
    ) -> some View {
        LabeledContent {
            HStack(spacing: 8) {
                Text(value)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Stepper("", value: binding, in: range, step: 1)
                    .labelsHidden()
                    .accessibilityLabel(title)
                    .accessibilityValue(value)
            }
        } label: {
            Text(title)
        }
    }

    private func enabledBinding(_ kind: AlertKind) -> Binding<Bool> {
        Binding(
            get: { alertSettings.rule(for: kind)?.enabled ?? false },
            set: { enabled in
                guard var rule = alertSettings.rule(for: kind) else { return }
                rule.enabled = enabled
                alertSettings.update(rule)
                if enabled {
                    notifications.requestPermissionIfNeeded()
                }
            }
        )
    }

    private func thresholdBinding(_ kind: AlertKind) -> Binding<Double> {
        Binding(
            get: {
                guard let rule = alertSettings.rule(for: kind) else { return 0 }
                return kind.displayThreshold(rule.threshold)
            },
            set: { newValue in
                guard var rule = alertSettings.rule(for: kind) else { return }
                rule.threshold = kind.threshold(fromDisplay: newValue)
                alertSettings.update(rule)
            }
        )
    }

    private func samplesBinding(_ kind: AlertKind) -> Binding<Double> {
        Binding(
            get: {
                guard let rule = alertSettings.rule(for: kind) else { return 1 }
                return Double(rule.consecutiveSamples)
            },
            set: { newValue in
                guard var rule = alertSettings.rule(for: kind) else { return }
                rule.consecutiveSamples = Int(newValue.rounded())
                alertSettings.update(rule)
            }
        )
    }

    private func hysteresisBinding(_ kind: AlertKind) -> Binding<Double> {
        Binding(
            get: {
                guard let rule = alertSettings.rule(for: kind) else { return 0 }
                return kind.displayHysteresis(rule.hysteresis)
            },
            set: { newValue in
                guard var rule = alertSettings.rule(for: kind) else { return }
                rule.hysteresis = kind.hysteresis(fromDisplay: newValue)
                alertSettings.update(rule)
            }
        )
    }

    private func cooldownBinding(_ kind: AlertKind) -> Binding<Double> {
        Binding(
            get: {
                guard let rule = alertSettings.rule(for: kind) else { return 1 }
                return (rule.cooldown / 60).rounded()
            },
            set: { newValue in
                guard var rule = alertSettings.rule(for: kind) else { return }
                rule.cooldown = newValue.rounded() * 60
                alertSettings.update(rule)
            }
        )
    }
}
