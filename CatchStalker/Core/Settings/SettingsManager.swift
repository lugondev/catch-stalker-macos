import Foundation
import Combine

final class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    @Published var settings: AppSettings
    
    private let settingsKey = "CatchStalkerSettings"
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        if let data = UserDefaults.standard.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            settings = decoded
        } else {
            settings = AppSettings.default
        }
        
        setupAutoSave()
        ensureStorageDirectories()
    }
    
    private func setupAutoSave() {
        $settings
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak self] settings in
                self?.save(settings)
            }
            .store(in: &cancellables)
    }
    
    private func save(_ settings: AppSettings) {
        if let encoded = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(encoded, forKey: settingsKey)
        }
    }
    
    private func ensureStorageDirectories() {
        let fileManager = FileManager.default
        
        let directories = [
            settings.screenshotStoragePath,
            settings.cameraStoragePath
        ]
        
        for dir in directories {
            if !dir.isEmpty {
                try? fileManager.createDirectory(atPath: dir, withIntermediateDirectories: true)
            }
        }
    }
    
    func updateScreenshotPath(_ path: String) {
        settings.screenshotStoragePath = path
        try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
    }
    
    func updateCameraPath(_ path: String) {
        settings.cameraStoragePath = path
        try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
    }
    
    func addAntiSleepSchedule(_ schedule: AntiSleepSchedule) {
        settings.antiSleepSchedules.append(schedule)
    }
    
    func removeAntiSleepSchedule(at index: Int) {
        guard index < settings.antiSleepSchedules.count else { return }
        settings.antiSleepSchedules.remove(at: index)
    }
    
    func addAntiSleepAppRule(_ rule: AntiSleepAppRule) {
        settings.antiSleepAppRules.append(rule)
    }
    
    func removeAntiSleepAppRule(at index: Int) {
        guard index < settings.antiSleepAppRules.count else { return }
        settings.antiSleepAppRules.remove(at: index)
    }
    
    func addProtectedAppRule(_ rule: ProtectedAppRule) {
        settings.protectedAppRules.append(rule)
    }
    
    func removeProtectedAppRule(at index: Int) {
        guard index < settings.protectedAppRules.count else { return }
        settings.protectedAppRules.remove(at: index)
    }
    
    func resetToDefaults() {
        settings = AppSettings.default
        ensureStorageDirectories()
    }
    
    func triggerSave() {
        let current = settings
        settings = current
    }
    
    func saveImmediately() {
        save(settings)
    }
}
