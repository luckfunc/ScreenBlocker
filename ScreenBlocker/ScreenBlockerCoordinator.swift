import AppKit
import Combine

final class ScreenBlockerCoordinator: ObservableObject, BlockerLayoutProviding {
    let settings: SettingsManager
    let windowController: BlockerWindowController
    let windowWatcher: WindowWatcher

    @Published private(set) var displayedBlockRatio: Double

    private var isEditingBlockRatio = false
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
    }

    var targetGeometry: ScreenGeometry? {
        windowController.targetGeometry
    }

    var effectiveBlockRatio: Double {
        settings.blockRatio
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
        let committedRatio = settings.blockRatio
        windowController.createAndShow(blockRatio: committedRatio)
        windowWatcher.start()
    }

    func handleScreenParametersChanged() {
        let committedRatio = settings.blockRatio
        windowController.reposition(blockRatio: committedRatio)
        windowWatcher.adjustAllWindows()
    }

    func toggleOverlay() {
        windowController.toggle(blockRatio: settings.blockRatio)
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

        let previousRatio = settings.blockRatio
        let committedRatio = settings.commitBlockRatio(displayedBlockRatio)
        displayedBlockRatio = committedRatio
        isEditingBlockRatio = false
        windowController.reposition(blockRatio: committedRatio)

        let didChangeRatio = abs(previousRatio - committedRatio) > 0.0001
        windowWatcher.endInteractiveUpdate(applyFinalAdjustment: didChangeRatio)
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
                self.displayedBlockRatio = committedRatio
                self.windowController.reposition(blockRatio: committedRatio)
            }
            .store(in: &cancellables)
    }
}
