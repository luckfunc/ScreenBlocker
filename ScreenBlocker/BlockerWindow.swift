import AppKit

final class BlockerContentView: NSView {
    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "ScreenBlocker")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor

        iconView.image = NSImage(named: "ClaudeIcon")
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.wantsLayer = true
        addSubview(iconView)

        titleLabel.alignment = .center
        titleLabel.font = .systemFont(ofSize: 20, weight: .medium)
        titleLabel.textColor = NSColor(
            calibratedRed: 0.93,
            green: 0.60,
            blue: 0.43,
            alpha: 1
        )
        titleLabel.backgroundColor = .clear
        addSubview(titleLabel)

        startIconAnimation()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()

        let iconSize: CGFloat = min(120, bounds.width * 0.28, bounds.height * 0.42)
        let labelHeight: CGFloat = 28
        let spacing: CGFloat = 18
        let totalHeight = iconSize + spacing + labelHeight
        let contentOriginY = bounds.midY - totalHeight / 2

        iconView.frame = NSRect(
            x: bounds.midX - iconSize / 2,
            y: contentOriginY + labelHeight + spacing,
            width: iconSize,
            height: iconSize
        )

        titleLabel.frame = NSRect(
            x: 24,
            y: contentOriginY,
            width: bounds.width - 48,
            height: labelHeight
        )
    }

    private func startIconAnimation() {
        guard let layer = iconView.layer,
              layer.animation(forKey: "spin") == nil else { return }

        let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotation.fromValue = 0
        rotation.toValue = Double.pi * 2
        rotation.duration = 8
        rotation.repeatCount = .infinity
        rotation.isRemovedOnCompletion = false
        rotation.timingFunction = CAMediaTimingFunction(name: .linear)
        layer.add(rotation, forKey: "spin")
    }
}

final class BlockerWindowController: ObservableObject {
    private var window: NSWindow?
    @Published var isVisible = true

    var portraitScreen: NSScreen? {
        NSScreen.screens.first { $0.frame.height > $0.frame.width }
    }

    var usableRect: NSRect? {
        guard let screen = portraitScreen else { return nil }
        return layout(for: screen, ratio: SettingsManager.shared.blockRatio).usableRect
    }

    func createAndShow() {
        guard let screen = portraitScreen else {
            print("No portrait screen found")
            return
        }

        let windowFrame = layout(for: screen, ratio: SettingsManager.shared.blockRatio).blockerFrame

        let window = NSWindow(
            contentRect: windowFrame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        window.isOpaque = true
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.isMovable = false
        window.hidesOnDeactivate = false
        window.canHide = false
        window.backgroundColor = .black
        window.contentView = makeBlockerView()

        window.orderFrontRegardless()
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
            window.orderFrontRegardless()
            isVisible = true
        }
    }

    func reposition() {
        guard let window = window, let screen = portraitScreen else { return }
        let windowFrame = layout(for: screen, ratio: SettingsManager.shared.blockRatio).blockerFrame
        window.setFrame(windowFrame, display: true)
        if isVisible {
            window.orderFrontRegardless()
        }
    }

    private func makeBlockerView() -> NSView {
        BlockerContentView(frame: .zero)
    }

    private func layout(for screen: NSScreen, ratio: Double) -> (usableRect: NSRect, blockerFrame: NSRect) {
        let managedHeight = max(0, screen.frame.height - reservedTopInset(for: screen))
        let blockedHeight = managedHeight * CGFloat(ratio)
        let usableHeight = max(0, managedHeight - blockedHeight)
        let usableRect = NSRect(
            x: screen.frame.origin.x,
            y: screen.frame.origin.y,
            width: screen.frame.width,
            height: usableHeight
        )
        let blockerFrame = NSRect(
            x: screen.frame.origin.x,
            y: screen.frame.origin.y + usableHeight,
            width: screen.frame.width,
            height: blockedHeight
        )
        return (usableRect, blockerFrame)
    }

    private func reservedTopInset(for screen: NSScreen) -> CGFloat {
        let visibleTopInset = max(0, screen.frame.maxY - screen.visibleFrame.maxY)
        let separateSpacesInset = NSScreen.screensHaveSeparateSpaces ? NSStatusBar.system.thickness : 0
        return max(visibleTopInset, separateSpacesInset)
    }
}
