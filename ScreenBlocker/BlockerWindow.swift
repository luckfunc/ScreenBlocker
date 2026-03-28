import AppKit

private let blockerWindowLevel = NSWindow.Level(rawValue: NSWindow.Level.normal.rawValue - 1)

enum BlockerFeedbackStyle {
    case constrained
    case failed

    var symbolName: String {
        switch self {
        case .constrained:
            return "arrow.down.forward.and.arrow.up.backward"
        case .failed:
            return "hand.raised.slash"
        }
    }

    var message: String {
        switch self {
        case .constrained:
            return "已限制到下半区"
        case .failed:
            return "这个窗口无法自动调整"
        }
    }
}

private struct BlockerPalette {
    let backgroundTop: NSColor
    let backgroundBottom: NSColor
    let celestial: NSColor
    let celestialGlow: NSColor
    let cloud: NSColor
    let ridgeFar: NSColor
    let ridgeMid: NSColor
    let ridgeFront: NSColor
    let divider: NSColor

    static let dark = BlockerPalette(
        backgroundTop: NSColor(calibratedRed: 0.08, green: 0.10, blue: 0.15, alpha: 1),
        backgroundBottom: NSColor(calibratedRed: 0.03, green: 0.04, blue: 0.06, alpha: 1),
        celestial: NSColor(calibratedRed: 0.95, green: 0.75, blue: 0.48, alpha: 1),
        celestialGlow: NSColor(calibratedRed: 0.96, green: 0.70, blue: 0.41, alpha: 0.22),
        cloud: NSColor(calibratedRed: 0.79, green: 0.84, blue: 0.89, alpha: 0.14),
        ridgeFar: NSColor(calibratedRed: 0.18, green: 0.22, blue: 0.29, alpha: 1),
        ridgeMid: NSColor(calibratedRed: 0.12, green: 0.16, blue: 0.22, alpha: 1),
        ridgeFront: NSColor(calibratedRed: 0.07, green: 0.10, blue: 0.15, alpha: 1),
        divider: NSColor(calibratedWhite: 1, alpha: 0.08)
    )

    static let light = BlockerPalette(
        backgroundTop: NSColor(calibratedRed: 0.98, green: 0.97, blue: 0.94, alpha: 1),
        backgroundBottom: NSColor(calibratedRed: 0.93, green: 0.95, blue: 0.96, alpha: 1),
        celestial: NSColor(calibratedRed: 0.95, green: 0.70, blue: 0.36, alpha: 1),
        celestialGlow: NSColor(calibratedRed: 0.97, green: 0.76, blue: 0.47, alpha: 0.24),
        cloud: NSColor(calibratedRed: 1.00, green: 1.00, blue: 1.00, alpha: 0.42),
        ridgeFar: NSColor(calibratedRed: 0.84, green: 0.85, blue: 0.81, alpha: 1),
        ridgeMid: NSColor(calibratedRed: 0.73, green: 0.77, blue: 0.76, alpha: 1),
        ridgeFront: NSColor(calibratedRed: 0.58, green: 0.63, blue: 0.65, alpha: 1),
        divider: NSColor(calibratedWhite: 0, alpha: 0.08)
    )
}

final class BlockerFeedbackView: NSView {
    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let backgroundLayer = CAShapeLayer()
    private let borderLayer = CAShapeLayer()

    private var style: BlockerFeedbackStyle = .constrained

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true

        layer?.addSublayer(backgroundLayer)
        layer?.addSublayer(borderLayer)
        layer?.shadowOpacity = 0.18
        layer?.shadowRadius = 14
        layer?.shadowOffset = CGSize(width: 0, height: 6)

        iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        iconView.imageScaling = .scaleProportionallyDown
        addSubview(iconView)

        titleLabel.font = .systemFont(ofSize: 12, weight: .medium)
        titleLabel.alignment = .center
        titleLabel.lineBreakMode = .byTruncatingTail
        addSubview(titleLabel)

        alphaValue = 0
        isHidden = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool {
        true
    }

    override var intrinsicContentSize: NSSize {
        let labelSize = titleLabel.fittingSize
        return NSSize(width: labelSize.width + 42, height: 30)
    }

    override func layout() {
        super.layout()

        let capsulePath = CGPath(
            roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5),
            cornerWidth: bounds.height / 2,
            cornerHeight: bounds.height / 2,
            transform: nil
        )
        backgroundLayer.frame = bounds
        backgroundLayer.path = capsulePath
        borderLayer.frame = bounds
        borderLayer.path = capsulePath

