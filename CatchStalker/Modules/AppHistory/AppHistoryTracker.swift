import Foundation
import Cocoa

final class AppHistoryTracker: ObservableObject {
    static let shared = AppHistoryTracker()
    
    @Published var isRunning = false
    @Published var currentApp: AppHistoryEvent?
    
    private var observer: NSObjectProtocol?
    private var lastActivatedApp: String?
    private var lastActivationTime: Date?
    
    private init() {}
    
    func start() {
        guard !isRunning else { return }
        
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleAppActivation(notification)
        }
        
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            recordAppActivation(app: frontApp)
        }
        
        isRunning = true
    }
    
    func stop() {
        if let observer = observer {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        observer = nil
        
        if let lastApp = lastActivatedApp, let lastTime = lastActivationTime {
            let duration = Date().timeIntervalSince(lastTime)
            let event = AppHistoryEvent(
                bundleIdentifier: lastApp,
                appName: lastApp,
                windowTitle: nil,
                eventType: .deactivated,
                duration: duration
            )
            DatabaseManager.shared.insertAppHistory(event)
        }
        
        isRunning = false
    }
    
    private func handleAppActivation(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        
        if let lastApp = lastActivatedApp, let lastTime = lastActivationTime {
            let duration = Date().timeIntervalSince(lastTime)
            let deactivateEvent = AppHistoryEvent(
                bundleIdentifier: lastApp,
                appName: lastApp,
                windowTitle: nil,
                eventType: .deactivated,
                duration: duration
            )
            DatabaseManager.shared.insertAppHistory(deactivateEvent)
        }
        
        recordAppActivation(app: app)
    }
    
    private func recordAppActivation(app: NSRunningApplication) {
        let bundleId = app.bundleIdentifier ?? "unknown"
        let appName = app.localizedName ?? "Unknown"
        
        lastActivatedApp = bundleId
        lastActivationTime = Date()
        
        let event = AppHistoryEvent(
            bundleIdentifier: bundleId,
            appName: appName,
            windowTitle: getActiveWindowTitle(),
            eventType: .activated
        )
        
        DispatchQueue.main.async { [weak self] in
            self?.currentApp = event
        }
        
        DatabaseManager.shared.insertAppHistory(event)
    }
    
    private func getActiveWindowTitle() -> String? {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return nil }
        
        let options = CGWindowListOption(arrayLiteral: .optionOnScreenOnly, .excludeDesktopElements)
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else { return nil }
        
        let pid = frontApp.processIdentifier
        for window in windowList {
            if let windowPID = window[kCGWindowOwnerPID as String] as? Int32, windowPID == pid {
                return window[kCGWindowName as String] as? String
            }
        }
        
        return nil
    }
    
    func getCurrentAppBundleId() -> String? {
        return NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }
}
