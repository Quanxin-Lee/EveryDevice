import Foundation

public enum AppLanguage: String, CaseIterable, Codable, Sendable, Identifiable {
    case system
    case zhHans = "zh-Hans"
    case english = "en"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .system: return L10n.tr("settings.language.followSystem")
        case .zhHans: return "简体中文"
        case .english: return "English"
        }
    }

    public var resourceName: String? {
        switch self {
        case .system: return nil
        case .zhHans: return "zh-Hans"
        case .english: return "en"
        }
    }

    public static var systemResolved: AppLanguage {
        let preferred = Locale.preferredLanguages.first?.lowercased() ?? "en"
        return preferred.hasPrefix("zh") ? .zhHans : .english
    }
}
