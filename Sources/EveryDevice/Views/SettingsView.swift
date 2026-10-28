import EveryDeviceCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var power: PowerController
    @ObservedObject var alertSettings: AlertSettings
    @ObservedObject var notifications: NotificationCoordinator
    let recorder: MetricsRecorder

    @State private var page: SettingsPage = .general

    var body: some View {
        NavigationSplitView {
            List(SettingsPage.allCases, selection: $page) { item in
                HStack(spacing: 9) {
                    Image(systemName: item.symbol)
                        .foregroundStyle(item.tint)
                        .frame(width: 18)
                    Text(item.title)
                }
                .tag(item)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(117)
            .toolbar(removing: .sidebarToggle)
        } detail: {
            detail
                .navigationTitle(page.title)
                .scrollIndicators(.hidden)
        }
        .navigationSplitViewStyle(.balanced)
        .environment(\.locale, L10n.locale)
        .onAppear {
            notifications.refreshStatus()
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch page {
        case .general:
            GeneralSettingsView(settings: settings, power: power)
        case .panel:
            PanelSettingsView(settings: settings)
        case .alerts:
            AlertsSettingsView(alertSettings: alertSettings, notifications: notifications)
        case .data:
            DataSettingsView(settings: settings, recorder: recorder)
        case .about:
            AboutSettingsView()
        }
    }
}
