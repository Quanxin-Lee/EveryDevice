import AppKit
import Combine
import EveryDeviceCore
import SwiftUI

final class StatusItemController: NSObject {
    private let statusItem: NSStatusItem
    private let store: MetricsStore
    private let settings: AppSettings
    private let device: DeviceInfoStore
    private let panelState = PanelState()
    private let onOpenSettings: () -> Void
    private let onQuit: () -> Void
    private let onPanelVisibilityChange: ((Bool) -> Void)?
    private lazy var dropdown = makeDropdown()

    private var cancellables: Set<AnyCancellable> = []
    private var lastTitle: String?
    private var lastImageSignature: String?
    private var lastRingImage: NSImage?
    private var lastTooltip: String?
    private var isPresentingMenu = false
    private let speedContainer = PassthroughView()
    private let speedRing = NSImageView()
    private let speedText = NSTextField(labelWithString: "")
    private var isSpeedViewInstalled = false
    private var isShowingSpeedView = false

    // Keeps the status button at its usual 22pt height while the speed view
    // supplies the visible content; an empty button would collapse to zero
    // height and move the panel anchor up into the menu bar.
    private static let speedSpacerImage: NSImage = {
        let image = NSImage(
            size: NSSize(width: 1, height: 22),
            flipped: false
        ) { _ in true }
        image.isTemplate = true
        return image
    }()

    init(
        store: MetricsStore,
        settings: AppSettings,
        device: DeviceInfoStore,
        onOpenSettings: @escaping () -> Void,
        onQuit: @escaping () -> Void,
        onPanelVisibilityChange: ((Bool) -> Void)? = nil
    ) {
        self.store = store
        self.settings = settings
        self.device = device
        self.onOpenSettings = onOpenSettings
        self.onQuit = onQuit
        self.onPanelVisibilityChange = onPanelVisibilityChange

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        super.init()

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(handleClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.imagePosition = .imageLeft
            button.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .medium)
            button.setAccessibilityLabel(L10n.tr("status.accessibility"))
        }

