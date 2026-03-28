import AppKit
import SwiftUI

final class BlockerWindowController: ObservableObject {
    private var window: NSWindow?
    private var currentBlockRatio = SettingsManager.shared.blockRatio
    @Published var isVisible = true

    var portraitScreen: NSScreen? {
        NSScreen.screens.first { $0.frame.height > $0.frame.width }
    }

    var usableRect: NSRect? {
        guard let screen = portraitScreen else { return nil }
        let usableHeight = screen.frame.height * (1.0 - currentBlockRatio)
        return NSRect(
            x: screen.frame.origin.x,
            y: screen.frame.origin.y,
            width: screen.frame.width,
            height: usableHeight
        )
    }

    func createAndShow() {
        guard let screen = portraitScreen else {
            print("No portrait screen found")
            return
        }

        let window = NSWindow(
            contentRect: windowFrame(for: screen, ratio: currentBlockRatio),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        window.level = NSWindow.Level(Int(CGWindowLevelForKey(.desktopIconWindow)))
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        window.isOpaque = true
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.isMovable = false
        window.backgroundColor = .black
        window.contentView = NSHostingView(rootView: ContentView())

        window.orderFront(nil)
        self.window = window
        self.isVisible = true
    }

    func toggle() {
        guard let window = window else {
            createAndShow()
            return
        }

        if window.isVisible {
            window.orderOut(nil)
            isVisible = false
        } else {
            window.orderFront(nil)
            isVisible = true
        }
    }

    func previewBlockRatio(_ ratio: Double) {
        currentBlockRatio = min(max(ratio, SettingsManager.blockRatioRange.lowerBound), SettingsManager.blockRatioRange.upperBound)
        reposition()
    }

    func reposition() {
        guard let window = window, let screen = portraitScreen else { return }
        window.setFrame(windowFrame(for: screen, ratio: currentBlockRatio), display: true)
    }

    private func windowFrame(for screen: NSScreen, ratio: Double) -> NSRect {
        let blockedHeight = screen.frame.height * ratio
        return NSRect(
            x: screen.frame.origin.x,
            y: screen.frame.origin.y + screen.frame.height - blockedHeight,
            width: screen.frame.width,
            height: blockedHeight
        )
    }
}
