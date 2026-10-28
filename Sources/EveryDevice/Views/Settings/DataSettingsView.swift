import AppKit
import EveryDeviceCore
import SwiftUI
import UniformTypeIdentifiers

struct DataSettingsView: View {
    @ObservedObject var settings: AppSettings
    let recorder: MetricsRecorder

    @State private var isExporting = false
    @State private var exportMessage: String?

    var body: some View {
        Form {
            Section {
                HStack(spacing: 10) {
                    Text(L10n.tr("settings.retention"))
                    Spacer(minLength: 8)
                    Text(L10n.tr("settings.retention.value", settings.historyRetentionHours))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    Stepper(
                        "",
                        value: retentionBinding,
                        in: MetricsRecorder.retentionRange
                    )
                    .labelsHidden()
                    .accessibilityLabel(L10n.tr("settings.retention"))
                }

                Text(L10n.tr("settings.retention.note"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text(L10n.tr("settings.section.recording"))
            }

            Section {
                HStack(spacing: 8) {
                    Button(L10n.tr("settings.exportAll")) {
                        exportAll()
                    }
                    .disabled(isExporting)

                    if isExporting {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                Text(L10n.tr("settings.export.note"))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let exportMessage {
                    Text(exportMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            } header: {
                Text(L10n.tr("settings.section.export"))
            }
        }
        .formStyle(.grouped)
        .scrollEdgeEffectStyle(.soft, for: .top)
    }

    private var retentionBinding: Binding<Int> {
        Binding(
            get: { settings.historyRetentionHours },
            set: { value in
                let range = MetricsRecorder.retentionRange
                settings.historyRetentionHours = min(range.upperBound, max(range.lowerBound, value))
            }
        )
    }

    private func exportAll() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = Self.defaultFileName()
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        isExporting = true
        exportMessage = L10n.tr("settings.export.inProgress")

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let count = try recorder.exportAll(to: url)
                DispatchQueue.main.async {
                    isExporting = false
                    exportMessage = L10n.tr("settings.export.success", count, url.path)
                }
            } catch {
                DispatchQueue.main.async {
                    isExporting = false
                    exportMessage = L10n.tr("settings.export.failure", error.localizedDescription)
                }
            }
        }
    }

    private static func defaultFileName() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "EveryDevice-All-Data-\(formatter.string(from: Date())).csv"
    }
}
