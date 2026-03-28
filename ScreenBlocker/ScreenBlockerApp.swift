import SwiftUI

@main
struct ScreenBlockerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @ObservedObject private var settings = SettingsManager.shared

    var body: some Scene {
        MenuBarExtra(isInserted: $settings.showMenuBarIcon) {
            MenuBarView(
                coordinator: appDelegate.coordinator,
                settingsWindowController: appDelegate.settingsWindowController
            )
        } label: {
            Image(systemName: "rectangle.portrait.tophalf.inset.filled")
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let coordinator = ScreenBlockerCoordinator()
    lazy var settingsWindowController = SettingsWindowController(coordinator: coordinator)

    func applicationDidFinishLaunching(_ notification: Notification) {
        coordinator.start()

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.coordinator.handleScreenParametersChanged()
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
    private let coordinator: ScreenBlockerCoordinator

    init(coordinator: ScreenBlockerCoordinator) {
        self.coordinator = coordinator
    }

    func showSettings() {
        if let window = window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView(coordinator: coordinator)

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
    @ObservedObject var coordinator: ScreenBlockerCoordinator
    var settingsWindowController: SettingsWindowController

    var body: some View {
        VStack {
            if !coordinator.hasAccessibilityPermission {
                Button("⚠ 授权辅助功能权限") {
                    coordinator.requestAccessibility()
                }
                Divider()
            }

            Button(coordinator.isOverlayVisible ? "隐藏占位窗口" : "显示占位窗口") {
                coordinator.toggleOverlay()
            }
            .keyboardShortcut("h")

            Divider()

            Button(coordinator.isWindowAdjustmentEnabled ? "关闭自动调整窗口" : "开启自动调整窗口") {
                coordinator.toggleWindowAdjustment()
            }
            .keyboardShortcut("a")

            Button("立即调整所有窗口") {
                coordinator.adjustAllWindows()
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
