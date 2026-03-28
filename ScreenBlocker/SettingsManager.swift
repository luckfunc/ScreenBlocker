import Foundation
import ServiceManagement
import Combine

final class SettingsManager: ObservableObject {

    static let shared = SettingsManager()

    private enum Keys {
        static let blockRatio = "blockRatio"
        static let launchAtLogin = "launchAtLogin"
        static let showMenuBarIcon = "showMenuBarIcon"
    }

    static let blockRatioRange = 0.1...0.8

    /// Fraction of the portrait screen blocked from the top (0.1 ~ 0.8)
    @Published private(set) var blockRatio: Double

    @Published var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: Keys.launchAtLogin)
            applyLaunchAtLogin()
        }
    }

    @Published var showMenuBarIcon: Bool {
        didSet { UserDefaults.standard.set(showMenuBarIcon, forKey: Keys.showMenuBarIcon) }
    }

    private init() {
        let defaults = UserDefaults.standard

        if defaults.object(forKey: Keys.blockRatio) == nil {
            defaults.set(0.333, forKey: Keys.blockRatio)
        }
        if defaults.object(forKey: Keys.showMenuBarIcon) == nil {
            defaults.set(true, forKey: Keys.showMenuBarIcon)
        }

        self.blockRatio = defaults.double(forKey: Keys.blockRatio)
        self.launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
        self.showMenuBarIcon = defaults.bool(forKey: Keys.showMenuBarIcon)
    }

    @discardableResult
    func commitBlockRatio(_ ratio: Double) -> Double {
        let normalizedRatio = Self.clampBlockRatio(ratio)

        guard abs(blockRatio - normalizedRatio) > 0.0001 else {
            return blockRatio
        }

        blockRatio = normalizedRatio
        UserDefaults.standard.set(normalizedRatio, forKey: Keys.blockRatio)
        return normalizedRatio
    }

    static func clampBlockRatio(_ ratio: Double) -> Double {
        min(max(ratio, blockRatioRange.lowerBound), blockRatioRange.upperBound)
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
