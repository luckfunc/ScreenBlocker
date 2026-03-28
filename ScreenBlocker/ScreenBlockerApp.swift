import SwiftUI

@main
struct ScreenBlockerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @ObservedObject private var settings = SettingsManager.shared

    var body: some Scene {
        MenuBarExtra(isInserted: $settings.showMenuBarIcon) {
            MenuBarView(
                windowController: appDelegate.windowController,
                windowWatcher: appDelegate.windowWatcher,
                settingsWindowController: appDelegate.settingsWindowController
            )
        } label: {
            Image(systemName: "rectangle.portrait.tophalf.inset.filled")
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let windowController = BlockerWindowController()
    lazy var windowWatcher = WindowWatcher(blockerController: windowController)
    lazy var settingsWindowController = SettingsWindowController(
        blockerController: windowController,
        watcher: windowWatcher
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        windowController.createAndShow()
        windowWatcher.start()

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.windowController.reposition()
            self?.windowWatcher.adjustAllWindows()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        SettingsManager.shared.showMenuBarIcon = true
        return true
    }
}

// MARK: - Settings Window (NSWindow-based)

final class SettingsWindowController {
    private var window: NSWindow?
    private let blockerController: BlockerWindowController
    private let watcher: WindowWatcher

    init(blockerController: BlockerWindowController, watcher: WindowWatcher) {
        self.blockerController = blockerController
        self.watcher = watcher
    }

    func showSettings() {
        if let window = window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView(
            windowController: blockerController,
            windowWatcher: watcher
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 480),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "ScreenBlocker 设置"
        window.contentView = NSHostingView(rootView: settingsView)
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.window = window
    }
}

// MARK: - Menu Bar

struct MenuBarView: View {
    @ObservedObject var windowController: BlockerWindowController
    @ObservedObject var windowWatcher: WindowWatcher
    var settingsWindowController: SettingsWindowController

    var body: some View {
        VStack {
            if !windowWatcher.hasAccessibilityPermission {
                Button("⚠ 授权辅助功能权限") {
                    windowWatcher.requestAccessibility()
                }
                Divider()
            }

            Button(windowController.isVisible ? "隐藏占位窗口" : "显示占位窗口") {
                windowController.toggle()
            }
            .keyboardShortcut("h")

            Divider()

            Button(windowWatcher.isEnabled ? "关闭自动调整窗口" : "开启自动调整窗口") {
                windowWatcher.toggle()
            }
            .keyboardShortcut("a")

            Button("立即调整所有窗口") {
                windowWatcher.adjustAllWindows()
            }
            .keyboardShortcut("j")

            Divider()

            Button("设置...") {
                settingsWindowController.showSettings()
            }
            .keyboardShortcut(",")

            Divider()

            Button("退出 ScreenBlocker") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}
