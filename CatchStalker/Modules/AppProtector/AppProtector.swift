import Foundation
import Cocoa
import os.log

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "CatchStalker", category: "AppProtector")

final class AppProtector: ObservableObject {
    static let shared = AppProtector()
    
    @Published var isRunning = false
    @Published var lastBlockedApp: String?
    @Published var blockCount: Int = 0
    
    private var activationObserver: NSObjectProtocol?
    private var launchObserver: NSObjectProtocol?
    private var pollingTimer: Timer?
    private var isRedirecting = false
    private var lastCheckedBundleId: String?
    
    private init() {}
    
    func start() {
        guard !isRunning else {
            logger.info("Already running")
            return
        }
        
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleAppActivation(notification)
        }
        
        launchObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleAppLaunch(notification)
        }
        
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            self?.checkFrontmostApp()
        }
        
        isRunning = true
        logger.info("Started successfully")
    }
    
    func stop() {
        if let observer = activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        if let observer = launchObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        pollingTimer?.invalidate()
        pollingTimer = nil
        activationObserver = nil
        launchObserver = nil
        isRunning = false
        logger.info("Stopped")
    }
    
    private func handleAppActivation(_ notification: Notification) {
        guard !isRedirecting else { return }
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        processProtectedApp(app)
    }
    
    private func handleAppLaunch(_ notification: Notification) {
        guard !isRedirecting else { return }
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        processProtectedApp(app)
    }
    
    private func checkFrontmostApp() {
        guard !isRedirecting else { return }
        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        guard let bundleId = app.bundleIdentifier else { return }
        
        if bundleId != lastCheckedBundleId {
            lastCheckedBundleId = bundleId
            processProtectedApp(app)
        }
    }
    
    private func processProtectedApp(_ app: NSRunningApplication) {
        guard let bundleId = app.bundleIdentifier else { return }
        
        let settings = SettingsManager.shared.settings
        
        guard settings.appProtectionEnabled else { return }
        guard !settings.redirectAppConfig.isEmpty else { return }
        
        let isProtected = settings.protectedAppRules.contains { rule in
            rule.isEnabled && rule.bundleIdentifier == bundleId
        }
        
        guard isProtected else { return }
        
        let appName = app.localizedName ?? bundleId
        logger.notice(">>> BLOCKING protected app: \(appName, privacy: .public)")
        
        isRedirecting = true
        lastCheckedBundleId = nil
        
        app.hide()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.redirectToConfiguredApp()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self?.lastBlockedApp = appName
                self?.blockCount += 1
                self?.isRedirecting = false
                logger.info("Block completed, count: \(self?.blockCount ?? 0)")
            }
        }
    }
    
    private func redirectToConfiguredApp() {
        let config = SettingsManager.shared.settings.redirectAppConfig
        guard !config.isEmpty else { return }
        
        if let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == config.bundleIdentifier }) {
            app.activate()
            lastCheckedBundleId = config.bundleIdentifier
            logger.info("Activated running app: \(config.appName, privacy: .public)")
        } else {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: config.bundleIdentifier) {
                NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { [weak self] _, error in
                    if let error = error {
                        logger.error("Failed to launch redirect app: \(error.localizedDescription, privacy: .public)")
                    } else {
                        self?.lastCheckedBundleId = config.bundleIdentifier
                        logger.info("Launched redirect app: \(config.appName, privacy: .public)")
                    }
                }
            } else {
                logger.error("Redirect app not found: \(config.bundleIdentifier, privacy: .public)")
            }
        }
    }
    
    func isAppProtected(_ bundleIdentifier: String) -> Bool {
        let settings = SettingsManager.shared.settings
        return settings.appProtectionEnabled && settings.protectedAppRules.contains { rule in
            rule.isEnabled && rule.bundleIdentifier == bundleIdentifier
        }
    }
    
    func addProtectedApp(bundleId: String, appName: String) {
        let exists = SettingsManager.shared.settings.protectedAppRules.contains { $0.bundleIdentifier == bundleId }
        guard !exists else {
            logger.warning("App already protected: \(appName, privacy: .public)")
            return
        }
        
        let rule = ProtectedAppRule(bundleIdentifier: bundleId, appName: appName)
        SettingsManager.shared.settings.protectedAppRules.append(rule)
        logger.info("Added protected app: \(appName, privacy: .public)")
    }
    
    func removeProtectedApp(at index: Int) {
        guard index < SettingsManager.shared.settings.protectedAppRules.count else { return }
        let removed = SettingsManager.shared.settings.protectedAppRules.remove(at: index)
        logger.info("Removed protected app: \(removed.appName, privacy: .public)")
    }
    
    func setRedirectApp(bundleId: String, appName: String) {
        SettingsManager.shared.settings.redirectAppConfig = RedirectAppConfig(
            bundleIdentifier: bundleId,
            appName: appName
        )
        logger.info("Set redirect app: \(appName, privacy: .public)")
    }
    
    func clearRedirectApp() {
        SettingsManager.shared.settings.redirectAppConfig = RedirectAppConfig()
        logger.info("Cleared redirect app")
    }
}
