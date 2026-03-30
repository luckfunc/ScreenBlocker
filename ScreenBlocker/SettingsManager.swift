import Foundation
import ServiceManagement

final class SettingsManager: ObservableObject {

    static let shared = SettingsManager()
    static let blockRatioRange: ClosedRange<Double> = 0.1...0.8

    private enum Keys {
        static let blockRatio = "blockRatio"
        static let launchAtLogin = "launchAtLogin"
        static let showMenuBarIcon = "showMenuBarIcon"
    }

    @Published private(set) var blockRatio: Double
    @Published private(set) var launchAtLogin: Bool
    @Published private(set) var showMenuBarIcon: Bool

    private let defaults: UserDefaults

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if defaults.object(forKey: Keys.blockRatio) == nil {
            defaults.set(Self.clampedBlockRatio(0.333), forKey: Keys.blockRatio)
        }
        if defaults.object(forKey: Keys.showMenuBarIcon) == nil {
            defaults.set(true, forKey: Keys.showMenuBarIcon)
        }
        self.blockRatio = Self.clampedBlockRatio(defaults.double(forKey: Keys.blockRatio))
        self.launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
        self.showMenuBarIcon = defaults.bool(forKey: Keys.showMenuBarIcon)
    }

    static func clampedBlockRatio(_ value: Double) -> Double {
        min(max((value * 100).rounded() / 100, blockRatioRange.lowerBound), blockRatioRange.upperBound)
    }

    func setBlockRatio(_ value: Double) {
        let clampedValue = Self.clampedBlockRatio(value)
        guard blockRatio != clampedValue else { return }
        blockRatio = clampedValue
        defaults.set(clampedValue, forKey: Keys.blockRatio)
    }

    func setLaunchAtLogin(_ isEnabled: Bool) {
        guard launchAtLogin != isEnabled else { return }
        launchAtLogin = isEnabled
        defaults.set(isEnabled, forKey: Keys.launchAtLogin)
        applyLaunchAtLogin()
    }

    func setShowMenuBarIcon(_ isVisible: Bool) {
        guard showMenuBarIcon != isVisible else { return }
        showMenuBarIcon = isVisible
        defaults.set(isVisible, forKey: Keys.showMenuBarIcon)
    }

    private func applyLaunchAtLogin() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to update login item: \(error)")
        }
    }
}
