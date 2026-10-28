import AppKit
import SwiftUI

final class DropdownPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class DropdownPanelController {
    static let menuBarGap: CGFloat = 6
    static let cornerRadius: CGFloat = 16
    static let minimumHeight: CGFloat = 200

    private let panel: DropdownPanel
    private let widthProvider: () -> CGFloat
    private let contentFactory: (Bool) -> AnyView

    private var hostingView: NSHostingView<AnyView>?
    private var scrolls = false
    private var lastWidth: CGFloat = 0
    private var lastHeight: CGFloat = 0
    private(set) var lastCloseAt: Date?
    private var ignoreClicksUntil: Date?
    private var eventMonitors: [Any] = []
    private var globalMonitor: Any?
    private var observers: [NSObjectProtocol] = []
    private weak var statusButton: NSStatusBarButton?

    var onVisibilityChange: ((Bool) -> Void)?
    var closesOnStatusClick = false
    var makeKeyWhenInactive = false

    var window: NSWindow { panel }
    var isVisible: Bool { panel.isVisible }
    var isKey: Bool { panel.isKeyWindow }
    var contentHeight: CGFloat { panel.frame.height }

    init(
        widthProvider: @escaping () -> CGFloat,
        content: @escaping (Bool) -> AnyView
    ) {
        self.widthProvider = widthProvider
        contentFactory = content

        panel = DropdownPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 420),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isMovable = false
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .none
        panel.isExcludedFromWindowsMenu = true

        installMonitors()
    }

    deinit {
        removeGlobalMonitor()
        for monitor in eventMonitors {
            NSEvent.removeMonitor(monitor)
        }
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func toggle(relativeTo button: NSStatusBarButton) {
        if panel.isVisible {
            close()
            return
        }

        if let lastCloseAt, Date().timeIntervalSince(lastCloseAt) < 0.15 {
            return
        }
        show(relativeTo: button)
    }

    func show(relativeTo button: NSStatusBarButton) {
        guard !panel.isVisible else { return }
        statusButton = button
        guard let buttonWindow = button.window else { return }

        let width = max(280, widthProvider())
        let buttonFrame = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let screen = buttonWindow.screen ?? NSScreen.main
        let visible = screen?.visibleFrame ?? .zero
        let panelTop = buttonFrame.minY - Self.menuBarGap
        let maxHeight = max(Self.minimumHeight, panelTop - visible.minY - 8)

        let measured = measureNaturalHeight(width: width)
        let targetScrolls = measured > maxHeight
        let targetHeight = min(max(measured, Self.minimumHeight), maxHeight)

        if hostingView == nil
            || abs(width - lastWidth) > 0.5
            || abs(targetHeight - lastHeight) > 0.5
            || targetScrolls != scrolls {
            rebuildContent(width: width, height: targetHeight, scrolls: targetScrolls)
            lastWidth = width
            lastHeight = targetHeight
            scrolls = targetScrolls
        }

        var x = buttonFrame.midX - width / 2
        x = min(max(visible.minX + 8, x), visible.maxX - width - 8)
        let frame = NSRect(x: x, y: panelTop - targetHeight, width: width, height: targetHeight)

        panel.setFrame(frame, display: true)
        panel.invalidateShadow()
        panel.orderFrontRegardless()
        panel.displayIfNeeded()
        // The global copy of the click that opened the panel can arrive after
        // the monitor is installed.
        ignoreClicksUntil = Date().addingTimeInterval(0.2)
        installGlobalMonitor()

        if makeKeyWhenInactive || NSApp.isActive {
            panel.makeKey()
        }

        onVisibilityChange?(true)
    }

    func close() {
        removeGlobalMonitor()
        guard panel.isVisible else { return }
        panel.orderOut(nil)
        lastCloseAt = Date()

        panel.contentView = nil
        hostingView = nil
        lastWidth = 0
        lastHeight = 0
        scrolls = false

        onVisibilityChange?(false)
    }

    private func measureNaturalHeight(width: CGFloat) -> CGFloat {
        let probe = NSHostingView(
            rootView: AnyView(contentFactory(false).frame(width: width))
        )
        probe.frame = NSRect(x: 0, y: 0, width: width, height: 1)
        probe.layoutSubtreeIfNeeded()

        let height = probe.fittingSize.height
        guard height.isFinite, height >= 80 else {
            return max(Self.minimumHeight, lastHeight)
        }
        return height
    }

    private func rebuildContent(width: CGFloat, height: CGFloat, scrolls: Bool) {
        let size = NSSize(width: width, height: height)
        let root = contentFactory(scrolls)
            .frame(width: width, height: height)
        let view = NSHostingView(rootView: AnyView(root))
        view.frame = NSRect(origin: .zero, size: size)
        view.autoresizingMask = [.width, .height]

        panel.contentView = makeChrome(hosting: view, size: size)
        panel.setContentSize(size)
        hostingView = view
    }

    private func makeChrome(hosting: NSView, size: NSSize) -> NSView {
        let container = NSView(frame: NSRect(origin: .zero, size: size))
        container.autoresizingMask = [.width, .height]
        container.wantsLayer = true
        container.layer?.cornerRadius = Self.cornerRadius
        container.layer?.cornerCurve = .continuous
        container.layer?.masksToBounds = true

        let glass = NSGlassEffectView(frame: container.bounds)
        glass.autoresizingMask = [.width, .height]
        glass.style = .regular
        glass.cornerRadius = Self.cornerRadius
        glass.contentView = hosting
        container.addSubview(glass)
        return container
    }

    private func installGlobalMonitor() {
        guard globalMonitor == nil else { return }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown],
            handler: { [weak self] _ in
                self?.closeIfClickOutside()
            }
        )
    }

    private func removeGlobalMonitor() {
        guard let globalMonitor else { return }
        NSEvent.removeMonitor(globalMonitor)
        self.globalMonitor = nil
    }

    private func installMonitors() {
        if let local = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown],
            handler: { [weak self] event in
                guard let self, self.panel.isVisible else { return event }
                let point = NSEvent.mouseLocation
                if self.isStatusButtonClick(point) {
                    guard self.closesOnStatusClick else { return event }
                    self.close()
                    return nil
                }
                if !self.panel.frame.contains(point) {
                    self.close()
                }
                return event
            }
        ) {
            eventMonitors.append(local)
        }

        if let key = NSEvent.addLocalMonitorForEvents(
            matching: .keyDown,
            handler: { [weak self] event in
                guard let self, self.panel.isVisible, self.panel.isKeyWindow else {
                    return event
                }
                if event.keyCode == 53 {
                    self.close()
                    return nil
                }
                return event
            }
        ) {
            eventMonitors.append(key)
        }

        let resign = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self, self.panel.isVisible else { return }
            self.close()
        }
        observers.append(resign)
    }

    private func closeIfClickOutside() {
        guard panel.isVisible else { return }
        if let ignoreClicksUntil, Date() < ignoreClicksUntil { return }

        let point = NSEvent.mouseLocation
        let inStatus = isStatusButtonClick(point)
        let inPanel = panel.frame.contains(point)
        if inStatus {
            // With the macOS 27 expanded interface the primary click does not
            // reach the button action, so this is where a status item click is
            // observed.
            if closesOnStatusClick {
                close()
            }
            return
        }
        if inPanel { return }

        close()
    }

    private func isStatusButtonClick(_ point: NSPoint) -> Bool {
        guard let button = statusButton, let window = button.window else { return false }
        let rect = window.convertToScreen(button.convert(button.bounds, to: nil))
        return rect.insetBy(dx: -2, dy: -2).contains(point)
    }
}
