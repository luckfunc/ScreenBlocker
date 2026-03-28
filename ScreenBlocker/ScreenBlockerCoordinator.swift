import AppKit
import Combine

final class ScreenBlockerCoordinator: ObservableObject, BlockerLayoutProviding {
    let settings: SettingsManager
    let windowController: BlockerWindowController
    let windowWatcher: WindowWatcher

    @Published private(set) var displayedBlockRatio: Double

    private let previewFlushInterval: TimeInterval = 1.0 / 24.0
    private var isEditingBlockRatio = false
    private var pendingPreviewBlockRatio: Double?
    private var isPreviewFlushScheduled = false
    private var cancellables = Set<AnyCancellable>()

    init(
        settings: SettingsManager = .shared,
        windowController: BlockerWindowController = BlockerWindowController(),
        windowWatcher: WindowWatcher = WindowWatcher()
    ) {
        self.settings = settings
        self.windowController = windowController
        self.windowWatcher = windowWatcher
        self.displayedBlockRatio = settings.blockRatio

        self.windowWatcher.layoutProvider = self
        bindDependencies()
        applyDisplayedBlockRatio(settings.blockRatio)
    }

    var targetGeometry: ScreenGeometry? {
        windowController.targetGeometry
    }

    var effectiveBlockRatio: Double {
        displayedBlockRatio
    }

    var isOverlayVisible: Bool {
        windowController.isVisible
    }

    var isWindowAdjustmentEnabled: Bool {
        windowWatcher.isEnabled
    }

    var hasAccessibilityPermission: Bool {
        windowWatcher.hasAccessibilityPermission
    }

    var portraitScreen: NSScreen? {
        windowController.portraitScreen
    }

    func start() {
        windowController.createAndShow(blockRatio: displayedBlockRatio)
        windowWatcher.start()
    }

    func handleScreenParametersChanged() {
        windowController.reposition(blockRatio: displayedBlockRatio)
        windowWatcher.adjustAllWindows()
    }

    func toggleOverlay() {
        windowController.toggle(blockRatio: displayedBlockRatio)
    }

    func toggleWindowAdjustment() {
        windowWatcher.toggle()
    }

    func adjustAllWindows() {
        windowWatcher.adjustAllWindows()
    }

    func requestAccessibility() {
        windowWatcher.requestAccessibility()
    }

    func previewBlockRatio(_ ratio: Double) {
        let normalizedRatio = SettingsManager.clampBlockRatio(ratio)

        if abs(displayedBlockRatio - normalizedRatio) > 0.0001 {
            displayedBlockRatio = normalizedRatio
        }

        pendingPreviewBlockRatio = normalizedRatio
        schedulePreviewFlush()
    }

    func setBlockRatioEditing(_ isEditing: Bool) {
        if isEditing {
            beginBlockRatioEditing()
        } else {
            endBlockRatioEditing()
        }
    }

    private func beginBlockRatioEditing() {
        guard !isEditingBlockRatio else { return }
        isEditingBlockRatio = true
        windowWatcher.beginInteractiveUpdate()
    }

    private func endBlockRatioEditing() {
        guard isEditingBlockRatio else { return }

        let committedRatio = settings.commitBlockRatio(displayedBlockRatio)
        flushPreviewBlockRatio(committedRatio)
        isEditingBlockRatio = false
        windowWatcher.endInteractiveUpdate(applyFinalAdjustment: true)
    }

    private func bindDependencies() {
        settings.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        windowController.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        windowWatcher.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        settings.$blockRatio
            .dropFirst()
            .sink { [weak self] committedRatio in
                guard let self, !self.isEditingBlockRatio else { return }
                self.flushPreviewBlockRatio(committedRatio)
            }
            .store(in: &cancellables)
    }

    private func applyDisplayedBlockRatio(_ ratio: Double) {
        let normalizedRatio = SettingsManager.clampBlockRatio(ratio)

        if abs(displayedBlockRatio - normalizedRatio) > 0.0001 {
            displayedBlockRatio = normalizedRatio
        }

        windowController.reposition(blockRatio: normalizedRatio)
    }

    private func schedulePreviewFlush() {
        guard !isPreviewFlushScheduled else { return }

        isPreviewFlushScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + previewFlushInterval) { [weak self] in
            guard let self else { return }
            self.isPreviewFlushScheduled = false

            guard let ratio = self.pendingPreviewBlockRatio else { return }
            self.pendingPreviewBlockRatio = nil
            self.windowController.reposition(blockRatio: ratio)
        }
    }

    private func flushPreviewBlockRatio(_ ratio: Double) {
        pendingPreviewBlockRatio = nil
        isPreviewFlushScheduled = false
        applyDisplayedBlockRatio(ratio)
    }
}
