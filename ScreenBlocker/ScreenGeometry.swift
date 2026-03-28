import AppKit

/// Bridges AppKit screen frames and Accessibility window frames so callers
/// can reason about placement without re-implementing global coordinate math.
struct ScreenGeometry {
    let screenFrame: CGRect
    let desktopFrame: CGRect

    init?(screen: NSScreen, allScreens: [NSScreen] = NSScreen.screens) {
        guard let firstScreen = allScreens.first else { return nil }

        self.screenFrame = screen.frame
        self.desktopFrame = allScreens
            .dropFirst()
            .reduce(firstScreen.frame) { partialResult, nextScreen in
                partialResult.union(nextScreen.frame)
            }
    }

    var accessibilityFrame: CGRect {
        accessibilityRect(for: screenFrame)
    }

    func usableRect(for blockedRatio: Double) -> CGRect {
        let ratio = SettingsManager.clampBlockRatio(blockedRatio)
        let usableHeight = screenFrame.height * (1.0 - ratio)
        return CGRect(
            x: screenFrame.minX,
            y: screenFrame.minY,
            width: screenFrame.width,
            height: usableHeight
        )
    }

    func blockedRect(for blockedRatio: Double) -> CGRect {
        let ratio = SettingsManager.clampBlockRatio(blockedRatio)
        let blockedHeight = screenFrame.height * ratio
        return CGRect(
            x: screenFrame.minX,
            y: screenFrame.maxY - blockedHeight,
            width: screenFrame.width,
            height: blockedHeight
        )
    }

    func adjustedWindowFrame(windowFrameAX: CGRect, blockedRatio: Double, minimumHeight: CGFloat = 200) -> CGRect? {
        let windowMidpoint = CGPoint(x: windowFrameAX.midX, y: windowFrameAX.midY)
        guard accessibilityFrame.contains(windowMidpoint) else { return nil }

        let usableFrameAX = accessibilityRect(for: usableRect(for: blockedRatio))
        guard windowFrameAX.minY < usableFrameAX.minY else { return nil }

        var adjustedFrame = windowFrameAX
        adjustedFrame.origin.y = usableFrameAX.minY

        if adjustedFrame.maxY > usableFrameAX.maxY {
            let availableHeight = usableFrameAX.maxY - adjustedFrame.minY
            let minimumAllowedHeight = min(minimumHeight, availableHeight)
            adjustedFrame.size.height = max(min(windowFrameAX.height, availableHeight), minimumAllowedHeight)
        }

        guard adjustedFrame != windowFrameAX else { return nil }
        return adjustedFrame
    }

    private func accessibilityRect(for appKitRect: CGRect) -> CGRect {
        CGRect(
            x: appKitRect.minX,
            y: desktopFrame.maxY - appKitRect.maxY,
            width: appKitRect.width,
            height: appKitRect.height
        )
    }
}
