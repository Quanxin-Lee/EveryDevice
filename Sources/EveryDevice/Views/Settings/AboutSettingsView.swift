import AppKit
import EveryDeviceCore
import SwiftUI

struct AboutSettingsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(nsImage: appIcon)
                .resizable()
                .interpolation(.high)
                .frame(width: 96, height: 96)
                .accessibilityHidden(true)

            Text(appName)
                .font(.system(size: 26, weight: .bold, design: .rounded))

            Text(versionLine)
                .font(.callout)
                .monospacedDigit()
                .foregroundStyle(.secondary)

            Text(copyrightLine)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .offset(y: -20)
        .padding(.horizontal, 24)
    }

    private var appIcon: NSImage {
        NSApp.applicationIconImage
            ?? NSImage(named: "AppIcon")
            ?? NSImage(size: NSSize(width: 96, height: 96))
    }

    private var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "EveryDevice"
    }

    private var versionLine: String {
        L10n.tr("settings.about.versionFormat", versionText, buildText)
    }

    private var versionText: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
    }

    private var buildText: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    private var copyrightLine: String {
        let holder = Bundle.main.object(forInfoDictionaryKey: "NSHumanReadableCopyright") as? String
            ?? "© 2026 Quanxin Li"
        return "\(holder) · \(L10n.tr("settings.about.rights"))"
    }
}
