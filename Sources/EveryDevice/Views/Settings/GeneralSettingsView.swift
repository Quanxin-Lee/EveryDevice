import AppKit
import Combine
import EveryDeviceCore
import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var power: PowerController

    @State private var launchAtLogin = LoginItemManager.isEnabled
    @State private var loginMessage: String?

    var body: some View {
        Form {
            Section {
                Picker(L10n.tr("settings.ringMetric"), selection: $settings.ringMetric) {
                    ForEach(MetricKind.allCases) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                .pickerStyle(.menu)

                Toggle(L10n.tr("settings.showValue"), isOn: $settings.showsValueText)
                    .toggleStyle(.switch)
            } header: {
                Text(L10n.tr("settings.section.menuBar"))
            }

            Section {
                Picker(L10n.tr("settings.refreshInterval"), selection: $settings.refreshInterval) {
                    Text(L10n.tr("settings.interval.1s")).tag(1.0)
                    Text(L10n.tr("settings.interval.2s")).tag(2.0)
                    Text(L10n.tr("settings.interval.5s")).tag(5.0)
                }
                .pickerStyle(.menu)
            } header: {
                Text(L10n.tr("settings.section.refresh"))
            }

            Section {
                Toggle(L10n.tr("settings.launchAtLogin"), isOn: $launchAtLogin)
                    .toggleStyle(.switch)
                    .onChange(of: launchAtLogin) { _, enabled in
                        updateLoginItem(enabled)
                    }

                if let loginMessage {
                    Text(loginMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text(L10n.tr("settings.section.launch"))
            }

            Section {
                Toggle(L10n.tr("settings.keepAwake"), isOn: $settings.preventsSleep)
                    .toggleStyle(.switch)

                if settings.preventsSleep, !power.isActive {
                    Label(L10n.tr("settings.power.rejected"), systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            } header: {
                Text(L10n.tr("settings.section.power"))
            }

            Section {
                Picker(L10n.tr("settings.language"), selection: $settings.appLanguage) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .pickerStyle(.menu)
            } header: {
                Text(L10n.tr("settings.section.language"))
            }

            Section {
                Picker(L10n.tr("settings.appearance"), selection: $settings.appAppearance) {
                    ForEach(AppAppearance.allCases) { appearance in
                        Text(appearance.title).tag(appearance)
                    }
                }
                .pickerStyle(.menu)
            } header: {
                Text(L10n.tr("settings.section.appearance"))
            }
        }
        .formStyle(.grouped)
        .scrollEdgeEffectStyle(.soft, for: .top)
        .onAppear {
            refreshLoginItemState()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshLoginItemState()
        }
    }

    private func updateLoginItem(_ enabled: Bool) {
        do {
            try LoginItemManager.setEnabled(enabled)
            loginMessage = LoginItemManager.requiresApproval
                ? L10n.tr("settings.launch.approval")
                : nil
        } catch {
            loginMessage = error.localizedDescription
            launchAtLogin = LoginItemManager.isEnabled
        }
    }

    private func refreshLoginItemState() {
        launchAtLogin = LoginItemManager.isEnabled
        if LoginItemManager.requiresApproval {
            loginMessage = L10n.tr("settings.launch.approval")
        }
    }
}
