import SwiftUI

struct MetricCard<Content: View>: View {
    private let title: String
    private let value: String
    private let detail: String?
    private let valueColor: Color
    private let content: () -> Content

    init(
        title: String,
        value: String,
        detail: String? = nil,
        valueColor: Color = .primary,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.value = value
        self.detail = detail
        self.valueColor = valueColor
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .numericRoll(value)

            Text(detail ?? " ")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .opacity(detail == nil ? 0 : 1)

            content()
                .frame(height: 30, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(padding: 9)
    }
}

struct Sparkline: View {
    let values: [Double]
    var color: Color
    var minValue: Double = 0
    var maxValue: Double? = nil
    var height: CGFloat = 30

    var body: some View {
        Canvas { context, size in
            guard values.count > 1 else { return }

            let scale = plotScale
            drawSeries(values, color: color, fillArea: true, context: &context, size: size, scale: scale)
        }
        .frame(height: height)
    }

    private var plotScale: (lower: Double, upper: Double) {
        let lower = min(minValue, values.min() ?? minValue)
        let peak = max(maxValue ?? (values.max() ?? 1), lower + 0.0001)
        return (lower, peak)
    }

    private func yPosition(_ value: Double, size: CGSize, scale: (lower: Double, upper: Double)) -> CGFloat {
        let range = max(scale.upper - scale.lower, 0.0001)
        let ratio = min(1, max(0, (value - scale.lower) / range))
        return size.height - CGFloat(ratio) * (size.height - 1)
    }

    private func drawSeries(
        _ series: [Double],
        color: Color,
        fillArea: Bool,
        context: inout GraphicsContext,
        size: CGSize,
        scale: (lower: Double, upper: Double)
    ) {
        guard series.count > 1 else { return }

        let stepX = size.width / CGFloat(series.count - 1)
        var line = Path()

        for (index, value) in series.enumerated() {
            let point = CGPoint(
                x: CGFloat(index) * stepX,
                y: yPosition(value, size: size, scale: scale)
            )
            if index == 0 {
                line.move(to: point)
            } else {
                line.addLine(to: point)
            }
        }

        if fillArea {
            var area = line
            area.addLine(to: CGPoint(x: size.width, y: size.height))
            area.addLine(to: CGPoint(x: 0, y: size.height))
            area.closeSubpath()

            context.fill(
                area,
                with: .linearGradient(
                    Gradient(colors: [color.opacity(0.22), color.opacity(0.02)]),
                    startPoint: CGPoint(x: 0, y: 0),
                    endPoint: CGPoint(x: 0, y: size.height)
                )
            )
        }

        context.stroke(
            line,
            with: .color(color),
            style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round)
        )
    }
}

struct MeterSegment {
    let fraction: Double
    let color: Color
}

struct MeterBar: View {
    let segments: [MeterSegment]

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                ForEach(segments.indices, id: \.self) { index in
                    Rectangle()
                        .fill(segments[index].color)
                        .frame(
                            width: max(
                                0,
                                geometry.size.width * CGFloat(min(1, max(0, segments[index].fraction)))
                            )
                        )
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.08))
            .clipShape(Capsule())
        }
        .frame(height: 6)
    }
}

struct CoreBars: View {
    let values: [Double]
    var maxHeight: CGFloat = 26

    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(values.indices, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(Theme.fractionColor(values[index]))
                    .frame(
                        width: 4.5,
                        height: max(2, maxHeight * CGFloat(min(1, max(0, values[index]))))
                    )
            }
        }
        .frame(height: maxHeight, alignment: .bottom)
    }
}

struct CardLegend: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
    }
}

private struct CardSurface: ViewModifier {
    var padding: CGFloat

    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background {
                let shape = RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                shape
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .overlay {
                        shape.strokeBorder(Theme.cardHairline(for: scheme), lineWidth: 1)
                    }
            }
    }
}

extension View {
    func cardSurface(padding: CGFloat = 16) -> some View {
        modifier(CardSurface(padding: padding))
    }
}

private struct NumericRollModifier: ViewModifier {
    let value: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .contentTransition(reduceMotion ? .identity : .numericText())
            .animation(reduceMotion ? nil : Motion.value, value: value)
    }
}

extension View {
    func numericRoll(_ value: String) -> some View {
        modifier(NumericRollModifier(value: value))
    }
}
