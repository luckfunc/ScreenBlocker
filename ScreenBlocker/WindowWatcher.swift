import AppKit
import ApplicationServices

final class WindowWatcher: ObservableObject {
    @Published var isEnabled = true
    @Published var hasAccessibilityPermission = false

    private var timer: Timer?
    private weak var blockerController: BlockerWindowController?
    private let workQueue = DispatchQueue(label: "com.xdd.ScreenBlocker.watcher", qos: .utility)
    private var isAdjusting = false
    private var pendingAdjustment = false
    private var interactiveUpdateDepth = 0

    init(blockerController: BlockerWindowController) {
        self.blockerController = blockerController
        _ = checkAccessibility()
    }

    @discardableResult
    func checkAccessibility() -> Bool {
        let trusted = AXIsProcessTrusted()
        hasAccessibilityPermission = trusted
        return trusted
    }

    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.hasAccessibilityPermission = AXIsProcessTrusted()
        }
    }

    func start() {
        isEnabled = true

        if !checkAccessibility() {
            requestAccessibility()
        } else {
            adjustAllWindows()
        }

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            guard let self = self, self.isEnabled else { return }
            if !self.hasAccessibilityPermission {
                self.hasAccessibilityPermission = AXIsProcessTrusted()
            }
            if self.hasAccessibilityPermission {
                self.adjustAllWindows()
            }
        }
    }

    func stop() {
        isEnabled = false
        timer?.invalidate()
        timer = nil
    }

    func toggle() {
        if isEnabled { stop() } else { start() }
    }

    func beginInteractiveUpdate() {
        interactiveUpdateDepth += 1
    }

    func endInteractiveUpdate(applyFinalAdjustment: Bool) {
        interactiveUpdateDepth = max(0, interactiveUpdateDepth - 1)

        guard interactiveUpdateDepth == 0 else { return }
        guard applyFinalAdjustment, isEnabled, hasAccessibilityPermission else {
            pendingAdjustment = false
            return
        }

        requestAdjustment()
    }

    func adjustAllWindows() {
        requestAdjustment()
    }

    private func requestAdjustment() {
        if interactiveUpdateDepth > 0 || isAdjusting {
            pendingAdjustment = true
            return
        }

        guard let usableRect = blockerController?.usableRect,
              let portraitScreen = blockerController?.portraitScreen else { return }

        let screenFrame = portraitScreen.frame
        let mainHeight = NSScreen.screens.first?.frame.height ?? screenFrame.height

        let myPid = ProcessInfo.processInfo.processIdentifier
        let pids = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.processIdentifier != myPid }
            .map { $0.processIdentifier }

        isAdjusting = true
        pendingAdjustment = false
        workQueue.async { [weak self] in
            defer { DispatchQueue.main.async { self?.finishAdjustmentPass() } }

            for pid in pids {
                let appRef = AXUIElementCreateApplication(pid)
                AXUIElementSetMessagingTimeout(appRef, 0.3)

                var windowsRef: CFTypeRef?
                guard AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &windowsRef) == .success,
                      let windows = windowsRef as? [AXUIElement] else { continue }

                for window in windows {
                    self?.adjustWindow(window, screenFrame: screenFrame, usableRect: usableRect, mainScreenHeight: mainHeight)
                }
            }
        }
    }

    private func finishAdjustmentPass() {
        isAdjusting = false

        guard pendingAdjustment, interactiveUpdateDepth == 0, hasAccessibilityPermission else { return }
        requestAdjustment()
    }

    private func adjustWindow(_ window: AXUIElement, screenFrame: NSRect, usableRect: NSRect, mainScreenHeight: CGFloat) {
        guard let (position, size) = getWindowFrame(window) else { return }

        let windowRect = NSRect(x: position.x, y: position.y, width: size.width, height: size.height)

        guard windowIsOnScreen(windowRect, screenFrame: screenFrame, mainScreenHeight: mainScreenHeight) else { return }

        let usableTopCG = mainScreenHeight - (usableRect.origin.y + usableRect.height)
        let usableBottomCG = usableTopCG + usableRect.height
        let blockedZoneBottom = usableTopCG

        guard position.y < blockedZoneBottom else { return }

        let newY = blockedZoneBottom
        var newHeight = size.height

        if newY + newHeight > usableBottomCG {
            newHeight = usableBottomCG - newY
            if newHeight < 200 { newHeight = 200 }
        }

        var newPos = CGPoint(x: position.x, y: newY)
        var newSize = CGSize(width: size.width, height: newHeight)

        let posValue = AXValueCreate(.cgPoint, &newPos)!
        let sizeValue = AXValueCreate(.cgSize, &newSize)!

        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posValue)
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
    }

    private func getWindowFrame(_ window: AXUIElement) -> (CGPoint, CGSize)? {
        var posRef: CFTypeRef?
        var sizeRef: CFTypeRef?

        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &posRef) == .success,
              AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef) == .success else {
            return nil
        }

        var position = CGPoint.zero
        var size = CGSize.zero

        AXValueGetValue(posRef as! AXValue, .cgPoint, &position)
        AXValueGetValue(sizeRef as! AXValue, .cgSize, &size)

        return (position, size)
    }

    private func windowIsOnScreen(_ windowRect: NSRect, screenFrame: NSRect, mainScreenHeight: CGFloat) -> Bool {
        let screenTopCG = mainScreenHeight - (screenFrame.origin.y + screenFrame.height)
        let screenCGRect = NSRect(
            x: screenFrame.origin.x,
            y: screenTopCG,
            width: screenFrame.width,
            height: screenFrame.height
        )

        return windowRect.midX >= screenCGRect.minX && windowRect.midX <= screenCGRect.maxX &&
               windowRect.midY >= screenCGRect.minY && windowRect.midY <= screenCGRect.maxY
    }
}
