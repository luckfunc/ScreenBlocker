import AppKit
import Combine
import SwiftUI

@main
struct ScreenBlockerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
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
    lazy var statusBarController = StatusBarController(
        windowController: windowController,
        windowWatcher: windowWatcher,
        settingsWindowController: settingsWindowController
    )

    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        windowController.createAndShow()
        windowWatcher.start()
        statusBarController.setVisible(SettingsManager.shared.showMenuBarIcon)

        SettingsManager.shared.$showMenuBarIcon
            .removeDuplicates()
            .sink { [weak self] isVisible in
                self?.statusBarController.setVisible(isVisible)
            }
            .store(in: &cancellables)

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.windowController.reposition()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        SettingsManager.shared.showMenuBarIcon = true
        return true
    }
}

final class StatusBarController: NSObject, NSMenuDelegate {
    private let windowController: BlockerWindowController
    private let windowWatcher: WindowWatcher
    private let settingsWindowController: SettingsWindowController

    private var statusItem: NSStatusItem?
    private lazy var menu: NSMenu = {
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        menu.items = [
            accessibilityItem,
            .separator(),
            toggleOverlayItem,
            .separator(),
            toggleWatcherItem,
            adjustWindowsItem,
            .separator(),
            settingsItem,
            .separator(),
            quitItem
        ]
        return menu
    }()

    private lazy var accessibilityItem = makeMenuItem(
        title: "⚠ 授权辅助功能权限",
        action: #selector(requestAccessibility),
        keyEquivalent: ""
    )

    private lazy var toggleOverlayItem = makeMenuItem(
        title: "",
        action: #selector(toggleOverlay),
        keyEquivalent: "h"
    )

    private lazy var toggleWatcherItem = makeMenuItem(
        title: "",
        action: #selector(toggleWindowAdjustment),
        keyEquivalent: "a"
    )

    private lazy var adjustWindowsItem = makeMenuItem(
        title: "立即调整所有窗口",
        action: #selector(adjustAllWindows),
        keyEquivalent: "j"
    )

    private lazy var settingsItem = makeMenuItem(
        title: "设置...",
        action: #selector(showSettings),
        keyEquivalent: ","
    )

    private lazy var quitItem = makeMenuItem(
        title: "退出 ScreenBlocker",
        action: #selector(quit),
        keyEquivalent: "q"
    )

    init(
        windowController: BlockerWindowController,
        windowWatcher: WindowWatcher,
        settingsWindowController: SettingsWindowController
    ) {
        self.windowController = windowController
        self.windowWatcher = windowWatcher
        self.settingsWindowController = settingsWindowController
        super.init()
    }

    func setVisible(_ isVisible: Bool) {
        if isVisible {
            installStatusItemIfNeeded()
        } else {
            removeStatusItem()
        }
    }

    func menuWillOpen(_ menu: NSMenu) {
        updateMenuItems()
    }

    private func installStatusItemIfNeeded() {
        guard statusItem == nil else {
            updateMenuItems()
            return
        }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "rectangle.portrait.tophalf.inset.filled", accessibilityDescription: "ScreenBlocker")
        item.button?.toolTip = "ScreenBlocker"
        item.menu = menu

        statusItem = item
        updateMenuItems()
    }

    private func removeStatusItem() {
        guard let statusItem else { return }
        NSStatusBar.system.removeStatusItem(statusItem)
        self.statusItem = nil
    }

    private func updateMenuItems() {
        accessibilityItem.isHidden = windowWatcher.hasAccessibilityPermission
        toggleOverlayItem.title = windowController.isVisible ? "隐藏占位窗口" : "显示占位窗口"
        toggleWatcherItem.title = windowWatcher.isEnabled ? "关闭自动调整窗口" : "开启自动调整窗口"
        adjustWindowsItem.isEnabled = windowWatcher.hasAccessibilityPermission
    }

    private func makeMenuItem(title: String, action: Selector, keyEquivalent: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        return item
    }

    @objc
    private func requestAccessibility() {
        windowWatcher.requestAccessibility()
        updateMenuItems()
    }

    @objc
    private func toggleOverlay() {
        windowController.toggle()
        updateMenuItems()
    }

    @objc
    private func toggleWindowAdjustment() {
        windowWatcher.toggle()
        updateMenuItems()
    }

    @objc
    private func adjustAllWindows() {
        windowWatcher.adjustAllWindows()
    }

    @objc
    private func showSettings() {
        DispatchQueue.main.async { [settingsWindowController] in
            settingsWindowController.showSettings()
        }
    }

    @objc
    private func quit() {
        NSApplication.shared.terminate(nil)
    }
}

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