        let iconSize: CGFloat = 14
        iconView.frame = NSRect(x: 12, y: (bounds.height - iconSize) / 2, width: iconSize, height: iconSize)
        let labelX = iconView.frame.maxX + 8
        titleLabel.frame = NSRect(
            x: labelX,
            y: (bounds.height - 16) / 2,
            width: max(0, bounds.width - labelX - 14),
            height: 16
        )
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateAppearance()
    }

    func configure(style: BlockerFeedbackStyle) {
        self.style = style
        titleLabel.stringValue = style.message
        iconView.image = NSImage(systemSymbolName: style.symbolName, accessibilityDescription: style.message)
        invalidateIntrinsicContentSize()
        needsLayout = true
        updateAppearance()
    }

    private func updateAppearance() {
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        layer?.shadowColor = (isDark
            ? NSColor(calibratedWhite: 0.0, alpha: 0.55)
            : NSColor(calibratedWhite: 0.0, alpha: 0.22)
        ).cgColor

        switch style {
        case .constrained:
            titleLabel.textColor = NSColor(calibratedWhite: 1.0, alpha: isDark ? 0.92 : 0.96)
            iconView.contentTintColor = titleLabel.textColor
            backgroundLayer.fillColor = (isDark
                ? NSColor(calibratedWhite: 1.0, alpha: 0.10)
                : NSColor(calibratedRed: 0.25, green: 0.30, blue: 0.34, alpha: 0.84)
            ).cgColor
            borderLayer.strokeColor = (isDark
                ? NSColor(calibratedWhite: 1.0, alpha: 0.16)
                : NSColor(calibratedRed: 0.19, green: 0.24, blue: 0.28, alpha: 0.94)
            ).cgColor
        case .failed:
            titleLabel.textColor = isDark
                ? NSColor(calibratedRed: 0.99, green: 0.81, blue: 0.68, alpha: 0.96)
                : NSColor(calibratedWhite: 1.0, alpha: 0.96)
            iconView.contentTintColor = titleLabel.textColor
            backgroundLayer.fillColor = (isDark
                ? NSColor(calibratedRed: 0.63, green: 0.39, blue: 0.16, alpha: 0.18)
                : NSColor(calibratedRed: 0.73, green: 0.43, blue: 0.16, alpha: 0.88)
            ).cgColor
            borderLayer.strokeColor = (isDark
                ? NSColor(calibratedRed: 0.92, green: 0.63, blue: 0.38, alpha: 0.32)
                : NSColor(calibratedRed: 0.56, green: 0.30, blue: 0.09, alpha: 0.94)
            ).cgColor
        }
    }
}

final class BlockerContentView: NSView {
    private let backgroundLayer = CAGradientLayer()
    private let glowLayer = CAShapeLayer()
    private let celestialLayer = CAShapeLayer()
    private let cloudLayers = (0..<3).map { _ in CAShapeLayer() }
    private let ridgeLayers = (0..<3).map { _ in CAShapeLayer() }
    private let dividerLayer = CAShapeLayer()
    private let feedbackView = BlockerFeedbackView(frame: .zero)

    private var palette = BlockerPalette.dark
    private var sceneSize = CGSize.zero
    private var hideFeedbackWorkItem: DispatchWorkItem?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        configureSceneLayers()
        addSubview(feedbackView)

        updateAppearance()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        layoutScene()
        layoutFeedbackView()
        if sceneSize != bounds.size {
            sceneSize = bounds.size
            restartAnimations()
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateAppearance()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateAppearance()
        restartAnimations()
    }

    private func updateAppearance() {
        palette = paletteForCurrentAppearance()
        layer?.backgroundColor = palette.backgroundBottom.cgColor
        backgroundLayer.colors = [palette.backgroundTop.cgColor, palette.backgroundBottom.cgColor]
        glowLayer.fillColor = palette.celestialGlow.cgColor
        celestialLayer.fillColor = palette.celestial.cgColor
        cloudLayers.forEach { $0.fillColor = palette.cloud.cgColor }
        ridgeLayers[0].fillColor = palette.ridgeFar.cgColor
        ridgeLayers[1].fillColor = palette.ridgeMid.cgColor
        ridgeLayers[2].fillColor = palette.ridgeFront.cgColor
        dividerLayer.strokeColor = palette.divider.cgColor
        window?.backgroundColor = palette.backgroundBottom
    }

    private func configureSceneLayers() {
        guard let rootLayer = layer else { return }

        rootLayer.masksToBounds = true
        backgroundLayer.startPoint = CGPoint(x: 0.5, y: 1)
        backgroundLayer.endPoint = CGPoint(x: 0.5, y: 0)
        rootLayer.addSublayer(backgroundLayer)

        [glowLayer, celestialLayer].forEach(rootLayer.addSublayer)
        cloudLayers.forEach(rootLayer.addSublayer)
        ridgeLayers.forEach(rootLayer.addSublayer)
        rootLayer.addSublayer(dividerLayer)

        dividerLayer.lineWidth = 1
        dividerLayer.fillColor = nil
    }