        if #available(macOS 27.0, *) {
            statusItem.expandedInterfaceDelegate = self
        }

        _ = dropdown
        dropdown.closesOnStatusClick = usesExpandedInterface
        dropdown.makeKeyWhenInactive = usesExpandedInterface
        dropdown.onVisibilityChange = { [weak self] visible in
            guard let self else { return }
            self.onPanelVisibilityChange?(visible)
            if #available(macOS 27.0, *), !visible {
                self.statusItem.expandedInterfaceSession?.cancel()
            }
        }

        store.$snapshot
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)

        settings.objectWillChange
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.refresh() }
            }
            .store(in: &cancellables)

        refresh()
    }

    private func refresh() {
        guard let button = statusItem.button else { return }

        let snapshot = store.snapshot
        let metric = settings.ringMetric
        let color = Theme.statusColor(metric: metric, snapshot: snapshot)

        let style: RingStyle
        if metric == .network {
            let peak = max(
                store.history.networkPeak(endingAt: snapshot.timestamp),
                1_048_576
            ) * 1.2
            style = .dual(
                download: snapshot.network.downloadBytesPerSec,
                upload: snapshot.network.uploadBytesPerSec,
                scale: peak
            )
        } else {
            style = .single
        }

        let imageSignature: String
        switch style {
        case .single:
            let value = Int(((metric.fraction(in: snapshot) ?? -1) * 100).rounded())
            imageSignature = "\(metric.rawValue)|\(value)"
        case let .dual(download, upload, scale):
            imageSignature = "network|\(Int(download / 1024))|\(Int(upload / 1024))|\(Int(scale / 1024))"
        }

        if imageSignature != lastImageSignature {
            lastRingImage = StatusRingRenderer.image(
                fraction: metric.fraction(in: snapshot),
                color: color,
                style: style
            )
            lastImageSignature = imageSignature
        }
        guard let ringImage = lastRingImage else { return }

        let showsSpeedView = metric == .network && settings.showsValueText
        if showsSpeedView {
            installSpeedViewIfNeeded()
            let text = Format.menuBarText(metric: metric, snapshot: snapshot)
            if !isShowingSpeedView {
                isShowingSpeedView = true
                button.image = Self.speedSpacerImage
                button.attributedTitle = NSAttributedString(string: "")
                lastTitle = nil
                speedContainer.isHidden = false
            }
            if speedRing.image !== ringImage {
                speedRing.image = ringImage
            }
            if speedText.stringValue != text {
                speedText.stringValue = text
            }
            let length = speedItemLength(for: text)
            if abs(statusItem.length - length) > 0.01 {
                statusItem.length = length
            }
        } else {
            if isShowingSpeedView {
                isShowingSpeedView = false
                speedContainer.isHidden = true
                lastTitle = nil
                statusItem.length = NSStatusItem.variableLength
            }
            if button.image !== ringImage {
                button.image = ringImage
            }
            let title = settings.showsValueText
                ? Format.menuBarText(metric: metric, snapshot: snapshot)
                : ""
            let titleKey = "\(metric.rawValue)|\(title)"
            if titleKey != lastTitle {
                let font = NSFont.monospacedSystemFont(ofSize: 11, weight: .medium)
                button.font = font
                button.attributedTitle = NSAttributedString(
                    string: title,
                    attributes: [
                        .font: font,
                        .foregroundColor: NSColor.labelColor
                    ]
                )
                lastTitle = titleKey
            }
        }

        let tooltipText = tooltip(for: snapshot)
        if tooltipText != lastTooltip {
            button.toolTip = tooltipText
            lastTooltip = tooltipText
        }
    }

    private func installSpeedViewIfNeeded() {
        guard !isSpeedViewInstalled, let button = statusItem.button else { return }
        isSpeedViewInstalled = true

        speedContainer.translatesAutoresizingMaskIntoConstraints = false
        speedContainer.isHidden = true
        button.addSubview(speedContainer)
        NSLayoutConstraint.activate([
            speedContainer.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            speedContainer.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            speedContainer.topAnchor.constraint(equalTo: button.topAnchor),
            speedContainer.bottomAnchor.constraint(equalTo: button.bottomAnchor)
        ])

        speedRing.translatesAutoresizingMaskIntoConstraints = false
        speedRing.imageScaling = .scaleNone

        speedText.translatesAutoresizingMaskIntoConstraints = false
        speedText.font = NSFont.monospacedSystemFont(ofSize: 9, weight: .medium)
        speedText.textColor = .labelColor
        speedText.maximumNumberOfLines = 2
        speedText.cell?.wraps = true
        speedText.cell?.usesSingleLineMode = false
        speedText.cell?.lineBreakMode = .byClipping

        let stack = NSStackView(views: [speedRing, speedText])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 6
        speedContainer.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: speedContainer.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: speedContainer.centerYAnchor),
            speedRing.widthAnchor.constraint(equalToConstant: StatusRingRenderer.canvas),
            speedRing.heightAnchor.constraint(equalToConstant: StatusRingRenderer.canvas)
        ])
    }

    private func speedItemLength(for text: String) -> CGFloat {
        let font = NSFont.monospacedSystemFont(ofSize: 9, weight: .medium)
        let textWidth = (text as NSString).size(withAttributes: [.font: font]).width
        return (14 + StatusRingRenderer.canvas + 6 + textWidth).rounded(.up)
    }

    private func tooltip(for snapshot: MetricsSnapshot) -> String {
        [
            L10n.tr(
                "status.tooltip.cpu",
                Format.percent(snapshot.cpu.total),
                Format.percent(snapshot.gpu.utilization)
            ),
            L10n.tr(
                "status.tooltip.memory",
                Format.percent(snapshot.memory.usedFraction),
                Format.temperature(snapshot.thermal.cpuCelsius)
            ),
            L10n.tr(
                "status.tooltip.network",
                Format.rate(snapshot.network.downloadBytesPerSec),
                Format.rate(snapshot.network.uploadBytesPerSec)
            )
        ].joined(separator: "\n")
    }

    private var usesExpandedInterface: Bool {
        if #available(macOS 27.0, *) { return true }
        return false
    }

    @objc private func handleClick() {
        let event = NSApp.currentEvent
        let isRightClick = event?.type == .rightMouseUp
            || event?.modifierFlags.contains(.control) == true
        if isRightClick {
            DispatchQueue.main.async { [weak self] in
                self?.showMenu()
            }
            return
        }

        // On macOS 27 the primary click starts an expanded interface session
        // and AppKit no longer invokes the button action.
        guard !usesExpandedInterface else { return }
        toggleDropdown()
    }

    func showPopover() {
        guard let button = statusItem.button else { return }
        dropdown.show(relativeTo: button)
    }

    var debugPopoverWindow: NSWindow? { dropdown.window }
    var debugStatusButton: NSStatusBarButton? { statusItem.button }
    var debugPanelIsKey: Bool { dropdown.isKey }
    var debugPanelIsVisible: Bool { dropdown.isVisible }
    var debugPanelHeight: CGFloat { dropdown.contentHeight }

    func refreshLocalization() {
        statusItem.button?.setAccessibilityLabel(L10n.tr("status.accessibility"))
        refresh()
    }

    private func makeDropdown() -> DropdownPanelController {
        DropdownPanelController(
            widthProvider: { [weak self] in
                CGFloat(self?.settings.panelWidth.rawValue ?? PanelWidth.standard.rawValue)
            },
            content: { [weak self] scrolls in
                guard let self else { return AnyView(EmptyView()) }
                return AnyView(
                    PanelView(
                        store: self.store,
                        settings: self.settings,
                        device: self.device,
                        panelState: self.panelState,
                        scrolls: scrolls
                    )
                )
            }
        )
    }

    private func toggleDropdown() {
        guard let button = statusItem.button else { return }
        dropdown.toggle(relativeTo: button)
    }

    private func openSettings() {
        dropdown.close()
        onOpenSettings()
    }

    private func showMenu() {
        dropdown.close()
        let menu = NSMenu()

        let openItem = NSMenuItem(
            title: L10n.tr("status.menu.openPanel"),
            action: #selector(openPanel),
            keyEquivalent: ""
        )
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: L10n.tr("menu.settings"),
            action: #selector(openSettingsAction),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: L10n.tr("menu.quit"),
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        guard let button = statusItem.button else { return }
        // Let AppKit present the menu from the status item so it gets the
        // native anchored appearance and position. The menu is only attached
        // for the duration of this right-click.
        isPresentingMenu = true
        statusItem.menu = menu
        button.performClick(nil)
        statusItem.menu = nil
        isPresentingMenu = false
    }

    @objc private func openPanel() {
        toggleDropdown()
    }

    @objc private func openSettingsAction() {
        openSettings()
    }

    @objc private func quit() {
        onQuit()
    }
}

@available(macOS 27.0, *)
extension StatusItemController: NSStatusItemExpandedInterfaceDelegate {
    func statusItem(
        _ statusItem: NSStatusItem,
        didBegin session: NSStatusItemExpandedInterfaceSession
    ) {
        // Presenting a right-click menu goes through the status item menu and
        // must not start the panel session underneath it. The session belongs
        // to the menu, so leave it alone; cancelling it dismisses the menu.
        guard !isPresentingMenu else { return }
        // A click that just closed the panel can start a new session; cancel it
        // instead of immediately reopening.
        if let lastCloseAt = dropdown.lastCloseAt,
           Date().timeIntervalSince(lastCloseAt) < 0.2 {
            session.cancel()
            return
        }
        guard let button = statusItem.button else {
            session.cancel()
            return
        }
        dropdown.toggle(relativeTo: button)
    }

    func statusItemDidEndExpandedInterfaceSession(_ statusItem: NSStatusItem, animated: Bool) {
        dropdown.close()
    }
}

private final class PassthroughView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
