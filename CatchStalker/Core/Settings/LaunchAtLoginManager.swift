import Foundation
import ServiceManagement

@available(macOS 13.0, *)
final class LaunchAtLoginManager: ObservableObject {
    static let shared = LaunchAtLoginManager()
    
    @Published var isEnabled: Bool {
        didSet {
            if isEnabled != oldValue {
                setLaunchAtLogin(enabled: isEnabled)
            }
        }
    }
    
    private init() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }
    
    private func setLaunchAtLogin(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to \(enabled ? "enable" : "disable") launch at login: \(error)")
            // Revert the published value on failure
            DispatchQueue.main.async { [weak self] in
                self?.isEnabled = !enabled
            }
        }
    }
    
    func refreshStatus() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }
}

// Fallback for older macOS versions
final class LaunchAtLoginManagerLegacy: ObservableObject {
    static let shared = LaunchAtLoginManagerLegacy()
    
    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "LaunchAtLogin")
        }
    }
    
    private init() {
        isEnabled = UserDefaults.standard.bool(forKey: "LaunchAtLogin")
    }
}
