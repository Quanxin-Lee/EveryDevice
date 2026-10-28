import EveryDeviceCore
import SwiftUI

enum ProcessSort: Hashable {
    case cpu
    case memory
}

struct ProcessListView: View {
    let processes: [ProcessUsage]
    let unreadable: Int
    @ObservedObject var state: PanelState

    private static let visibleRows = 8
    private static let rowHeight: CGFloat = 18
    private static let rowSpacing: CGFloat = 6
    private static let listHeight = CGFloat(visibleRows) * rowHeight
        + CGFloat(visibleRows - 1) * rowSpacing

    private var sort: ProcessSort { state.processSort }

    private var rows: [ProcessUsage] {
        let sorted: [ProcessUsage]
        switch sort {
        case .cpu:
            sorted = processes.sorted { $0.cpuFraction > $1.cpuFraction }
        case .memory:
            sorted = processes.sorted { $0.memoryBytes > $1.memoryBytes }
        }
        return Array(sorted.prefix(Self.visibleRows))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(L10n.tr("panel.process.title"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 8)

                Picker(L10n.tr("panel.process.sort"), selection: $state.processSort) {
                    Text(L10n.tr("panel.process.cpu")).tag(ProcessSort.cpu)
                    Text(L10n.tr("panel.process.memory")).tag(ProcessSort.memory)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 116)
            }

            if rows.isEmpty {
                Text(L10n.tr("panel.process.collecting"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .frame(height: Self.listHeight, alignment: .center)
            } else {
                VStack(spacing: Self.rowSpacing) {
                    ForEach(0..<Self.visibleRows, id: \.self) { index in
                        if index < rows.count {
                            row(rows[index])
                        } else {
                            Color.clear
                                .frame(height: Self.rowHeight)
                        }
                    }
                }
                .frame(height: Self.listHeight, alignment: .top)
            }

            Text(
                unreadable > 0
                    ? L10n.tr("panel.process.unreadable", unreadable)
                    : " "
            )
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.tertiary)
            .lineLimit(1)
            .frame(height: 12, alignment: .leading)
        }
        .cardSurface(padding: 10)
    }

    private func row(_ process: ProcessUsage) -> some View {
        HStack(spacing: 8) {
            Text(process.name)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 4)

            Text(valueText(for: process))
                .font(.system(size: 11, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(
                    sort == .cpu
                        ? Theme.processCPUColor(process.cpuFraction)
                        : .secondary
                )
        }
        .frame(height: Self.rowHeight)
    }

    private func valueText(for process: ProcessUsage) -> String {
        switch sort {
        case .cpu:
            return Format.percentUnclamped(process.cpuFraction)
        case .memory:
            return Format.bytes(Double(process.memoryBytes))
        }
    }
}
