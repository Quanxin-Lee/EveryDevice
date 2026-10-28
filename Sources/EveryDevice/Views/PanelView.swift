import EveryDeviceCore
import SwiftUI

struct PanelView: View {
    @ObservedObject var store: MetricsStore
    @ObservedObject var settings: AppSettings
    @ObservedObject var device: DeviceInfoStore
    @ObservedObject var panelState: PanelState
    var scrolls = false

    private var accent: Color { settings.accentTheme.color }

    private var snapshot: MetricsSnapshot { store.snapshot }
    private var history: MetricHistory { store.history }

    private var cpuHistory: [Double] {
        history.cpuValues(endingAt: snapshot.timestamp)
    }

    private var gpuHistory: [Double] {
        history.gpuValues(endingAt: snapshot.timestamp)
    }

    private var downloadHistory: [Double] {
        history.downloadValues(endingAt: snapshot.timestamp)
    }

    private var uploadHistory: [Double] {
        history.uploadValues(endingAt: snapshot.timestamp)
    }

    private var temperatureHistory: [Double] {
        history.temperatureValues(endingAt: snapshot.timestamp)
    }

    private var spacing: CGFloat {
        settings.panelDensity == .compact ? 8 : 10
    }

    private var contentPadding: CGFloat {
        settings.panelDensity == .compact ? 10 : 12
    }

