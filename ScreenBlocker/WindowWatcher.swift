import AppKit
import ApplicationServices

private let axFullScreenAttribute = "AXFullScreen" as CFString

final class WindowWatcher: ObservableObject {
    @Published var isEnabled = true
    @Published var hasAccessibilityPermission = false

    private weak var blockerController: BlockerWindowController?
    private var observers: [pid_t: AXObserver] = [:]
    private var knownPids: Set<pid_t> = []
    private var workspaceObservers: [NSObjectProtocol] = []
    private var pollTimer: Timer?
    private var scheduledAdjustment: DispatchWorkItem?
    private var isAdjustingAllWindows = false
    private var needsAdjustmentAfterResume = false
    private var paused = false

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
            guard let self else { return }
            self.hasAccessibilityPermission = AXIsProcessTrusted()
            guard self.hasAccessibilityPermission, self.isEnabled else { return }
            self.refreshObservers()
            self.scheduleAdjustAllWindows(after: 0.2)
        }
    }

    func start() {
        isEnabled = true

        if !checkAccessibility() {
            requestAccessibility()
        }

        observeWorkspace()
        refreshObservers()
        scheduleAdjustAllWindows(after: 0.2)

        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
            guard let self = self, self.isEnabled, !self.paused else { return }
            if !self.hasAccessibilityPermission {
                self.hasAccessibilityPermission = AXIsProcessTrusted()
            }
            self.refreshObservers()
        }
    }

    func stop() {
        isEnabled = false
        pollTimer?.invalidate()
        pollTimer = nil
        scheduledAdjustment?.cancel()
        scheduledAdjustment = nil
        needsAdjustmentAfterResume = false
        removeAllObservers()
        for obs in workspaceObservers {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
        }
        workspaceObservers.removeAll()
    }

    func toggle() {
        if isEnabled { stop() } else { start() }
    }

    func pause() {
        paused = true
        scheduledAdjustment?.cancel()
        scheduledAdjustment = nil
    }

    func resume(applyPendingAdjustment: Bool = false) {
        paused = false

        let shouldAdjust = needsAdjustmentAfterResume || applyPendingAdjustment
        needsAdjustmentAfterResume = false

        if shouldAdjust {
            scheduleAdjustAllWindows(after: 0.15)
        }
    }

    func adjustAllWindows() {
        guard !paused, hasAccessibilityPermission else { return }
        guard let usableRect = blockerController?.usableRect,
              let portraitScreen = blockerController?.portraitScreen else { return }
        guard !isAdjustingAllWindows else { return }

        isAdjustingAllWindows = true
        defer { isAdjustingAllWindows = false }

        let screenFrame = portraitScreen.frame
        let desktopMaxY = NSScreen.screens.map(\.frame.maxY).max() ?? screenFrame.maxY
        let myPid = ProcessInfo.processInfo.processIdentifier
        var needsFollowUpAdjustment = false

        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular && app.processIdentifier != myPid {
            let appRef = AXUIElementCreateApplication(app.processIdentifier)
            AXUIElementSetMessagingTimeout(appRef, 0.2)

            var windowsRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &windowsRef) == .success,
                  let windows = windowsRef as? [AXUIElement] else { continue }

            for window in windows {
                let outcome = Self.adjustWindowIfNeeded(
                    window,
                    screenFrame: screenFrame,
                    usableRect: usableRect,
                    desktopMaxY: desktopMaxY
                )
                if outcome == .needsFollowUp {
                    needsFollowUpAdjustment = true
                }
            }
        }

        if needsFollowUpAdjustment {
            scheduleAdjustAllWindows(after: 0.5)
        }
    }

    // MARK: - Workspace observation (app launch/quit)

    private func observeWorkspace() {
        let nc = NSWorkspace.shared.notificationCenter

        let launchObs = nc.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) { [weak self] note in
            guard let self = self, self.isEnabled, !self.paused,
                  let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.activationPolicy == .regular else { return }
            self.addObserver(for: app.processIdentifier)
            self.scheduleAdjustAllWindows(after: 0.4)
        }

        let quitObs = nc.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            guard let self = self,
                  let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            self.removeObserver(for: app.processIdentifier)
        }

        workspaceObservers = [launchObs, quitObs]
    }

    // MARK: - AXObserver per app

    private func refreshObservers() {
        guard hasAccessibilityPermission else { return }

        let myPid = ProcessInfo.processInfo.processIdentifier
        let currentPids = Set(
            NSWorkspace.shared.runningApplications
                .filter { $0.activationPolicy == .regular && $0.processIdentifier != myPid }
                .map { $0.processIdentifier }
        )

        for pid in knownPids.subtracting(currentPids) {
            removeObserver(for: pid)
        }
        for pid in currentPids.subtracting(knownPids) {
            addObserver(for: pid)
        }
    }

    private func addObserver(for pid: pid_t) {
        guard observers[pid] == nil else { return }

        var observer: AXObserver?
        let result = AXObserverCreate(pid, axCallback, &observer)
        guard result == .success, let observer = observer else { return }

        let appRef = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(appRef, 0.2)

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        AXObserverAddNotification(observer, appRef, kAXWindowCreatedNotification as CFString, refcon)
        AXObserverAddNotification(observer, appRef, kAXWindowMovedNotification as CFString, refcon)
        AXObserverAddNotification(observer, appRef, kAXWindowResizedNotification as CFString, refcon)

        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)

        observers[pid] = observer
        knownPids.insert(pid)
    }

    private func removeObserver(for pid: pid_t) {
        if let observer = observers.removeValue(forKey: pid) {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        }
        knownPids.remove(pid)
    }

    private func removeAllObservers() {
        for pid in Array(knownPids) {
            removeObserver(for: pid)
        }
    }

    // MARK: - Handle AX notification

    func handleWindowEvent(_ element: AXUIElement) {
        guard !paused, isEnabled else { return }
        scheduleAdjustAllWindows(after: 0.15)
    }

    private func scheduleAdjustAllWindows(after delay: TimeInterval) {
        guard isEnabled, hasAccessibilityPermission else { return }

        if paused {
            needsAdjustmentAfterResume = true
            return
        }

        scheduledAdjustment?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.scheduledAdjustment = nil
            self?.adjustAllWindows()
        }

        scheduledAdjustment = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    // MARK: - Window adjustment

    private enum AdjustmentOutcome {
        case unchanged
        case adjusted
        case needsFollowUp
    }

    private static func adjustWindowIfNeeded(
        _ window: AXUIElement,
        screenFrame: NSRect,
        usableRect: NSRect,
        desktopMaxY: CGFloat
    ) -> AdjustmentOutcome {
        var posRef: CFTypeRef?
        var sizeRef: CFTypeRef?

        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &posRef) == .success,
              AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef) == .success else {
            return .unchanged
        }

        var position = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(posRef as! AXValue, .cgPoint, &position)
        AXValueGetValue(sizeRef as! AXValue, .cgSize, &size)

        let screenTopCG = desktopMaxY - screenFrame.maxY
        let screenCGRect = NSRect(x: screenFrame.origin.x, y: screenTopCG, width: screenFrame.width, height: screenFrame.height)

        let centerX = position.x + size.width / 2
        let centerY = position.y + size.height / 2
        guard centerX >= screenCGRect.minX && centerX <= screenCGRect.maxX &&
              centerY >= screenCGRect.minY && centerY <= screenCGRect.maxY else {
            return .unchanged
        }

        if isWindowFullScreen(window) {
            let result = AXUIElementSetAttributeValue(window, axFullScreenAttribute, kCFBooleanFalse)
            return result == .success ? .needsFollowUp : .unchanged
        }

        let usableTopCG = desktopMaxY - usableRect.maxY
        let usableBottomCG = usableTopCG + usableRect.height

        guard position.y < usableTopCG || position.y + size.height > usableBottomCG else {
            return .unchanged
        }

        let newY = usableTopCG
        var newHeight = size.height
        if newY + newHeight > usableBottomCG {
            newHeight = usableBottomCG - newY
            if newHeight < 200 { newHeight = 200 }
        }

        var newPos = CGPoint(x: position.x, y: newY)
        var newSize = CGSize(width: size.width, height: newHeight)
        let positionResult = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, AXValueCreate(.cgPoint, &newPos)!)
        let sizeResult = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, AXValueCreate(.cgSize, &newSize)!)

        return (positionResult == .success || sizeResult == .success) ? .adjusted : .unchanged
    }

    private static func isWindowFullScreen(_ window: AXUIElement) -> Bool {
        var fullScreenRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, axFullScreenAttribute, &fullScreenRef) == .success,
              let fullScreen = fullScreenRef as? NSNumber else {
            return false
        }

        return fullScreen.boolValue
    }
}

// MARK: - C callback

private func axCallback(_ observer: AXObserver, _ element: AXUIElement, _ notification: CFString, _ refcon: UnsafeMutableRawPointer?) {
    guard let refcon = refcon else { return }
    let watcher = Unmanaged<WindowWatcher>.fromOpaque(refcon).takeUnretainedValue()
    watcher.handleWindowEvent(element)
}
