import AppKit

private let blockerWindowLevel = NSWindow.Level(rawValue: NSWindow.Level.normal.rawValue - 1)
private let feedbackWindowLevel = NSWindow.Level.floating
private let defaultBlockerSpillHeight: CGFloat = 40

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

    func colors(isDark: Bool) -> (text: NSColor, fill: NSColor, border: NSColor, accent: NSColor, jelly: NSColor) {
        switch self {
        case .constrained:
            let accent = NSColor.controlAccentColor
            return (
                text: isDark
                    ? NSColor(calibratedWhite: 1.0, alpha: 0.96)
                    : NSColor(calibratedWhite: 0.11, alpha: 0.96),
                fill: isDark
                    ? NSColor(calibratedWhite: 0.15, alpha: 0.82)
                    : NSColor(calibratedWhite: 1.0, alpha: 0.84),
                border: isDark
                    ? NSColor(calibratedWhite: 1.0, alpha: 0.10)
                    : NSColor(calibratedWhite: 0.0, alpha: 0.08),
                accent: accent.withAlphaComponent(isDark ? 0.96 : 0.92),
                jelly: accent.withAlphaComponent(isDark ? 0.13 : 0.10)
            )
        case .failed:
            let accent = NSColor.systemOrange
            return (
                text: isDark
                    ? NSColor(calibratedWhite: 1.0, alpha: 0.96)
                    : NSColor(calibratedWhite: 0.11, alpha: 0.96),
                fill: isDark
                    ? NSColor(calibratedWhite: 0.15, alpha: 0.84)
                    : NSColor(calibratedWhite: 1.0, alpha: 0.86),
                border: isDark
                    ? accent.withAlphaComponent(0.22)
                    : accent.withAlphaComponent(0.18),
                accent: accent.withAlphaComponent(isDark ? 0.96 : 0.92),
                jelly: accent.withAlphaComponent(isDark ? 0.14 : 0.11)
            )
        }
    }
}

private struct BlockerPalette {
    let mistTop: NSColor
    let mistBottom: NSColor
    let idleMembrane: NSColor
    let idleEdge: NSColor

    static let light = BlockerPalette(
        mistTop: NSColor(calibratedWhite: 1.0, alpha: 0.028),
        mistBottom: NSColor(calibratedWhite: 1.0, alpha: 0.0),
        idleMembrane: NSColor(calibratedWhite: 1.0, alpha: 0.018),
        idleEdge: NSColor(calibratedWhite: 0.0, alpha: 0.10)
    )

    static let dark = BlockerPalette(
        mistTop: NSColor(calibratedWhite: 1.0, alpha: 0.018),
        mistBottom: NSColor(calibratedWhite: 1.0, alpha: 0.0),
        idleMembrane: NSColor(calibratedWhite: 1.0, alpha: 0.012),
        idleEdge: NSColor(calibratedWhite: 1.0, alpha: 0.10)
    )

    static func current(for appearance: NSAppearance) -> BlockerPalette {
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? .dark : .light
    }
}

final class BlockerFeedbackView: NSView {
    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let fillLayer = CAShapeLayer()
    private let borderLayer = CAShapeLayer()
    private let glossLayer = CAGradientLayer()

    private var style: BlockerFeedbackStyle = .constrained

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true

        layer?.addSublayer(fillLayer)
        layer?.addSublayer(glossLayer)
        layer?.addSublayer(borderLayer)
        layer?.shadowOpacity = 0.26
        layer?.shadowRadius = 18
        layer?.shadowOffset = CGSize(width: 0, height: 10)

        iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        iconView.imageScaling = .scaleProportionallyDown
        addSubview(iconView)

        titleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        titleLabel.alignment = .center
        titleLabel.lineBreakMode = .byTruncatingTail
        addSubview(titleLabel)

        alphaValue = 0
        isHidden = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize {
        let labelSize = titleLabel.fittingSize
        return NSSize(width: labelSize.width + 52, height: 36)
    }

    func configure(style: BlockerFeedbackStyle) {
        self.style = style
        titleLabel.stringValue = style.message
        iconView.image = NSImage(systemSymbolName: style.symbolName, accessibilityDescription: style.message)
        invalidateIntrinsicContentSize()
        needsLayout = true
        updateAppearance()
    }

    override func layout() {
        super.layout()

        let capsulePath = CGPath(
            roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5),
            cornerWidth: bounds.height / 2,
            cornerHeight: bounds.height / 2,
            transform: nil
        )

