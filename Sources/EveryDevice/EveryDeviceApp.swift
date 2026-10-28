import EveryDeviceCore
import SwiftUI

@main
struct EveryDeviceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Window(L10n.tr("settings.window.title"), id: "settings-window") {
            appDelegate.settingsRootView
                .frame(width: 507, height: 373)
                .background(SettingsWindowConfigurator())
        }
        .defaultSize(width: 507, height: 373)
        .windowResizability(.contentSize)
        .commands {
            SettingsCommands()
        }
    }
}

struct SettingsCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button(L10n.tr("menu.settings")) {
                openWindow(id: "settings-window")
            }
            .keyboardShortcut(",", modifiers: .command)
        }
    }
}

private struct SettingsWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        SettingsWindowConfiguratorView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class SettingsWindowConfiguratorView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else { return }
        DispatchQueue.main.async {
            if NSApp.activationPolicy() != .regular {
                NSApp.setActivationPolicy(.regular)
            }
            NSApp.activate()
            window.titlebarSeparatorStyle = .none
            window.styleMask.remove(.resizable)
            window.contentMinSize = NSSize(width: 507, height: 373)
            window.contentMaxSize = NSSize(width: 507, height: 373)
            window.standardWindowButton(.zoomButton)?.isEnabled = false
            window.setContentSize(NSSize(width: 507, height: 373))
            window.center()
            self.lockSidebar(in: window)
        }
    }

    private func lockSidebar(in window: NSWindow) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            guard let root = window.contentView?.superview ?? window.contentView,
                  let splitView = Self.findSplitView(in: root),
                  let sidebar = splitView.subviews.first(where: {
                      String(describing: type(of: $0)).contains("ItemViewWrapper") && $0.frame.width < splitView.bounds.width
                  }) else {
                return
            }
            sidebar.isHidden = false
            let width = sidebar.frame.width
            splitView.dividerStyle = .thin
            splitView.setPosition(width, ofDividerAt: 0)
            if let splitVC = splitView.delegate as? NSSplitViewController,
               let item = splitVC.splitViewItems.first(where: { $0.behavior == .sidebar }) ?? splitVC.splitViewItems.first {
                item.isCollapsed = false
                item.canCollapse = false
                item.minimumThickness = width
                item.maximumThickness = width
            }
            for subview in splitView.subviews {
                let name = String(describing: type(of: subview))
                if name.contains("SplitDividerView") || name.contains("SplitViewShadowView") {
                    subview.isHidden = true
                }
            }
        }
    }

    private static func findSplitView(in view: NSView) -> NSSplitView? {
        if let splitView = view as? NSSplitView { return splitView }
        for subview in view.subviews {
            if let splitView = findSplitView(in: subview) { return splitView }
        }
        return nil
    }
}
