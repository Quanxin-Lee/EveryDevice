import Foundation

/// Lightweight runtime localization that supports following the system language
/// or an in-app override. Resources live in the SwiftPM Core resource bundle.
public enum L10n {
    private static let lock = NSLock()
    private static var selectedLanguage: AppLanguage = .system
    private static var tables: [String: [String: String]] = [:]

    public static var language: AppLanguage {
        lock.lock()
        defer { lock.unlock() }
        return resolvedLanguage(selectedLanguage)
    }

    public static var locale: Locale {
        Locale(identifier: language.resourceName ?? "en")
    }

    public static func setLanguage(_ language: AppLanguage) {
        lock.lock()
        selectedLanguage = language
        lock.unlock()
    }

    public static func tr(_ key: String) -> String {
        let resolved = language.resourceName ?? "en"
        if let value = table(resolved)[key], !value.isEmpty {
            return value
        }
        if resolved != "en", let value = table("en")[key], !value.isEmpty {
            return value
        }
        #if DEBUG
        NSLog("EveryDevice: missing localization key %@", key)
        #endif
        return key
    }

    public static func tr(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: tr(key), locale: locale, arguments: arguments)
    }

    private static func resolvedLanguage(_ language: AppLanguage) -> AppLanguage {
        language == .system ? AppLanguage.systemResolved : language
    }

    private static func table(_ language: String) -> [String: String] {
        lock.lock()
        defer { lock.unlock() }

        if let cached = tables[language] {
            return cached
        }
        let loaded = loadTable(language)
        tables[language] = loaded
        return loaded
    }

    private static func loadTable(_ language: String) -> [String: String] {
        guard let path = Bundle.module.path(forResource: language, ofType: "lproj"),
              let bundle = Bundle(path: path),
              let url = bundle.url(forResource: "Localizable", withExtension: "strings"),
              let dictionary = NSDictionary(contentsOf: url) as? [String: String] else {
            return [:]
        }
        return dictionary
    }
}