        fillLayer.frame = bounds
        fillLayer.path = capsulePath

        glossLayer.frame = bounds
        let glossMask = CAShapeLayer()
        glossMask.frame = bounds
        glossMask.path = capsulePath
        glossLayer.mask = glossMask

        borderLayer.frame = bounds
        borderLayer.path = capsulePath
        borderLayer.lineWidth = 1
        borderLayer.fillColor = nil

        let iconSize: CGFloat = 14
        iconView.frame = NSRect(x: 14, y: (bounds.height - iconSize) / 2, width: iconSize, height: iconSize)
        let labelX = iconView.frame.maxX + 8
        titleLabel.frame = NSRect(
            x: labelX,
            y: (bounds.height - 16) / 2,
            width: max(0, bounds.width - labelX - 16),
            height: 16
        )
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateAppearance()
    }

    private func updateAppearance() {
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let colors = style.colors(isDark: isDark)

        titleLabel.textColor = colors.text
        iconView.contentTintColor = colors.accent
        fillLayer.fillColor = colors.fill.cgColor
        borderLayer.strokeColor = colors.border.cgColor
        glossLayer.colors = [
            NSColor(calibratedWhite: 1.0, alpha: isDark ? 0.12 : 0.20).cgColor,
            NSColor(calibratedWhite: 1.0, alpha: 0.02).cgColor
        ]
        glossLayer.startPoint = CGPoint(x: 0.5, y: 0)
        glossLayer.endPoint = CGPoint(x: 0.5, y: 1)
        layer?.shadowColor = NSColor(calibratedWhite: 0.0, alpha: isDark ? 0.42 : 0.16).cgColor
    }
}

final class BlockerContentView: NSView {
    private let mistLayer = CAGradientLayer()
    private let membraneLayer = CAShapeLayer()
    private let baseEdgeLayer = CAShapeLayer()
    private let highlightEdgeLayer = CAShapeLayer()
    private let feedbackView = BlockerFeedbackView(frame: .zero)

    private var palette = BlockerPalette.light
    private var hideFeedbackWorkItem: DispatchWorkItem?
    private var activeFeedbackStyle: BlockerFeedbackStyle?
    private var feedbackVisibleUntil = Date.distantPast

    var spillHeight: CGFloat = defaultBlockerSpillHeight {
        didSet {
            needsLayout = true
        }
    }

    var onFeedbackVisibilityChanged: ((Bool) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        configureLayers()
        addSubview(feedbackView)
        updateAppearance()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        layoutChrome()
        layoutFeedbackView()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateAppearance()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateAppearance()
    }

    func showFeedback(_ style: BlockerFeedbackStyle) {
        hideFeedbackWorkItem?.cancel()
        onFeedbackVisibilityChanged?(true)

        let now = Date()
        if !feedbackView.isHidden,
           activeFeedbackStyle == style,
           now < feedbackVisibleUntil {
            let hideWorkItem = DispatchWorkItem { [weak self] in
                self?.animateFeedbackOut()
            }
            hideFeedbackWorkItem = hideWorkItem
            feedbackVisibleUntil = now.addingTimeInterval(1.08)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.08, execute: hideWorkItem)
            return
        }

        feedbackView.configure(style: style)
        layoutFeedbackView()
        feedbackView.isHidden = false
        feedbackView.alphaValue = 1
        activeFeedbackStyle = style

        animateFeedbackIn()
        animateMembrane(style: style)

