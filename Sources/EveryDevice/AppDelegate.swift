import AppKit
import Combine
import EveryDeviceCore
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = AppSettings()
    private let device = DeviceInfoStore()
    private lazy var store = MetricsStore()
    private let engine = MetricsEngine()
    private let recorder = MetricsRecorder()
    private let power = PowerController()
    private let alertSettings = AlertSettings()
    private let alertEvaluator = AlertEvaluator()
    private let notifications = NotificationCoordinator()

    private var statusController: StatusItemController?
    private var observers: [NSObjectProtocol] = []
    private var cancellables: Set<AnyCancellable> = []
    private var lockDescriptor: Int32 = -1
    private var panelVisible = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard Bundle.main.bundleIdentifier != nil else {
            showBundledOnlyAlert()
            NSApp.terminate(nil)
            return
        }

        switch acquireSingleInstanceLock() {
        case .acquired:
            break
        case .alreadyRunning:
            if isCaptureRun {
                break
            }
            activateExistingInstance()
            NSApp.terminate(nil)
            return
        case .failed:
            showLockFailureAlert()
            NSApp.terminate(nil)
            return
        }

        LoginItemManager.cleanupLegacyFallback()
        observeWindowClose()
        NSApp.appearance = settings.appAppearance.nsAppearance

        statusController = StatusItemController(
            store: store,
            settings: settings,
            device: device,
            onOpenSettings: { [weak self] in self?.showSettings() },
            onQuit: { NSApp.terminate(nil) },
            onPanelVisibilityChange: { [weak self] visible in
                self?.panelVisible = visible
                self?.updateSamplingDemand()
            }
        )

        engine.onUpdate = { [weak self] update in
            guard let self else { return }
            self.store.apply(update)
            guard !update.isWarmup else { return }
            self.recorder.record(update.snapshot)

            let events = self.alertEvaluator.evaluate(
                snapshot: update.snapshot,
                fresh: update.fresh,
                rules: self.alertSettings.rules,
                now: update.snapshot.timestamp
            )
            for event in events {
                self.notifications.send(event)
            }
        }
        updateSamplingDemand()
        if settings.recordsHistoryToDisk {
            recorder.start(retentionHours: settings.historyRetentionHours)
        }
        engine.start(interval: settings.effectiveInterval)

        settings.$refreshInterval
            .dropFirst()
            .sink { [weak self] _ in
                guard let self else { return }
                self.engine.setInterval(self.settings.effectiveInterval)
            }
            .store(in: &cancellables)

        settings.$historyRetentionHours
            .dropFirst()
            .sink { [weak self] hours in
                self?.recorder.setRetention(hours: hours)
            }
            .store(in: &cancellables)

        settings.$recordsHistoryToDisk
            .dropFirst()
            .sink { [weak self] enabled in
                guard let self else { return }
                if enabled {
                    self.recorder.start(retentionHours: self.settings.historyRetentionHours)
                } else {
                    self.recorder.stop()
                }
            }
            .store(in: &cancellables)

        settings.$showsProcesses
            .dropFirst()
            .sink { [weak self] _ in self?.updateSamplingDemand() }
            .store(in: &cancellables)

        settings.$preventsSleep
            .dropFirst()
            .sink { [weak self] enabled in
                self?.power.set(enabled)
            }
            .store(in: &cancellables)

        settings.$appLanguage
            .dropFirst()
            .sink { [weak self] _ in
                guard let self else { return }
                self.statusController?.refreshLocalization()
            }
            .store(in: &cancellables)

        settings.$appAppearance
            .dropFirst()
            .sink { appearance in
                NSApp.appearance = appearance.nsAppearance
            }
            .store(in: &cancellables)

        alertSettings.$rules
            .dropFirst()
            .sink { [weak self] rules in
                guard let self else { return }
                self.alertEvaluator.reset()
                if rules.contains(where: { $0.enabled }) {
                    self.notifications.requestPermissionIfNeeded()
                }
            }
            .store(in: &cancellables)

        power.set(settings.preventsSleep)

        observeSleepWake()
        observeLowPowerMode()

        #if DEBUG
        if CommandLine.arguments.contains("--capture-popover") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                self?.capturePopoverSnapshot()
            }
        }

        if CommandLine.arguments.contains("--show-panel") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.statusController?.showPopover()

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    print("panel visible: \(self?.statusController?.debugPanelIsVisible == true)")
                    print("panel key: \(self?.statusController?.debugPanelIsKey == true)")
                    print("panel height: \(self?.statusController?.debugPanelHeight ?? 0)")
                    print("panel window number: \(self?.statusController?.debugPopoverWindow?.windowNumber ?? 0)")
                    print("app active: \(NSApp.isActive)")
                    fflush(stdout)
                }
            }
        }

        if CommandLine.arguments.contains("--capture-settings") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.showSettings()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) { [weak self] in
                self?.captureSettingsWindow()
            }
        }
        #endif
    }

    #if DEBUG
    private func captureSettingsWindow() {
        defer { NSApp.terminate(nil) }
        let window = NSApp.keyWindow ?? NSApp.windows.first { $0.isVisible && $0.level == .normal }
        if let window, let root = window.contentView?.superview ?? window.contentView {
            func collect(_ view: NSView, _ out: inout [NSScrollView]) {
                if let scroll = view as? NSScrollView { out.append(scroll) }
                for subview in view.subviews { collect(subview, &out) }
            }
            var scrolls: [NSScrollView] = []
            collect(root, &scrolls)
            if let detail = scrolls.max(by: { $0.frame.width < $1.frame.width }) {
                let maxY = max(0, (detail.documentView?.frame.height ?? 0) - detail.contentView.bounds.height)
                detail.contentView.scroll(to: NSPoint(x: 0, y: maxY * 0.55))
                detail.reflectScrolledClipView(detail.contentView)
            }
        }
        writeWindowSnapshot(window, name: "settings-window.png")
    }

    private func writeWindowSnapshot(_ window: NSWindow?, name: String) {
        guard let window,
              let frameView = window.contentView?.superview ?? window.contentView else {
            print("window not found")
            return
        }

        let bounds = frameView.bounds
        guard let bitmap = frameView.bitmapImageRepForCachingDisplay(in: bounds) else { return }
        frameView.cacheDisplay(in: bounds, to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]) else { return }

        let directory = URL(fileURLWithPath: "/tmp/everydevice-snapshot", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? png.write(to: directory.appendingPathComponent(name))
        print("window captured: \(name) \(bounds) number: \(window.windowNumber)")
    }

    private func capturePopoverSnapshot() {
        if let button = statusController?.debugStatusButton {
            print("status button frame: \(button.frame)")
            print("status image: \(button.image.map { "\($0.size)" } ?? "nil")")
            print("status title: \(button.attributedTitle.string)")
            print("status window visible: \(button.window?.isVisible == true)")
        }
        statusController?.showPopover()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            defer { NSApp.terminate(nil) }

            guard let self,
                  let window = self.statusController?.debugPopoverWindow,
                  let view = window.contentView,
                  let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
                print("panel not found")
                return
            }

            print("app active: \(NSApp.isActive)")
            print("panel key: \(self.statusController?.debugPanelIsKey == true)")

            view.cacheDisplay(in: view.bounds, to: bitmap)
            guard let png = bitmap.representation(using: .png, properties: [:]) else { return }

            let directory = URL(fileURLWithPath: "/tmp/everydevice-snapshot", isDirectory: true)
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try? png.write(to: directory.appendingPathComponent("popover.png"))
            print("popover captured")
        }
    }
    #endif

    func applicationWillTerminate(_ notification: Notification) {
        engine.stop()
        recorder.stop()
        power.set(false)
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        if lockDescriptor >= 0 {
            close(lockDescriptor)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if let settings = settingsWindowIfOpen() {
            activateRegular()
            if settings.isMiniaturized {
                settings.deminiaturize(nil)
            }
            settings.makeKeyAndOrderFront(nil)
        } else {
            statusController?.showPopover()
        }
        return true
    }

    private func settingsWindowIfOpen() -> NSWindow? {
        NSApp.windows.first {
            $0.level == .normal && !($0 is NSPanel) && ($0.isVisible || $0.isMiniaturized)
        }
    }

    var settingsRootView: some View {
        SettingsView(
            settings: settings,
            power: power,
            alertSettings: alertSettings,
            notifications: notifications,
            recorder: recorder
        )
    }

    private func showSettings() {
        notifications.refreshStatus()
        activateRegular()
        // The Settings scene has no public AppKit opener; invoke SwiftUI's own Settings… command instead.
        DispatchQueue.main.async {
            guard let item = NSApp.mainMenu?.items.first?.submenu?.items.first(where: { $0.keyEquivalent == "," }),
                  let action = item.action else { return }
            NSApp.sendAction(action, to: item.target, from: item)
        }
    }

    private func activateRegular() {
        if NSApp.activationPolicy() != .regular {
            NSApp.setActivationPolicy(.regular)
        }
        NSApp.activate()
    }

    private func restoreAccessoryIfNeeded() {
        let hasAppWindow = NSApp.windows.contains { window in
            window.level != .statusBar && (window.isVisible || window.isMiniaturized)
        }
        guard !hasAppWindow else { return }
        if NSApp.activationPolicy() == .regular {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    private func observeWindowClose() {
        let observer = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                self?.restoreAccessoryIfNeeded()
            }
        }
        observers.append(observer)
    }

    private func updateSamplingDemand() {
        engine.setDemand(SamplingDemand(processes: panelVisible && settings.showsProcesses))
    }

    private func observeSleepWake() {
        let center = NSWorkspace.shared.notificationCenter

        let sleepObserver = center.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.engine.stop()
        }

        let wakeObserver = center.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.store.resetChartData()
            self.engine.resetBaselines()
            self.alertEvaluator.reset()
            self.power.set(self.settings.preventsSleep)
            self.engine.start(interval: self.settings.effectiveInterval)
        }

        observers.append(contentsOf: [sleepObserver, wakeObserver])
    }

    private func observeLowPowerMode() {
        let observer = NotificationCenter.default.addObserver(
            forName: .NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.engine.setInterval(self.settings.effectiveInterval)
        }
        observers.append(observer)
    }

    private enum InstanceLockResult {
        case acquired
        case alreadyRunning
        case failed
    }

    private func acquireSingleInstanceLock() -> InstanceLockResult {
        let directory = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("EveryDevice", isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            return .failed
        }

        let path = directory.appendingPathComponent("instance.lock").path
        let descriptor = open(path, O_CREAT | O_RDWR, 0o644)
        guard descriptor >= 0 else { return .failed }

        if flock(descriptor, LOCK_EX | LOCK_NB) == 0 {
            lockDescriptor = descriptor
            return .acquired
        }

        close(descriptor)
        return .alreadyRunning
    }

    private func activateExistingInstance() {
        if let bundleID = Bundle.main.bundleIdentifier {
            NSRunningApplication
                .runningApplications(withBundleIdentifier: bundleID)
                .first { $0.processIdentifier != getpid() }?
                .activate()
        }
    }

    private func showBundledOnlyAlert() {
        let alert = NSAlert()
        alert.messageText = L10n.tr("app.bundleOnly.title")
        alert.informativeText = L10n.tr("app.bundleOnly.message")
        alert.runModal()
    }

    private func showLockFailureAlert() {
        let alert = NSAlert()
        alert.messageText = L10n.tr("app.lockFailed.title")
        alert.informativeText = L10n.tr("app.lockFailed.message")
        alert.runModal()
    }

    private var isCaptureRun: Bool {
        #if DEBUG
        CommandLine.arguments.contains {
            $0.hasPrefix("--capture") || $0.hasPrefix("--show-panel")
        }
        #else
        false
        #endif
    }
}