    private var cards: [PanelCardKind] {
        settings.visiblePanelCards
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            if scrolls {
                ScrollView(.vertical, showsIndicators: true) {
                    content
                }
            } else {
                content
            }
        }
        .background(PanelWash(theme: settings.accentTheme))
        .tint(settings.accentTheme.color)
        .environment(\.locale, L10n.locale)
    }

    private var content: some View {
        VStack(spacing: spacing) {
            cardRows

            if settings.showsTemperature {
                temperatureCard
            }

            if settings.showsProcesses {
                ProcessListView(
                    processes: snapshot.processes,
                    unreadable: snapshot.unreadableProcessCount,
                    state: panelState
                )
            }
        }
        .padding(.horizontal, contentPadding)
        .padding(.bottom, contentPadding)
    }

    private var cardRows: some View {
        VStack(spacing: spacing) {
            ForEach(Array(stride(from: 0, to: cards.count, by: 2)), id: \.self) { index in
                HStack(alignment: .top, spacing: spacing) {
                    panelCard(cards[index])

                    if index + 1 < cards.count {
                        panelCard(cards[index + 1])
                    } else {
                        Color.clear
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private var header: some View {
        Text(device.info.displayName)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
    }

    @ViewBuilder
    private func panelCard(_ card: PanelCardKind) -> some View {
        switch card {
        case .cpu: cpuCard
        case .gpu: gpuCard
        case .memory: memoryCard
        case .network: networkCard
        case .disk: diskCard
        case .battery: batteryCard
        }
    }

    private var cpuCard: some View {
        MetricCard(
            title: L10n.tr("metric.cpu.title"),
            value: Format.percent(snapshot.cpu.total),
            detail: cpuDetail,
            valueColor: Theme.fractionColor(snapshot.cpu.total)
        ) {
            HStack(alignment: .bottom, spacing: 8) {
                Sparkline(
                    values: cpuHistory,
                    color: accent,
                    maxValue: 1,
                    height: 30
                )
                CoreBars(values: snapshot.cpu.cores, maxHeight: 26)
            }
        }
    }

    private var cpuDetail: String {
        L10n.tr(
            "panel.cpu.detail",
            ProcessInfo.processInfo.processorCount,
            String(format: "%.2f", snapshot.cpu.loadAverage)
        )
    }

    private var gpuCard: some View {
        MetricCard(
            title: L10n.tr("metric.gpu.title"),
            value: Format.percent(snapshot.gpu.utilization),
            detail: gpuDetail,
            valueColor: Theme.fractionColor(snapshot.gpu.utilization)
        ) {
            Sparkline(
                values: gpuHistory,
                color: accent,
                maxValue: 1,
                height: 30
            )
        }
    }

    private var gpuDetail: String {
        if snapshot.gpu.isStale { return L10n.tr("panel.gpu.stale") }
        guard let memory = snapshot.gpu.memoryInUseBytes else {
            return L10n.tr("panel.gpu.unavailable")
        }
        return L10n.tr("panel.gpu.memory", Format.bytes(Double(memory)))
    }

    private var memoryCard: some View {
        MetricCard(
            title: L10n.tr("metric.memory.title"),
            value: Format.percent(snapshot.memory.usedFraction),
            detail: memoryDetail,
            valueColor: Theme.fractionColor(snapshot.memory.usedFraction)
        ) {
            VStack(alignment: .leading, spacing: 6) {
                MeterBar(segments: memorySegments)
                CardLegend(
                    text: L10n.tr(
                        "panel.memory.swap",
                        Format.bytes(Double(snapshot.memory.swapUsedBytes))
                    )
                )
            }
        }
    }

    private var memoryDetail: String {
        "\(Format.bytes(Double(snapshot.memory.usedBytes))) / \(Format.bytes(Double(snapshot.memory.totalBytes)))"
    }

    private var memorySegments: [MeterSegment] {
        let total = Double(max(1, snapshot.memory.totalBytes))
        return [
            MeterSegment(fraction: Double(snapshot.memory.appBytes) / total, color: accent),
            MeterSegment(fraction: Double(snapshot.memory.wiredBytes) / total, color: Theme.accentSecondary),
            MeterSegment(fraction: Double(snapshot.memory.compressedBytes) / total, color: accent.opacity(0.45))
        ]
    }

    private var networkCard: some View {
        MetricCard(
            title: L10n.tr("metric.network.title"),
            value: "↓ \(Format.rate(snapshot.network.downloadBytesPerSec))",
            detail: "↑ \(Format.rate(snapshot.network.uploadBytesPerSec))",
            valueColor: accent
        ) {
            ZStack {
                Sparkline(
                    values: downloadHistory,
                    color: accent,
                    maxValue: networkPeak,
                    height: 30
                )
                Sparkline(
                    values: uploadHistory,
                    color: Theme.accentSecondary,
                    maxValue: networkPeak,
                    height: 30
                )
            }
        }
    }

    private var networkPeak: Double {
        max(1024, history.networkPeak(endingAt: snapshot.timestamp) * 1.1)
    }

    private var diskCard: some View {
        MetricCard(
            title: L10n.tr("metric.disk.title"),
            value: Format.rate(snapshot.disk.readBytesPerSec),
            detail: L10n.tr(
                "panel.disk.writeRate",
                Format.rate(snapshot.disk.writeBytesPerSec)
            ),
            valueColor: .primary
        ) {
            VStack(alignment: .leading, spacing: 6) {
                MeterBar(
                    segments: [
                        MeterSegment(
                            fraction: snapshot.disk.usedFraction,
                            color: Theme.fractionColor(snapshot.disk.usedFraction)
                        )
                    ]
                )
                CardLegend(
                    text: L10n.tr(
                        "panel.disk.free",
                        Format.bytes(Double(snapshot.disk.freeBytes)),
                        Format.bytes(Double(snapshot.disk.totalBytes))
                    )
                )
            }
        }
    }

    private var batteryCard: some View {
        MetricCard(
            title: L10n.tr("metric.battery.title"),
            value: Format.percent(snapshot.battery.percentage),
            detail: batteryDetail,
            valueColor: Theme.batteryColor(snapshot.battery.percentage)
        ) {
            VStack(alignment: .leading, spacing: 6) {
                MeterBar(
                    segments: [
                        MeterSegment(
                            fraction: snapshot.battery.percentage ?? 0,
                            color: Theme.batteryColor(snapshot.battery.percentage)
                        )
                    ]
                )
                CardLegend(text: batteryLegend)
            }
        }
    }

    private var batteryDetail: String {
        guard snapshot.battery.isPresent else { return L10n.tr("panel.battery.absent") }
        if snapshot.battery.isFullyCharged { return L10n.tr("panel.battery.charged") }
        if snapshot.battery.isCharging { return L10n.tr("panel.battery.charging") }
        if snapshot.battery.isPluggedIn { return L10n.tr("panel.battery.pluggedIn") }
        return L10n.tr("panel.battery.onBattery")
    }

    private var batteryLegend: String {
        guard snapshot.battery.isPresent else { return "—" }
        if snapshot.battery.isCharging, let seconds = snapshot.battery.timeToFullSeconds {
            return L10n.tr("panel.battery.timeToFull", Format.duration(seconds: seconds))
        }
        if let seconds = snapshot.battery.timeRemainingSeconds {
            return L10n.tr("panel.battery.timeRemaining", Format.duration(seconds: seconds))
        }
        return "—"
    }

    private var temperatureCard: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text(L10n.tr("metric.temperature.title"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text(temperatureValue)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.temperatureColor(snapshot.thermal.cpuCelsius))
                    .lineLimit(1)

                Text(temperatureDetail)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 8)

            Sparkline(
                values: temperatureHistory,
                color: Theme.temperatureColor(snapshot.thermal.cpuCelsius),
                minValue: 30,
                maxValue: max(70, history.temperaturePeak(endingAt: snapshot.timestamp) + 3),
                height: 40
            )
            .frame(width: 148)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(padding: 9)
    }

    private var temperatureValue: String {
        if snapshot.thermal.sensorAvailable {
            return Format.temperature(snapshot.thermal.cpuCelsius)
        }
        return snapshot.thermal.pressure.title
    }

    private var temperatureDetail: String {
        guard snapshot.thermal.sensorAvailable else {
            return L10n.tr("panel.temperature.unavailable")
        }
        return L10n.tr(
            "panel.temperature.gpuDetail",
            Format.temperature(snapshot.thermal.gpuCelsius),
            snapshot.thermal.pressure.title
        )
    }
}