    private func layoutScene() {
        guard !bounds.isEmpty else { return }

        backgroundLayer.frame = bounds
        celestialLayer.frame = bounds
        glowLayer.frame = bounds
        cloudLayers.forEach { $0.frame = bounds }
        ridgeLayers.forEach { $0.frame = bounds }
        dividerLayer.frame = bounds

        let sceneInset = max(20, bounds.width * 0.035)
        let celestialDiameter = min(bounds.height * 0.18, 32)
        let celestialRect = CGRect(
            x: bounds.maxX - sceneInset - celestialDiameter,
            y: bounds.maxY - sceneInset - celestialDiameter,
            width: celestialDiameter,
            height: celestialDiameter
        )
        let glowInset = celestialDiameter * 0.95
        let glowRect = celestialRect.insetBy(dx: -glowInset, dy: -glowInset)
        glowLayer.path = CGPath(ellipseIn: glowRect, transform: nil)
        celestialLayer.path = CGPath(ellipseIn: celestialRect, transform: nil)

        let cloudRects = [
            CGRect(x: bounds.width * 0.10, y: bounds.height * 0.64, width: bounds.width * 0.18, height: bounds.height * 0.12),
            CGRect(x: bounds.width * 0.36, y: bounds.height * 0.72, width: bounds.width * 0.14, height: bounds.height * 0.10),
            CGRect(x: bounds.width * 0.62, y: bounds.height * 0.60, width: bounds.width * 0.20, height: bounds.height * 0.13)
        ]
        for (cloudLayer, rect) in zip(cloudLayers, cloudRects) {
            cloudLayer.path = cloudPath(in: rect)
        }

        let farBaseY = bounds.height * 0.34
        let midBaseY = bounds.height * 0.23
        let frontBaseY = bounds.height * 0.13

        ridgeLayers[0].path = ridgePath(
            baseY: farBaseY,
            points: [
                CGPoint(x: 0.00, y: farBaseY + bounds.height * 0.07),
                CGPoint(x: 0.18, y: farBaseY + bounds.height * 0.18),
                CGPoint(x: 0.37, y: farBaseY + bounds.height * 0.10),
                CGPoint(x: 0.58, y: farBaseY + bounds.height * 0.20),
                CGPoint(x: 0.78, y: farBaseY + bounds.height * 0.12),
                CGPoint(x: 1.00, y: farBaseY + bounds.height * 0.16)
            ]
        )
        ridgeLayers[1].path = ridgePath(
            baseY: midBaseY,
            points: [
                CGPoint(x: 0.00, y: midBaseY + bounds.height * 0.05),
                CGPoint(x: 0.16, y: midBaseY + bounds.height * 0.13),
                CGPoint(x: 0.31, y: midBaseY + bounds.height * 0.08),
                CGPoint(x: 0.49, y: midBaseY + bounds.height * 0.16),
                CGPoint(x: 0.67, y: midBaseY + bounds.height * 0.09),
                CGPoint(x: 0.84, y: midBaseY + bounds.height * 0.14),
                CGPoint(x: 1.00, y: midBaseY + bounds.height * 0.07)
            ]
        )
        ridgeLayers[2].path = ridgePath(
            baseY: frontBaseY,
            points: [
                CGPoint(x: 0.00, y: frontBaseY + bounds.height * 0.04),
                CGPoint(x: 0.14, y: frontBaseY + bounds.height * 0.09),
                CGPoint(x: 0.28, y: frontBaseY + bounds.height * 0.06),
                CGPoint(x: 0.46, y: frontBaseY + bounds.height * 0.12),
                CGPoint(x: 0.61, y: frontBaseY + bounds.height * 0.07),
                CGPoint(x: 0.80, y: frontBaseY + bounds.height * 0.11),
                CGPoint(x: 1.00, y: frontBaseY + bounds.height * 0.05)
            ]
        )

        let dividerPath = CGMutablePath()
        dividerPath.move(to: CGPoint(x: 0, y: 0.5))
        dividerPath.addLine(to: CGPoint(x: bounds.width, y: 0.5))
        dividerLayer.path = dividerPath
    }

    func showFeedback(_ style: BlockerFeedbackStyle) {
        hideFeedbackWorkItem?.cancel()

        feedbackView.configure(style: style)
        layoutFeedbackView()
        feedbackView.isHidden = false
        feedbackView.alphaValue = 0

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            feedbackView.animator().alphaValue = 1
        }

