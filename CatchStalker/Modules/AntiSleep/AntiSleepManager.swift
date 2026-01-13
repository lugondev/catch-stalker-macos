import Foundation
import AppKit
import IOKit.pwr_mgt

enum AntiSleepDuration: Int, CaseIterable {
    case indefinite = 0
    case minutes5 = 5
    case minutes15 = 15
    case minutes30 = 30
    case hour1 = 60
    case hours2 = 120
    case hours4 = 240
    case hours8 = 480
    
    var displayName: String {
        switch self {
        case .indefinite: return "Indefinitely"
        case .minutes5: return "5 minutes"
        case .minutes15: return "15 minutes"
        case .minutes30: return "30 minutes"
        case .hour1: return "1 hour"
        case .hours2: return "2 hours"
        case .hours4: return "4 hours"
        case .hours8: return "8 hours"
        }
    }
    
    var timeInterval: TimeInterval? {
        if self == .indefinite { return nil }
        return TimeInterval(rawValue * 60)
    }
}

final class AntiSleepManager: ObservableObject {
    static let shared = AntiSleepManager()
    
    @Published var isEnabled = false
    @Published var isActiveBySchedule = false
    @Published var isActiveByApp = false
    @Published var selectedDuration: AntiSleepDuration = .indefinite
    @Published var remainingTime: TimeInterval = 0
    
    private var assertionID: IOPMAssertionID = 0
    private var scheduleTimer: Timer?
    private var appObserver: NSObjectProtocol?
    private var durationTimer: Timer?
    private var endTime: Date?
    
    private init() {}
    
    func enableGlobal(duration: AntiSleepDuration = .indefinite) {
        selectedDuration = duration
        createAssertion()
        isEnabled = true
        
        durationTimer?.invalidate()
        durationTimer = nil
        
        if let interval = duration.timeInterval {
            endTime = Date().addingTimeInterval(interval)
            remainingTime = interval
            
            durationTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                self?.updateRemainingTime()
            }
        } else {
            endTime = nil
            remainingTime = 0
        }
    }
    
    func disableGlobal() {
        durationTimer?.invalidate()
        durationTimer = nil
        endTime = nil
        remainingTime = 0
        selectedDuration = .indefinite
        releaseAssertion()
        isEnabled = false
    }
    
    func toggleGlobal() {
        if isEnabled {
            disableGlobal()
        } else {
            enableGlobal()
        }
    }
    
    func enableWithDuration(_ duration: AntiSleepDuration) {
        if isEnabled {
            disableGlobal()
        }
        enableGlobal(duration: duration)
    }
    
    private func updateRemainingTime() {
        guard let endTime = endTime else {
            remainingTime = 0
            return
        }
        
        remainingTime = max(0, endTime.timeIntervalSinceNow)
        
        if remainingTime <= 0 {
            disableGlobal()
        }
    }
    
    var formattedRemainingTime: String {
        guard remainingTime > 0 else { return "" }
        
        let hours = Int(remainingTime) / 3600
        let minutes = (Int(remainingTime) % 3600) / 60
        let seconds = Int(remainingTime) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    private func createAssertion() {
        let reason = "CatchStalker Anti-Sleep" as CFString
        let status = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &assertionID
        )
        
        if status != kIOReturnSuccess {
            print("Failed to create power assertion: \(status)")
        }
    }
    
    private func releaseAssertion() {
        if assertionID != 0 {
            IOPMAssertionRelease(assertionID)
            assertionID = 0
        }
    }
    
    func startScheduleMonitoring() {
        scheduleTimer?.invalidate()
        scheduleTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.checkSchedules()
        }
        checkSchedules()
    }
    
    func stopScheduleMonitoring() {
        scheduleTimer?.invalidate()
        scheduleTimer = nil
        if isActiveBySchedule {
            isActiveBySchedule = false
            updateAssertionState()
        }
    }
    
    private func checkSchedules() {
        let schedules = SettingsManager.shared.settings.antiSleepSchedules.filter { $0.isEnabled }
        let now = Date()
        let calendar = Calendar.current
        let currentWeekday = Weekday(rawValue: calendar.component(.weekday, from: now))
        
        var shouldBeActive = false
        
        for schedule in schedules {
            guard let weekday = currentWeekday, schedule.weekdays.contains(weekday) else { continue }
            
            let startComponents = calendar.dateComponents([.hour, .minute], from: schedule.startTime)
            let endComponents = calendar.dateComponents([.hour, .minute], from: schedule.endTime)
            let nowComponents = calendar.dateComponents([.hour, .minute], from: now)
            
            let startMinutes = (startComponents.hour ?? 0) * 60 + (startComponents.minute ?? 0)
            let endMinutes = (endComponents.hour ?? 0) * 60 + (endComponents.minute ?? 0)
            let nowMinutes = (nowComponents.hour ?? 0) * 60 + (nowComponents.minute ?? 0)
            
            if startMinutes <= endMinutes {
                if nowMinutes >= startMinutes && nowMinutes < endMinutes {
                    shouldBeActive = true
                    break
                }
            } else {
                if nowMinutes >= startMinutes || nowMinutes < endMinutes {
                    shouldBeActive = true
                    break
                }
            }
        }
        
        if shouldBeActive != isActiveBySchedule {
            isActiveBySchedule = shouldBeActive
            updateAssertionState()
        }
    }
    
    func startAppMonitoring() {
        appObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.checkAppRules(notification)
        }
        
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            checkAppRule(bundleId: frontApp.bundleIdentifier)
        }
    }
    
    func stopAppMonitoring() {
        if let observer = appObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        appObserver = nil
        if isActiveByApp {
            isActiveByApp = false
            updateAssertionState()
        }
    }
    
    private func checkAppRules(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        checkAppRule(bundleId: app.bundleIdentifier)
    }
    
    private func checkAppRule(bundleId: String?) {
        guard let bundleId = bundleId else {
            isActiveByApp = false
            updateAssertionState()
            return
        }
        
        let rules = SettingsManager.shared.settings.antiSleepAppRules.filter { $0.isEnabled }
        let shouldBeActive = rules.contains { $0.bundleIdentifier == bundleId }
        
        if shouldBeActive != isActiveByApp {
            isActiveByApp = shouldBeActive
            updateAssertionState()
        }
    }
    
    private func updateAssertionState() {
        let shouldHaveAssertion = isEnabled || isActiveBySchedule || isActiveByApp
        
        if shouldHaveAssertion && assertionID == 0 {
            createAssertion()
        } else if !shouldHaveAssertion && assertionID != 0 {
            releaseAssertion()
        }
    }
    
    func addAppRule(bundleId: String, appName: String) {
        let rule = AntiSleepAppRule(bundleIdentifier: bundleId, appName: appName)
        SettingsManager.shared.addAntiSleepAppRule(rule)
    }
    
    func removeAppRule(at index: Int) {
        SettingsManager.shared.removeAntiSleepAppRule(at: index)
    }
    
    func addSchedule(name: String, startTime: Date, endTime: Date, weekdays: Set<Weekday>) {
        let schedule = AntiSleepSchedule(name: name, startTime: startTime, endTime: endTime, weekdays: weekdays)
        SettingsManager.shared.addAntiSleepSchedule(schedule)
    }
    
    func removeSchedule(at index: Int) {
        SettingsManager.shared.removeAntiSleepSchedule(at: index)
    }
    
    deinit {
        releaseAssertion()
    }
}
