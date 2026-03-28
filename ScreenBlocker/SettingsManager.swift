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

    @Published var blockRatio: Double

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

    func saveBlockRatio() {
        UserDefaults.standard.set(blockRatio, forKey: Keys.blockRatio)
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
