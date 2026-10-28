import EveryDeviceCore
import SwiftUI

struct PanelSettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section {
                ThemeSwatchPicker(selection: $settings.accentTheme)
            } header: {
                Text(L10n.tr("settings.section.theme"))
            }

            Section {
                Picker(L10n.tr("settings.panelWidth"), selection: $settings.panelWidth) {
                    ForEach(PanelWidth.allCases) { width in
                        Text(width.title).tag(width)
                    }
                }
                .pickerStyle(.menu)

                Picker(L10n.tr("settings.panelDensity"), selection: $settings.panelDensity) {
                    ForEach(PanelDensity.allCases) { density in
                        Text(density.title).tag(density)
                    }
                }
                .pickerStyle(.menu)
            } header: {
                Text(L10n.tr("settings.section.layout"))
            }

            Section {
                Toggle(L10n.tr("settings.showTemperature"), isOn: $settings.showsTemperature)
                    .toggleStyle(.switch)
                Toggle(L10n.tr("settings.showProcesses"), isOn: $settings.showsProcesses)
                    .toggleStyle(.switch)

                ForEach(settings.panelCardOrder, id: \.self) { raw in
                    if let card = PanelCardKind(rawValue: raw) {
                        HStack(spacing: 10) {
                            Text(card.title)

                            Spacer(minLength: 8)

                            Button {
                                moveCard(raw, by: -1)
                            } label: {
                                Image(systemName: "chevron.up")
                            }
                            .buttonStyle(.borderless)
                            .disabled(settings.panelCardOrder.first == raw)
                            .accessibilityLabel(L10n.tr("settings.moveUp"))

                            Button {
                                moveCard(raw, by: 1)
                            } label: {
                                Image(systemName: "chevron.down")
                            }
                            .buttonStyle(.borderless)
                            .disabled(settings.panelCardOrder.last == raw)
                            .accessibilityLabel(L10n.tr("settings.moveDown"))

                            Toggle("", isOn: visibilityBinding(card))
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .accessibilityLabel(card.title)
                        }
                    }
                }
            } header: {
                Text(L10n.tr("settings.section.cards"))
            }
        }
        .formStyle(.grouped)
        .scrollEdgeEffectStyle(.soft, for: .top)
    }

    private func visibilityBinding(_ card: PanelCardKind) -> Binding<Bool> {
        Binding(
            get: { settings.isPanelCardVisible(card) },
            set: { settings.setPanelCard(card, visible: $0) }
        )
    }

    private func moveCard(_ raw: String, by offset: Int) {
        guard let index = settings.panelCardOrder.firstIndex(of: raw) else { return }
        let destination = index + offset
        guard settings.panelCardOrder.indices.contains(destination) else { return }
        settings.movePanelCard(
            fromOffsets: IndexSet(integer: index),
            toOffset: offset > 0 ? destination + 1 : destination
        )
    }
}

struct ThemeSwatchPicker: View {
    @Binding var selection: AccentTheme

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                ForEach(AccentTheme.allCases) { theme in
                    swatch(theme)
                        .frame(minWidth: 52, maxWidth: .infinity)
                }
            }

            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible(minimum: 32), spacing: 8),
                    count: 4
                ),
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(AccentTheme.allCases) { theme in
                    swatch(theme)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func swatch(_ theme: AccentTheme) -> some View {
        Button {
            selection = theme
        } label: {
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(
                                theme == .system
                                    ? Color.clear
                                    : theme.color.opacity(scheme == .dark ? 0.40 : 0.28)
                            )
                    )
                    .overlay(alignment: .bottom) {
                        if theme == .system {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [.red, .orange, .yellow, .green, .blue, .purple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(height: 3)
                                .padding(.horizontal, 8)
                                .padding(.bottom, 6)
                        } else {
                            Capsule()
                                .fill(theme.color)
                                .frame(height: 3)
                                .padding(.horizontal, 8)
                                .padding(.bottom, 6)
                        }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(
                                selection == theme ? theme.color : Color.secondary.opacity(0.22),
                                lineWidth: selection == theme ? 2 : 1
                            )
                    )
                    .frame(height: 40)

                Text(theme.title)
                    .font(.caption2)
                    .foregroundStyle(selection == theme ? .primary : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(theme.title)
        .accessibilityAddTraits(selection == theme ? .isSelected : [])
    }
}
