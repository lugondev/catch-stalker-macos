import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var mainWindow: NSWindow?
    private var popover: NSPopover?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        startServices()
    }
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "eye.fill", accessibilityDescription: "CatchStalker")
            button.action = #selector(togglePopover)
            button.target = self
        }
        
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 400)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: MenuBarView(
            openMainWindow: { [weak self] in self?.showMainWindow() },
            quitApp: { NSApplication.shared.terminate(nil) }
        ))
        self.popover = popover
    }
    
    @objc private func togglePopover() {
        guard let button = statusItem.button, let popover = popover else { return }
        
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.becomeKey()
        }
    }
    
    private func showMainWindow() {
        popover?.performClose(nil)
        
        if mainWindow == nil {
            let contentView = MainWindowView()
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 1000, height: 700),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.center()
            window.title = "CatchStalker"
            window.contentView = NSHostingView(rootView: contentView)
            window.isReleasedWhenClosed = false
            mainWindow = window
        }
        
        mainWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func startServices() {
        PermissionsManager.shared.checkAllPermissions()
        
        let settings = SettingsManager.shared.settings
        
        if settings.keystrokeEnabled {
            KeystrokeLogger.shared.start()
        }
        if settings.mouseEnabled {
            MouseTracker.shared.start()
        }
        if settings.screenshotEnabled {
            ScreenshotCapture.shared.start()
        }
        if settings.cameraEnabled {
            CameraCapture.shared.start()
        }
        if settings.appHistoryEnabled {
            AppHistoryTracker.shared.start()
        }
        if settings.fileAccessEnabled {
            FileAccessMonitor.shared.start()
        }
        if settings.clipboardEnabled {
            ClipboardMonitor.shared.start()
        }
        
        if settings.antiSleepGlobalEnabled {
            AntiSleepManager.shared.enableGlobal()
        }
        
        if !settings.antiSleepSchedules.isEmpty {
            AntiSleepManager.shared.startScheduleMonitoring()
        }
        
        if !settings.antiSleepAppRules.isEmpty {
            AntiSleepManager.shared.startAppMonitoring()
        }
        
        CleanupService.shared.startAutoCleanup()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        KeystrokeLogger.shared.stop()
        MouseTracker.shared.stop()
        ScreenshotCapture.shared.stop()
        CameraCapture.shared.stop()
        AppHistoryTracker.shared.stop()
        FileAccessMonitor.shared.stop()
        ClipboardMonitor.shared.stop()
        AntiSleepManager.shared.disableGlobal()
        CleanupService.shared.stopAutoCleanup()
    }
}