        let hideWorkItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.2
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                self.feedbackView.animator().alphaValue = 0
            }, completionHandler: {
                self.feedbackView.isHidden = true
            })
        }

        hideFeedbackWorkItem = hideWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6, execute: hideWorkItem)
    }

    private func restartAnimations() {
        guard !bounds.isEmpty else { return }

        [glowLayer, celestialLayer, dividerLayer].forEach { $0.removeAllAnimations() }
        cloudLayers.forEach { $0.removeAllAnimations() }
        ridgeLayers.forEach { $0.removeAllAnimations() }

        let celestialFloat = CABasicAnimation(keyPath: "transform.translation.y")
        celestialFloat.fromValue = -3
        celestialFloat.toValue = 6
        celestialFloat.duration = 18
        celestialFloat.autoreverses = true
        celestialFloat.repeatCount = .infinity
        celestialFloat.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        celestialLayer.add(celestialFloat, forKey: "celestialFloat")
        glowLayer.add(celestialFloat, forKey: "glowFloat")

        let glowBreath = CABasicAnimation(keyPath: "opacity")
        glowBreath.fromValue = 0.35
        glowBreath.toValue = 0.55
        glowBreath.duration = 9
        glowBreath.autoreverses = true
        glowBreath.repeatCount = .infinity
        glowBreath.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        glowLayer.add(glowBreath, forKey: "glowBreath")

        for (index, cloudLayer) in cloudLayers.enumerated() {
            let drift = CABasicAnimation(keyPath: "transform.translation.x")
            drift.fromValue = -14 - CGFloat(index * 6)
            drift.toValue = 18 + CGFloat(index * 8)
            drift.duration = 24 + CFTimeInterval(index * 7)
            drift.autoreverses = true
            drift.repeatCount = .infinity
            drift.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            cloudLayer.add(drift, forKey: "cloudDrift")

            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 0.60
            fade.toValue = 0.88
            fade.duration = 10 + CFTimeInterval(index * 3)
            fade.autoreverses = true
            fade.repeatCount = .infinity
            fade.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            cloudLayer.add(fade, forKey: "cloudFade")
        }

        for (index, ridgeLayer) in ridgeLayers.enumerated() {
            let drift = CABasicAnimation(keyPath: "transform.translation.x")
            drift.fromValue = -10 + CGFloat(index * 4)
            drift.toValue = 10 - CGFloat(index * 3)
            drift.duration = 36 + CFTimeInterval(index * 10)
            drift.autoreverses = true
            drift.repeatCount = .infinity
            drift.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            ridgeLayer.add(drift, forKey: "ridgeDrift")
        }
    }

    private func paletteForCurrentAppearance() -> BlockerPalette {
        let bestMatch = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua])
        if bestMatch == .darkAqua {
            return .dark
        }
        return .light
    }

    private func ridgePath(baseY: CGFloat, points: [CGPoint]) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 0, y: baseY))
        for point in points {
            path.addLine(to: CGPoint(x: bounds.width * point.x, y: point.y))
        }
        path.addLine(to: CGPoint(x: bounds.width, y: 0))
        path.closeSubpath()
        return path
    }

    private func cloudPath(in rect: CGRect) -> CGPath {
        let path = CGMutablePath()
        let baseRect = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height * 0.55)
        path.addRoundedRect(in: baseRect, cornerWidth: baseRect.height / 2, cornerHeight: baseRect.height / 2)
        path.addEllipse(in: CGRect(
            x: rect.minX + rect.width * 0.08,
            y: rect.minY + rect.height * 0.22,
            width: rect.width * 0.28,
            height: rect.height * 0.52
        ))
        path.addEllipse(in: CGRect(
            x: rect.minX + rect.width * 0.30,
            y: rect.minY + rect.height * 0.34,
            width: rect.width * 0.34,
            height: rect.height * 0.58
        ))
        path.addEllipse(in: CGRect(
            x: rect.minX + rect.width * 0.55,
            y: rect.minY + rect.height * 0.18,
            width: rect.width * 0.24,
            height: rect.height * 0.48
        ))
        return path
    }

    private func layoutFeedbackView() {
        let fittingSize = feedbackView.fittingSize
        let width = min(bounds.width - 28, max(164, fittingSize.width))
        feedbackView.frame = NSRect(
            x: (bounds.width - width) / 2,
            y: max(10, bounds.height * 0.08),
            width: width,
            height: 30
        )
    }
}

final class BlockerWindowController: ObservableObject {
    private var window: NSWindow?
    private weak var blockerContentView: BlockerContentView?
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

        window.level = blockerWindowLevel
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        window.isOpaque = true
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.isMovable = false
        window.hidesOnDeactivate = false
        window.canHide = false
        window.backgroundColor = .windowBackgroundColor
        let blockerContentView = makeBlockerView()
        window.contentView = blockerContentView

        window.orderFrontRegardless()
        self.window = window
        self.blockerContentView = blockerContentView
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

    func showAdjustmentFeedback(_ style: BlockerFeedbackStyle) {
        blockerContentView?.showFeedback(style)
    }

    private func makeBlockerView() -> BlockerContentView {
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
