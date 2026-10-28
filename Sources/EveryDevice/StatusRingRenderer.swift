import AppKit

enum RingStyle {
    case single
    case dual(download: Double, upload: Double, scale: Double)
}

enum StatusRingRenderer {
    static let canvas: CGFloat = 18

    static func image(fraction: Double?, color: NSColor, style: RingStyle) -> NSImage {
        NSImage(size: NSSize(width: canvas, height: canvas), flipped: false) { rect in
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let trackColor = NSColor.tertiaryLabelColor.withAlphaComponent(0.35)

            switch style {
            case .single:
                let radius: CGFloat = 6.4
                let lineWidth: CGFloat = 2.4
                drawTrack(center: center, radius: radius, lineWidth: lineWidth, color: trackColor)
                if let fraction, fraction > 0.001 {
                    drawArc(
                        center: center,
                        radius: radius,
                        lineWidth: lineWidth,
                        fraction: fraction,
                        color: color
                    )
                }

            case let .dual(download, upload, scale):
                let denominator = log10(1 + max(scale, 1))
                let downloadFraction = denominator > 0
                    ? log10(1 + max(0, download)) / denominator
                    : 0
                let uploadFraction = denominator > 0
                    ? log10(1 + max(0, upload)) / denominator
                    : 0

                drawTrack(center: center, radius: 7.3, lineWidth: 1.7, color: trackColor)
                drawTrack(center: center, radius: 4.4, lineWidth: 1.7, color: trackColor)
                drawArc(
                    center: center,
                    radius: 7.3,
                    lineWidth: 1.7,
                    fraction: downloadFraction,
                    color: color
                )
                drawArc(
                    center: center,
                    radius: 4.4,
                    lineWidth: 1.7,
                    fraction: uploadFraction,
                    color: color.withAlphaComponent(0.55)
                )
            }

            return true
        }
    }

    private static func drawTrack(center: CGPoint, radius: CGFloat, lineWidth: CGFloat, color: NSColor) {
        let path = NSBezierPath()
        path.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
        path.lineWidth = lineWidth
        color.setStroke()
        path.stroke()
    }

    private static func drawArc(
        center: CGPoint,
        radius: CGFloat,
        lineWidth: CGFloat,
        fraction: Double,
        color: NSColor
    ) {
        let clamped = min(1, max(0, fraction))
        guard clamped > 0 else { return }

        let path = NSBezierPath()
        path.appendArc(
            withCenter: center,
            radius: radius,
            startAngle: 90,
            endAngle: 90 - 360 * CGFloat(clamped),
            clockwise: true
        )
        path.lineWidth = lineWidth
        path.lineCapStyle = .round
        color.setStroke()
        path.stroke()
    }
}