        let hideWorkItem = DispatchWorkItem { [weak self] in
            self?.animateFeedbackOut()
        }
        hideFeedbackWorkItem = hideWorkItem
        feedbackVisibleUntil = now.addingTimeInterval(1.08)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.08, execute: hideWorkItem)
    }

    private func configureLayers() {
        guard let rootLayer = layer else { return }

        rootLayer.masksToBounds = false
        rootLayer.backgroundColor = NSColor.clear.cgColor

        mistLayer.startPoint = CGPoint(x: 0.5, y: 1)
        mistLayer.endPoint = CGPoint(x: 0.5, y: 0)
        rootLayer.addSublayer(mistLayer)

        membraneLayer.fillColor = palette.idleMembrane.cgColor
        rootLayer.addSublayer(membraneLayer)

        baseEdgeLayer.fillColor = nil
        baseEdgeLayer.lineWidth = 1.25
        baseEdgeLayer.lineCap = .round
        baseEdgeLayer.opacity = 0
        rootLayer.addSublayer(baseEdgeLayer)

        highlightEdgeLayer.fillColor = nil
        highlightEdgeLayer.lineWidth = 5
        highlightEdgeLayer.lineCap = .round
        highlightEdgeLayer.opacity = 0
        rootLayer.addSublayer(highlightEdgeLayer)
    }

    private func updateAppearance() {
        palette = BlockerPalette.current(for: effectiveAppearance)
        mistLayer.colors = [palette.mistTop.cgColor, palette.mistBottom.cgColor]
        membraneLayer.fillColor = palette.idleMembrane.cgColor
        baseEdgeLayer.strokeColor = palette.idleEdge.cgColor
        window?.backgroundColor = .clear
    }

    private func layoutChrome() {
        guard !bounds.isEmpty else { return }

        let dividerY = spillHeight
        mistLayer.frame = CGRect(x: 0, y: dividerY, width: bounds.width, height: max(0, bounds.height - dividerY))
        membraneLayer.frame = bounds
        baseEdgeLayer.frame = bounds
        highlightEdgeLayer.frame = bounds

        membraneLayer.path = membranePath(depth: 1.5)
        baseEdgeLayer.path = edgePath(depth: 0)
        highlightEdgeLayer.path = edgePath(depth: 0)
    }

    private func layoutFeedbackView() {
        let fittingSize = feedbackView.fittingSize
        let width = min(bounds.width - 36, max(176, fittingSize.width))
        let height: CGFloat = 36
        let idealY = spillHeight - (height * 0.5)
        let y = max(6, min(max(6, bounds.height - height - 10), idealY))

        feedbackView.frame = NSRect(
            x: (bounds.width - width) / 2,
            y: y,
            width: width,
            height: height
        )
    }

    private func membranePath(depth: CGFloat) -> CGPath {
        let dividerY = spillHeight
        let dipY = max(0, dividerY - depth)
        let path = CGMutablePath()

        path.move(to: CGPoint(x: 0, y: bounds.height))
        path.addLine(to: CGPoint(x: bounds.width, y: bounds.height))
        path.addLine(to: CGPoint(x: bounds.width, y: dividerY))
        path.addCurve(
            to: CGPoint(x: 0, y: dividerY),
            control1: CGPoint(x: bounds.width * 0.76, y: dipY),
            control2: CGPoint(x: bounds.width * 0.24, y: dipY)
        )
        path.closeSubpath()
        return path
    }

    private func edgePath(depth: CGFloat) -> CGPath {
        let dividerY = spillHeight
        let dipY = max(0, dividerY - depth)
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 12, y: dividerY))
        path.addCurve(
            to: CGPoint(x: bounds.width - 12, y: dividerY),
            control1: CGPoint(x: bounds.width * 0.28, y: dipY),
            control2: CGPoint(x: bounds.width * 0.72, y: dipY)
        )
        return path
    }

    private func animateFeedbackIn() {
        guard let layer = feedbackView.layer else { return }

        layer.removeAllAnimations()

        let transformAnimation = CAKeyframeAnimation(keyPath: "transform")
        transformAnimation.values = [
            NSValue(caTransform3D: CATransform3DConcat(
                CATransform3DMakeScale(0.76, 0.80, 1),
                CATransform3DMakeTranslation(0, 14, 0)
            )),
            NSValue(caTransform3D: CATransform3DConcat(
                CATransform3DMakeScale(1.08, 0.92, 1),
                CATransform3DMakeTranslation(0, -2, 0)
            )),
            NSValue(caTransform3D: CATransform3DMakeScale(0.97, 1.04, 1)),
            NSValue(caTransform3D: CATransform3DIdentity)
        ]
        transformAnimation.keyTimes = [0, 0.50, 0.78, 1]
        transformAnimation.duration = 0.42
        transformAnimation.timingFunctions = [
            CAMediaTimingFunction(name: .easeOut),
            CAMediaTimingFunction(name: .easeInEaseOut),
            CAMediaTimingFunction(name: .easeOut)
        ]

        let opacityAnimation = CABasicAnimation(keyPath: "opacity")
        opacityAnimation.fromValue = 0
        opacityAnimation.toValue = 1
        opacityAnimation.duration = 0.18

        let group = CAAnimationGroup()
        group.animations = [transformAnimation, opacityAnimation]
        group.duration = 0.42
        group.isRemovedOnCompletion = true

        layer.add(group, forKey: "feedbackIn")
    }

    private func animateFeedbackOut() {
        guard let layer = feedbackView.layer else {
            feedbackView.isHidden = true
            onFeedbackVisibilityChanged?(false)
            return
        }

        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self] in
            guard let self else { return }
            self.feedbackView.isHidden = true
            self.activeFeedbackStyle = nil
            self.onFeedbackVisibilityChanged?(false)
        }

        let transformAnimation = CABasicAnimation(keyPath: "transform")
        transformAnimation.fromValue = CATransform3DIdentity
        transformAnimation.toValue = CATransform3DMakeScale(0.92, 0.96, 1)
        transformAnimation.duration = 0.18
        transformAnimation.timingFunction = CAMediaTimingFunction(name: .easeIn)

        let opacityAnimation = CABasicAnimation(keyPath: "opacity")
        opacityAnimation.fromValue = 1
        opacityAnimation.toValue = 0
        opacityAnimation.duration = 0.18
        opacityAnimation.timingFunction = CAMediaTimingFunction(name: .easeIn)

        let group = CAAnimationGroup()
        group.animations = [transformAnimation, opacityAnimation]
        group.duration = 0.18
        group.fillMode = .forwards
        group.isRemovedOnCompletion = false

        layer.add(group, forKey: "feedbackOut")
        feedbackView.alphaValue = 0
        CATransaction.commit()
    }

    private func animateMembrane(style: BlockerFeedbackStyle) {
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let colors = style.colors(isDark: isDark)

        membraneLayer.removeAllAnimations()
        baseEdgeLayer.removeAllAnimations()
        highlightEdgeLayer.removeAllAnimations()

        membraneLayer.path = membranePath(depth: 1.5)
        membraneLayer.fillColor = palette.idleMembrane.cgColor
        baseEdgeLayer.path = edgePath(depth: 0)
        baseEdgeLayer.strokeColor = palette.idleEdge.cgColor
        baseEdgeLayer.opacity = 0
        highlightEdgeLayer.path = edgePath(depth: 0)
        highlightEdgeLayer.strokeColor = colors.accent.cgColor
        highlightEdgeLayer.opacity = 0

        let membranePathAnimation = CAKeyframeAnimation(keyPath: "path")
        membranePathAnimation.values = [
            membranePath(depth: 1.5),
            membranePath(depth: min(spillHeight * 0.72, 28)),
            membranePath(depth: min(spillHeight * 0.48, 19)),
            membranePath(depth: min(spillHeight * 0.22, 8)),
            membranePath(depth: 1.5)
        ]
        membranePathAnimation.keyTimes = [0, 0.32, 0.58, 0.80, 1]
        membranePathAnimation.duration = 0.56

        let membraneOpacityAnimation = CAKeyframeAnimation(keyPath: "opacity")
        membraneOpacityAnimation.values = [0.10, 0.70, 0.46, 0.18, 0.10]
        membraneOpacityAnimation.keyTimes = [0, 0.24, 0.52, 0.80, 1]
        membraneOpacityAnimation.duration = 0.56

        let fillAnimation = CABasicAnimation(keyPath: "fillColor")
        fillAnimation.fromValue = palette.idleMembrane.cgColor
        fillAnimation.toValue = colors.jelly.cgColor
        fillAnimation.duration = 0.14
        fillAnimation.autoreverses = true

        let membraneGroup = CAAnimationGroup()
        membraneGroup.animations = [membranePathAnimation, membraneOpacityAnimation, fillAnimation]
        membraneGroup.duration = 0.56
        membraneGroup.isRemovedOnCompletion = true
        membraneLayer.add(membraneGroup, forKey: "membranePulse")

        let basePathAnimation = CAKeyframeAnimation(keyPath: "path")
        basePathAnimation.values = [
            edgePath(depth: 0),
            edgePath(depth: min(spillHeight * 0.74, 29)),
            edgePath(depth: min(spillHeight * 0.44, 17)),
            edgePath(depth: 0)
        ]
        basePathAnimation.keyTimes = [0, 0.32, 0.66, 1]
        basePathAnimation.duration = 0.56

        let baseOpacityAnimation = CAKeyframeAnimation(keyPath: "opacity")
        baseOpacityAnimation.values = [0, 0.58, 0.22, 0]
        baseOpacityAnimation.keyTimes = [0, 0.20, 0.62, 1]
        baseOpacityAnimation.duration = 0.56

        let baseWidthAnimation = CAKeyframeAnimation(keyPath: "lineWidth")
        baseWidthAnimation.values = [1.25, 2.4, 1.7, 1.25]
        baseWidthAnimation.keyTimes = [0, 0.26, 0.62, 1]
        baseWidthAnimation.duration = 0.56

        let baseGroup = CAAnimationGroup()
        baseGroup.animations = [basePathAnimation, baseOpacityAnimation, baseWidthAnimation]
        baseGroup.duration = 0.56
        baseGroup.isRemovedOnCompletion = true
        baseEdgeLayer.add(baseGroup, forKey: "baseEdgePulse")

        let highlightPathAnimation = CAKeyframeAnimation(keyPath: "path")
        highlightPathAnimation.values = [
            edgePath(depth: 0),
            edgePath(depth: min(spillHeight * 0.74, 29)),
            edgePath(depth: min(spillHeight * 0.44, 17)),
            edgePath(depth: 0)
        ]
        highlightPathAnimation.keyTimes = [0, 0.32, 0.66, 1]
        highlightPathAnimation.duration = 0.56

        let highlightOpacityAnimation = CAKeyframeAnimation(keyPath: "opacity")
        highlightOpacityAnimation.values = [0, 0.78, 0.36, 0]
        highlightOpacityAnimation.keyTimes = [0, 0.22, 0.58, 1]
        highlightOpacityAnimation.duration = 0.56

        let highlightWidthAnimation = CAKeyframeAnimation(keyPath: "lineWidth")
        highlightWidthAnimation.values = [2, 8, 4, 2]
        highlightWidthAnimation.keyTimes = [0, 0.26, 0.62, 1]
        highlightWidthAnimation.duration = 0.56

        let highlightGroup = CAAnimationGroup()
        highlightGroup.animations = [highlightPathAnimation, highlightOpacityAnimation, highlightWidthAnimation]
        highlightGroup.duration = 0.56
        highlightGroup.isRemovedOnCompletion = true
        highlightEdgeLayer.add(highlightGroup, forKey: "highlightPulse")
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

        let layout = layout(for: screen, ratio: SettingsManager.shared.blockRatio)
        let window = NSWindow(
            contentRect: layout.blockerFrame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        let blockerContentView = makeBlockerView()
        blockerContentView.spillHeight = layout.spillHeight
        blockerContentView.onFeedbackVisibilityChanged = { [weak self] isShowing in
            self?.setFeedbackPresentation(isShowing)
        }

        window.level = blockerWindowLevel
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        window.isOpaque = false
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.isMovable = false
        window.hidesOnDeactivate = false
        window.canHide = false
        window.backgroundColor = .clear
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
        let layout = layout(for: screen, ratio: SettingsManager.shared.blockRatio)
        window.setFrame(layout.blockerFrame, display: true)
        blockerContentView?.spillHeight = layout.spillHeight
        if isVisible {
            window.orderFrontRegardless()
        }
    }

    func showAdjustmentFeedback(_ style: BlockerFeedbackStyle) {
        blockerContentView?.showFeedback(style)
    }

    private func setFeedbackPresentation(_ isShowing: Bool) {
        guard let window else { return }
        window.level = isShowing ? feedbackWindowLevel : blockerWindowLevel
        if isShowing, isVisible {
            window.orderFrontRegardless()
        }
    }

    private func makeBlockerView() -> BlockerContentView {
        BlockerContentView(frame: .zero)
    }

    private func layout(for screen: NSScreen, ratio: Double) -> (usableRect: NSRect, blockerFrame: NSRect, spillHeight: CGFloat) {
        let managedHeight = max(0, screen.frame.height - reservedTopInset(for: screen))
        let blockedHeight = managedHeight * CGFloat(ratio)
        let usableHeight = max(0, managedHeight - blockedHeight)
        let spillHeight = min(defaultBlockerSpillHeight, usableHeight)

        let usableRect = NSRect(
            x: screen.frame.origin.x,
            y: screen.frame.origin.y,
            width: screen.frame.width,
            height: usableHeight
        )
        let blockerFrame = NSRect(
            x: screen.frame.origin.x,
            y: screen.frame.origin.y + usableHeight - spillHeight,
            width: screen.frame.width,
            height: blockedHeight + spillHeight
        )
        return (usableRect, blockerFrame, spillHeight)
    }

    private func reservedTopInset(for screen: NSScreen) -> CGFloat {
        let visibleTopInset = max(0, screen.frame.maxY - screen.visibleFrame.maxY)
        let separateSpacesInset = NSScreen.screensHaveSeparateSpaces ? NSStatusBar.system.thickness : 0
        return max(visibleTopInset, separateSpacesInset)
    }
}
