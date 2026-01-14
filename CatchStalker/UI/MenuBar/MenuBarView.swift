import SwiftUI

struct MenuBarView: View {
    @StateObject private var settings = SettingsManager.shared
    @StateObject private var permissions = PermissionsManager.shared
    @StateObject private var antiSleep = AntiSleepManager.shared
    
    @StateObject private var keystrokeLogger = KeystrokeLogger.shared
    @StateObject private var mouseTracker = MouseTracker.shared
    @StateObject private var screenshotCapture = ScreenshotCapture.shared
    @StateObject private var cameraCapture = CameraCapture.shared
    @StateObject private var appHistoryTracker = AppHistoryTracker.shared
    @StateObject private var fileAccessMonitor = FileAccessMonitor.shared
    @StateObject private var clipboardMonitor = ClipboardMonitor.shared
    
    let openMainWindow: () -> Void
    let quitApp: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerSection
            
            Divider()
            
            monitoringToggles
            
            Divider()
            
            antiSleepSection
            
            Divider()
            
            footerButtons
        }
        .padding()
        .frame(width: 280)
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                
                Text("CatchStalker")
                    .font(.headline)
                
                Spacer()
                
                statusIndicator
            }
            
            HStack {
                Image(systemName: settings.settings.globalMonitoringEnabled ? "power.circle.fill" : "power.circle")
                    .foregroundColor(settings.settings.globalMonitoringEnabled ? .green : .gray)
                    .font(.system(size: 14))
                
                Text("Global Monitoring")
                    .font(.callout)
                
                Spacer()
                
                Toggle("", isOn: $settings.settings.globalMonitoringEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .onChange(of: settings.settings.globalMonitoringEnabled) { newValue in
                        handleGlobalToggle(enabled: newValue)
                    }
            }
            .padding(.horizontal, 4)
        }
    }
    
    private func handleGlobalToggle(enabled: Bool) {
        if enabled {
            if settings.settings.keystrokeEnabled { KeystrokeLogger.shared.start() }
            if settings.settings.mouseEnabled { MouseTracker.shared.start() }
            if settings.settings.screenshotEnabled { ScreenshotCapture.shared.start() }
            if settings.settings.cameraEnabled { CameraCapture.shared.start() }
            if settings.settings.appHistoryEnabled { AppHistoryTracker.shared.start() }
            if settings.settings.fileAccessEnabled { FileAccessMonitor.shared.start() }
            if settings.settings.clipboardEnabled { ClipboardMonitor.shared.start() }
        } else {
            KeystrokeLogger.shared.stop()
            MouseTracker.shared.stop()
            ScreenshotCapture.shared.stop()
            CameraCapture.shared.stop()
            AppHistoryTracker.shared.stop()
            FileAccessMonitor.shared.stop()
            ClipboardMonitor.shared.stop()
        }
        settings.saveImmediately()
    }
    
    private var statusIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isAnyModuleRunning ? Color.green : Color.gray)
                .frame(width: 8, height: 8)
            
            Text(isAnyModuleRunning ? "Active" : "Idle")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var isAnyModuleRunning: Bool {
        keystrokeLogger.isRunning ||
        mouseTracker.isRunning ||
        screenshotCapture.isRunning ||
        cameraCapture.isRunning ||
        appHistoryTracker.isRunning ||
        fileAccessMonitor.isRunning ||
        clipboardMonitor.isRunning
    }
    
    private var monitoringToggles: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Monitoring")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Group {
                ModuleToggle(
                    icon: "keyboard",
                    title: "Keystroke",
                    isEnabled: $settings.settings.keystrokeEnabled,
                    isRunning: keystrokeLogger.isRunning,
                    isPermissionGranted: permissions.accessibilityGranted,
                    permissionName: "Accessibility",
                    isGlobalEnabled: settings.settings.globalMonitoringEnabled
                ) { enabled in
                    if enabled { KeystrokeLogger.shared.start() }
                    else { KeystrokeLogger.shared.stop() }
                    settings.saveImmediately()
                }
                
                ModuleToggle(
                    icon: "cursorarrow.motionlines",
                    title: "Mouse",
                    isEnabled: $settings.settings.mouseEnabled,
                    isRunning: mouseTracker.isRunning,
                    isPermissionGranted: permissions.accessibilityGranted,
                    permissionName: "Accessibility",
                    isGlobalEnabled: settings.settings.globalMonitoringEnabled
                ) { enabled in
                    if enabled { MouseTracker.shared.start() }
                    else { MouseTracker.shared.stop() }
                    settings.saveImmediately()
                }
                
                ModuleToggle(
                    icon: "camera.viewfinder",
                    title: "Screenshot",
                    isEnabled: $settings.settings.screenshotEnabled,
                    isRunning: screenshotCapture.isRunning,
                    isPermissionGranted: permissions.screenRecordingGranted,
                    permissionName: "Screen Recording",
                    isGlobalEnabled: settings.settings.globalMonitoringEnabled
                ) { enabled in
                    if enabled { ScreenshotCapture.shared.start() }
                    else { ScreenshotCapture.shared.stop() }
                    settings.saveImmediately()
                }
                
                ModuleToggle(
                    icon: "camera.fill",
                    title: "Camera",
                    isEnabled: $settings.settings.cameraEnabled,
                    isRunning: cameraCapture.isRunning,
                    isPermissionGranted: permissions.cameraGranted,
                    permissionName: "Camera",
                    isGlobalEnabled: settings.settings.globalMonitoringEnabled
                ) { enabled in
                    if enabled { CameraCapture.shared.start() }
                    else { CameraCapture.shared.stop() }
                    settings.saveImmediately()
                }
                
                ModuleToggle(
                    icon: "app.badge",
                    title: "App History",
                    isEnabled: $settings.settings.appHistoryEnabled,
                    isRunning: appHistoryTracker.isRunning,
                    isPermissionGranted: true,
                    permissionName: nil,
                    isGlobalEnabled: settings.settings.globalMonitoringEnabled
                ) { enabled in
                    if enabled { AppHistoryTracker.shared.start() }
                    else { AppHistoryTracker.shared.stop() }
                    settings.saveImmediately()
                }
                
                ModuleToggle(
                    icon: "folder",
                    title: "File Access",
                    isEnabled: $settings.settings.fileAccessEnabled,
                    isRunning: fileAccessMonitor.isRunning,
                    isPermissionGranted: true,
                    permissionName: nil,
                    isGlobalEnabled: settings.settings.globalMonitoringEnabled
                ) { enabled in
                    if enabled { FileAccessMonitor.shared.start() }
                    else { FileAccessMonitor.shared.stop() }
                    settings.saveImmediately()
                }
                
                ModuleToggle(
                    icon: "doc.on.clipboard",
                    title: "Clipboard",
                    isEnabled: $settings.settings.clipboardEnabled,
                    isRunning: clipboardMonitor.isRunning,
                    isPermissionGranted: true,
                    permissionName: nil,
                    isGlobalEnabled: settings.settings.globalMonitoringEnabled
                ) { enabled in
                    if enabled { ClipboardMonitor.shared.start() }
                    else { ClipboardMonitor.shared.stop() }
                    settings.saveImmediately()
                }
            }
            .disabled(!settings.settings.globalMonitoringEnabled)
            .opacity(settings.settings.globalMonitoringEnabled ? 1.0 : 0.5)
        }
    }
    
    private var antiSleepSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Anti-Sleep")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                Image(systemName: "moon.zzz.fill")
                    .foregroundColor(antiSleep.isEnabled ? .orange : .gray)
                
                Text("Prevent Sleep")
                
                Spacer()
                
                if antiSleep.isEnabled && antiSleep.remainingTime > 0 {
                    Text(antiSleep.formattedRemainingTime)
                        .font(.caption)
                        .foregroundColor(.orange)
                        .monospacedDigit()
                }
                
                Toggle("", isOn: Binding(
                    get: { antiSleep.isEnabled },
                    set: { newValue in
                        if newValue {
                            antiSleep.enableGlobal()
                        } else {
                            antiSleep.disableGlobal()
                        }
                    }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
            }
            
            if antiSleep.isEnabled {
                HStack {
                    Text("Duration:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Picker("", selection: Binding(
                        get: { antiSleep.selectedDuration },
                        set: { antiSleep.enableWithDuration($0) }
                    )) {
                        ForEach(AntiSleepDuration.allCases, id: \.self) { duration in
                            Text(duration.displayName).tag(duration)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            
            if antiSleep.isActiveBySchedule {
                HStack {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundColor(.blue)
                    Text("Active by schedule")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if antiSleep.isActiveByApp {
                HStack {
                    Image(systemName: "app.fill")
                        .foregroundColor(.purple)
                    Text("Active by app rule")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var footerButtons: some View {
        HStack {
            Button(action: openMainWindow) {
                HStack {
                    Image(systemName: "macwindow")
                    Text("Open Dashboard")
                }
            }
            .buttonStyle(.bordered)
            
            Spacer()
            
            Button(action: quitApp) {
                Image(systemName: "power")
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
    }
}

struct ModuleToggle: View {
    let icon: String
    let title: String
    @Binding var isEnabled: Bool
    let isRunning: Bool
    let isPermissionGranted: Bool
    let permissionName: String?
    var isGlobalEnabled: Bool = true
    let onToggle: (Bool) -> Void
    
    @StateObject private var permissions = PermissionsManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 20)
                    .foregroundColor(isRunning ? .green : (isPermissionGranted ? .gray : .red))
                
                Text(title)
                    .font(.callout)
                
                Spacer()
                
                if !isPermissionGranted {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                }
                
                Toggle("", isOn: Binding(
                    get: { isEnabled && isPermissionGranted && isGlobalEnabled },
                    set: { newValue in
                        guard isGlobalEnabled else { return }
                        if isPermissionGranted {
                            isEnabled = newValue
                            onToggle(newValue)
                        } else if newValue {
                            requestPermission()
                        }
                    }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
                .controlSize(.small)
            }
            
            if !isPermissionGranted, let permission = permissionName {
                Text("Requires \(permission) permission")
                    .font(.system(size: 9))
                    .foregroundColor(.orange)
                    .padding(.leading, 24)
            }
        }
    }
    
    private func requestPermission() {
        guard let permissionName = permissionName else { return }
        
        permissions.resetRequestFlags()
        
        switch permissionName {
        case "Accessibility":
            permissions.requestAccessibilityPermission()
        case "Screen Recording":
            permissions.requestScreenRecordingPermission()
        case "Camera":
            permissions.requestCameraPermission()
        default:
            break
        }
    }
}
