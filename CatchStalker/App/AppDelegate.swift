import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem!
    private var mainWindow: NSWindow?
    private var popover: NSPopover?
    private var eventMonitor: Any?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        startServices()
    }
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.image = NSImage(named: "MenuBarIcon")
            button.image?.isTemplate = true
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
            closePopover()
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.becomeKey()
            startEventMonitor()
        }
    }
    
    private func closePopover() {
        popover?.performClose(nil)
        stopEventMonitor()
    }
    
    private func startEventMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            if self?.popover?.isShown == true {
                self?.closePopover()
            }
        }
    }
    
    private func stopEventMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
    
    private func showMainWindow() {
        closePopover()
        
        if mainWindow == nil {
            let contentView = MainWindowView()
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 1000, height: 700),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.center()
            window.title = "CatchStalker"
            window.titlebarAppearsTransparent = true
            window.toolbarStyle = .unified
            window.contentView = NSHostingView(rootView: contentView)
            window.isReleasedWhenClosed = false
            window.delegate = self
            mainWindow = window
        }
        
        NSApp.setActivationPolicy(.regular)
        
        mainWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func startServices() {
        PermissionsManager.shared.checkAllPermissions()
        
        let settings = SettingsManager.shared.settings
        
        if settings.globalMonitoringEnabled {
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
        
        if settings.appProtectionEnabled {
            AppProtector.shared.start()
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
        AppProtector.shared.stop()
        CleanupService.shared.stopAutoCleanup()
    }
    
    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
