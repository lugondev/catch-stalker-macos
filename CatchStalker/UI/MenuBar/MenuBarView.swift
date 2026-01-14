import SwiftUI

struct MenuBarView: View {
    @StateObject private var settings = SettingsManager.shared
    @StateObject private var permissions = PermissionsManager.shared
    @StateObject private var antiSleep = AntiSleepManager.shared
    @StateObject private var appProtector = AppProtector.shared
    
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
        VStack(alignment: .leading, spacing: Spacing.md) {
            headerSection
            
            Divider()
            
            monitoringToggles
            
            Divider()
            
            antiSleepSection
            
            Divider()
            
            appProtectionSection
            
            Divider()
            
            footerButtons
        }
        .padding()
        .frame(width: 280)
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
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
                    .foregroundStyle(settings.settings.globalMonitoringEnabled ? StatusColor.active : StatusColor.inactive)
                    .font(.system(size: IconSize.sm))
                
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
            .padding(.horizontal, Spacing.xs)
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
        HStack(spacing: Spacing.xs) {
            StatusIndicator(isActive: isAnyModuleRunning)
            
            Text(isAnyModuleRunning ? "Active" : "Idle")
                .font(.caption)
                .foregroundStyle(.secondary)
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
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Monitoring")
                .font(.caption)
                .foregroundStyle(.secondary)
            
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
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Anti-Sleep")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack {
                Image(systemName: "moon.zzz.fill")
                    .foregroundStyle(antiSleep.isEnabled ? StatusColor.warning : StatusColor.inactive)
                
                Text("Prevent Sleep")
                
                Spacer()
                
                if antiSleep.isEnabled && antiSleep.remainingTime > 0 {
                    Text(antiSleep.formattedRemainingTime)
                        .font(.caption)
                        .foregroundStyle(StatusColor.warning)
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
                        .foregroundStyle(.secondary)
                    
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
                        .foregroundStyle(StatusColor.info)
                    Text("Active by schedule")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            if antiSleep.isActiveByApp {
                HStack {
                    Image(systemName: "app.fill")
                        .foregroundStyle(.purple)
                    Text("Active by app rule")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    private var appProtectionSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("App Protection")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack {
                Image(systemName: "shield.fill")
                    .foregroundStyle(appProtector.isRunning ? StatusColor.active : StatusColor.inactive)
                
                Text("Block Protected Apps")
                
                Spacer()
                
                Toggle("", isOn: Binding(
                    get: { settings.settings.appProtectionEnabled },
                    set: { newValue in
                        settings.settings.appProtectionEnabled = newValue
                        if newValue {
                            AppProtector.shared.start()
                        } else {
                            AppProtector.shared.stop()
                        }
                        settings.saveImmediately()
                    }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
                .disabled(settings.settings.redirectAppConfig.isEmpty)
            }
            
            if settings.settings.appProtectionEnabled {
                if appProtector.blockCount > 0 {
                    HStack {
                        Image(systemName: "hand.raised.fill")
                            .foregroundStyle(StatusColor.warning)
                        Text("Blocked: \(appProtector.blockCount)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let lastApp = appProtector.lastBlockedApp {
                            Text("(\(lastApp))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                
                if !settings.settings.protectedAppRules.isEmpty {
                    HStack {
                        Image(systemName: "list.bullet.rectangle")
                            .foregroundStyle(StatusColor.info)
                        Text("\(settings.settings.protectedAppRules.count) app(s) protected")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            if settings.settings.redirectAppConfig.isEmpty {
                Text("Configure redirect app in Settings")
                    .font(.caption2)
                    .foregroundStyle(StatusColor.warning)
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
            .tint(StatusColor.error)
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
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            HStack {
                Image(systemName: icon)
                    .frame(width: IconSize.md)
                    .foregroundStyle(isRunning ? StatusColor.active : (isPermissionGranted ? StatusColor.inactive : StatusColor.error))
                
                Text(title)
                    .font(.callout)
                
                Spacer()
                
                if !isPermissionGranted {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(StatusColor.warning)
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
                    .font(.caption2)
                    .foregroundStyle(StatusColor.warning)
                    .padding(.leading, IconSize.lg + Spacing.xs)
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
