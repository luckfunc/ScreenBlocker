import AppKit

final class BlockerContentView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class BlockerWindowController: ObservableObject {
    private var window: NSWindow?
    @Published private(set) var isVisible = true

    var portraitScreen: NSScreen? {
        NSScreen.screens.first { $0.frame.height > $0.frame.width }
    }

    var targetGeometry: ScreenGeometry? {
        guard let screen = portraitScreen else { return nil }
        return ScreenGeometry(screen: screen)
    }

    func createAndShow(blockRatio: Double) {
        guard let geometry = targetGeometry else {
            print("No portrait screen found")
            isVisible = false
            return
        }

        let window = NSWindow(
            contentRect: geometry.blockedRect(for: blockRatio),
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
        window.contentView = BlockerContentView(frame: geometry.blockedRect(for: blockRatio))

        window.orderFront(nil)
        self.window = window
        self.isVisible = true
    }

    func toggle(blockRatio: Double) {
        guard let window = window else {
            createAndShow(blockRatio: blockRatio)
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

    func reposition(blockRatio: Double) {
        guard let window = window, let geometry = targetGeometry else { return }
        window.setFrame(geometry.blockedRect(for: blockRatio), display: false)
    }
}
