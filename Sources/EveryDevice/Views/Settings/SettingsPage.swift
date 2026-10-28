import AppKit
import EveryDeviceCore
import Foundation
import SwiftUI

enum SettingsPage: String, CaseIterable, Identifiable {
    case general
    case panel
    case alerts
    case data
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return L10n.tr("settings.page.general")
        case .panel: return L10n.tr("settings.page.panel")
        case .alerts: return L10n.tr("settings.page.alerts")
        case .data: return L10n.tr("settings.page.data")
        case .about: return L10n.tr("settings.page.about")
        }
    }

    var symbol: String {
        switch self {
        case .general: return "gearshape"
        case .panel: return "menubar.rectangle"
        case .alerts: return "bell"
        case .data: return "externaldrive"
        case .about: return "info.circle"
        }
    }

    var tint: Color {
        switch self {
        case .general: return Color(nsColor: .systemGray)
        case .panel: return Color(nsColor: .systemBlue)
        case .alerts: return Color(nsColor: .systemOrange)
        case .data: return Color(nsColor: .systemIndigo)
        case .about: return Color(nsColor: .systemTeal)
        }
    }
}
