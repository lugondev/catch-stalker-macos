import SwiftUI

struct SettingsView: View {
    @StateObject private var settings = SettingsManager.shared
    @StateObject private var launchAtLogin = LaunchAtLoginManager.shared
    @State private var showPasswordSheet = false
    @State private var showAddScheduleSheet = false
    @State private var showAddAppRuleSheet = false
    @State private var showExportSheet = false
    @State private var showResetConfirmation = false
    @State private var showCleanupConfirmation = false
    @State private var isResetting = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                generalSection
                intervalsSection
                storageSection
                antiSleepSection
                securitySection
                dataSection
            }
            .padding()
        }
        .navigationTitle("Settings")
        .sheet(isPresented: $showPasswordSheet) {
            PasswordSettingsSheet()
        }
        .sheet(isPresented: $showAddScheduleSheet) {
            AddScheduleSheet()
        }
        .sheet(isPresented: $showAddAppRuleSheet) {
            AddAppRuleSheet()
        }
        .sheet(isPresented: $showExportSheet) {
            ExportDataSheet()
        }
        .alert("Reset to Factory Settings", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset Everything", role: .destructive) {
                performFactoryReset()
            }
        } message: {
            Text("This will delete ALL data including:\n• All logs and captured data\n• Screenshots and camera images\n• Settings and preferences\n• Password protection\n\nThis action cannot be undone.")
        }
        .alert("Clean Up Storage", isPresented: $showCleanupConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clean Up", role: .destructive) {
                CleanupService.shared.performCleanup()
            }
        } message: {
            let days = settings.settings.autoDeleteDays
            if days > 0 {
                Text("This will delete all data older than \(days) days including database records, screenshots, and camera images.")
            } else {
                Text("Auto-delete is set to \"Never\". No data will be deleted.\n\nChange the auto-delete setting to enable cleanup.")
            }
        }
    }
    
    private var generalSection: some View {
        GroupBox("General") {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Launch at Login")
                    Spacer()
                    Toggle("", isOn: $launchAtLogin.isEnabled)
                        .labelsHidden()
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    private var intervalsSection: some View {
        GroupBox("Capture Intervals") {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Screenshot Interval")
                    Spacer()
                    Picker("", selection: $settings.settings.screenshotInterval) {
                        Text("5 seconds").tag(TimeInterval(5))
                        Text("10 seconds").tag(TimeInterval(10))
                        Text("30 seconds").tag(TimeInterval(30))
                        Text("1 minute").tag(TimeInterval(60))
                        Text("5 minutes").tag(TimeInterval(300))
                    }
                    .frame(width: 150)
                }
                
                HStack {
                    Text("Camera Interval")
                    Spacer()
                    Picker("", selection: $settings.settings.cameraInterval) {
                        Text("5 seconds").tag(TimeInterval(5))
                        Text("10 seconds").tag(TimeInterval(10))
                        Text("30 seconds").tag(TimeInterval(30))
                        Text("1 minute").tag(TimeInterval(60))
                        Text("5 minutes").tag(TimeInterval(300))
                    }
                    .frame(width: 150)
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    private var storageSection: some View {
        GroupBox("Storage") {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Screenshot Storage")
                    Spacer()
                    Text(settings.settings.screenshotStoragePath)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Button("Copy") {
                        copyToClipboard(settings.settings.screenshotStoragePath)
                    }
                    Button("Open") {
                        openFolder(settings.settings.screenshotStoragePath)
                    }
                    Button("Change") {
                        selectFolder { path in
                            settings.updateScreenshotPath(path)
                        }
                    }
                }
                
                HStack {
                    Text("Camera Storage")
                    Spacer()
                    Text(settings.settings.cameraStoragePath)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Button("Copy") {
                        copyToClipboard(settings.settings.cameraStoragePath)
                    }
                    Button("Open") {
                        openFolder(settings.settings.cameraStoragePath)
                    }
                    Button("Change") {
                        selectFolder { path in
                            settings.updateCameraPath(path)
                        }
                    }
                }
                
                HStack {
                    Text("Database")
                    Spacer()
                    Text(databasePath)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Button("Copy") {
                        copyToClipboard(databasePath)
                    }
                    Button("Open") {
                        openInFinder(databasePath)
                    }
                }
                
                Divider()
                
                HStack {
                    Text("Auto-delete after")
                    Spacer()
                    Picker("", selection: $settings.settings.autoDeleteDays) {
                        Text("Never").tag(0)
                        Text("7 days").tag(7)
                        Text("14 days").tag(14)
                        Text("30 days").tag(30)
                        Text("60 days").tag(60)
                        Text("90 days").tag(90)
                    }
                    .frame(width: 150)
                }
                
                HStack {
                    Spacer()
                    Button("Clean Up Now") {
                        showCleanupConfirmation = true
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    private var antiSleepSection: some View {
        GroupBox("Anti-Sleep") {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Schedules")
                        .font(.headline)
                    Spacer()
                    Button(action: { showAddScheduleSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
                
                if settings.settings.antiSleepSchedules.isEmpty {
                    Text("No schedules configured")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                } else {
                    ForEach(Array(settings.settings.antiSleepSchedules.enumerated()), id: \.element.id) { index, schedule in
                        HStack {
                            Toggle("", isOn: Binding(
                                get: { schedule.isEnabled },
                                set: { settings.settings.antiSleepSchedules[index].isEnabled = $0 }
                            ))
                            .labelsHidden()
                            
                            Text(schedule.name)
                            
                            Spacer()
                            
                            Text(formatScheduleTime(schedule))
                                .foregroundColor(.secondary)
                            
                            Button(action: { settings.removeAntiSleepSchedule(at: index) }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                Divider()
                
                HStack {
                    Text("App Rules")
                        .font(.headline)
                    Spacer()
                    Button(action: { showAddAppRuleSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
                
                if settings.settings.antiSleepAppRules.isEmpty {
                    Text("No app rules configured")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                } else {
                    ForEach(Array(settings.settings.antiSleepAppRules.enumerated()), id: \.element.id) { index, rule in
                        HStack {
                            Toggle("", isOn: Binding(
                                get: { rule.isEnabled },
                                set: { settings.settings.antiSleepAppRules[index].isEnabled = $0 }
                            ))
                            .labelsHidden()
                            
                            Text(rule.appName)
                            
                            Spacer()
                            
                            Text(rule.bundleIdentifier)
                                .foregroundColor(.secondary)
                                .font(.caption)
                            
                            Button(action: { settings.removeAntiSleepAppRule(at: index) }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    private var securitySection: some View {
        GroupBox("Security") {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Password Protection")
                    Spacer()
                    
                    if PasswordManager.shared.hasPassword() {
                        Text("Enabled")
                            .foregroundColor(.green)
                        Button("Change") {
                            showPasswordSheet = true
                        }
                    } else {
                        Text("Disabled")
                            .foregroundColor(.secondary)
                        Button("Enable") {
                            showPasswordSheet = true
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    private var dataSection: some View {
        GroupBox("Data") {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Export Data")
                    Spacer()
                    Button("Export...") {
                        showExportSheet = true
                    }
                    .buttonStyle(.bordered)
                }
                
                Divider()
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Reset to Factory Settings")
                        Text("Delete all data, logs, and settings")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("Reset...") {
                        showResetConfirmation = true
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .disabled(isResetting)
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    private func selectFolder(completion: @escaping (String) -> Void) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        
        if panel.runModal() == .OK, let url = panel.url {
            completion(url.path)
        }
    }
    
    private func openFolder(_ path: String) {
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.open(url)
    }
    
    private func openInFinder(_ path: String) {
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
    
    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
    
    private var databasePath: String {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("CatchStalker/catchstalker.db").path
    }
    
    private func formatScheduleTime(_ schedule: AntiSleepSchedule) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let start = formatter.string(from: schedule.startTime)
        let end = formatter.string(from: schedule.endTime)
        return "\(start) - \(end)"
    }
    
    private func performFactoryReset() {
        isResetting = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            KeystrokeLogger.shared.stop()
            MouseTracker.shared.stop()
            ScreenshotCapture.shared.stop()
            CameraCapture.shared.stop()
            AppHistoryTracker.shared.stop()
            FileAccessMonitor.shared.stop()
            ClipboardMonitor.shared.stop()
            AntiSleepManager.shared.disableGlobal()
            
            let fileManager = FileManager.default
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let catchStalkerDir = appSupport.appendingPathComponent("CatchStalker")
            
            try? fileManager.removeItem(at: catchStalkerDir)
            
            UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier ?? "")
            UserDefaults.standard.synchronize()
            
            DispatchQueue.main.async {
                isResetting = false
                NSApplication.shared.terminate(nil)
            }
        }
    }
}

struct PasswordSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var showError = false
    @State private var errorMessage = ""
    
    private var hasExistingPassword: Bool {
        PasswordManager.shared.hasPassword()
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text(hasExistingPassword ? "Change Password" : "Set Password")
                .font(.headline)
            
            if hasExistingPassword {
                SecureField("Current Password", text: $currentPassword)
                    .textFieldStyle(.roundedBorder)
            }
            
            SecureField("New Password", text: $newPassword)
                .textFieldStyle(.roundedBorder)
            
            SecureField("Confirm Password", text: $confirmPassword)
                .textFieldStyle(.roundedBorder)
            
            if showError {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                if hasExistingPassword {
                    Button("Remove Password") {
                        if PasswordManager.shared.verifyPassword(currentPassword) {
                            let _ = PasswordManager.shared.removePassword()
                            dismiss()
                        } else {
                            errorMessage = "Current password is incorrect"
                            showError = true
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
                
                Button("Save") {
                    savePassword()
                }
                .buttonStyle(.borderedProminent)
                .disabled(newPassword.isEmpty || newPassword != confirmPassword)
            }
        }
        .padding(30)
        .frame(width: 350)
    }
    
    private func savePassword() {
        if hasExistingPassword && !PasswordManager.shared.verifyPassword(currentPassword) {
            errorMessage = "Current password is incorrect"
            showError = true
            return
        }
        
        if newPassword != confirmPassword {
            errorMessage = "Passwords do not match"
            showError = true
            return
        }
        
        if PasswordManager.shared.setPassword(newPassword) {
            dismiss()
        } else {
            errorMessage = "Failed to save password"
            showError = true
        }
    }
}

struct AddScheduleSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var startTime = Date()
    @State private var endTime = Date()
    @State private var selectedWeekdays: Set<Weekday> = Set(Weekday.allCases)
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Add Schedule")
                .font(.headline)
            
            TextField("Schedule Name", text: $name)
                .textFieldStyle(.roundedBorder)
            
            HStack {
                DatePicker("Start", selection: $startTime, displayedComponents: .hourAndMinute)
                DatePicker("End", selection: $endTime, displayedComponents: .hourAndMinute)
            }
            
            HStack {
                ForEach(Weekday.allCases, id: \.self) { day in
                    Button(day.shortName) {
                        if selectedWeekdays.contains(day) {
                            selectedWeekdays.remove(day)
                        } else {
                            selectedWeekdays.insert(day)
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(selectedWeekdays.contains(day) ? .accentColor : .gray)
                }
            }
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Button("Add") {
                    AntiSleepManager.shared.addSchedule(
                        name: name.isEmpty ? "Schedule" : name,
                        startTime: startTime,
                        endTime: endTime,
                        weekdays: selectedWeekdays
                    )
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedWeekdays.isEmpty)
            }
        }
        .padding(30)
        .frame(width: 400)
    }
}

struct AddAppRuleSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var runningApps: [NSRunningApplication] = []
    @State private var selectedApp: NSRunningApplication?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Add App Rule")
                .font(.headline)
            
            Text("Select an app to prevent sleep when it's active:")
                .foregroundColor(.secondary)
            
            List(runningApps, id: \.processIdentifier, selection: $selectedApp) { app in
                HStack {
                    if let icon = app.icon {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 24, height: 24)
                    }
                    Text(app.localizedName ?? "Unknown")
                }
                .tag(app)
            }
            .frame(height: 200)
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Button("Add") {
                    if let app = selectedApp,
                       let bundleId = app.bundleIdentifier,
                       let name = app.localizedName {
                        AntiSleepManager.shared.addAppRule(bundleId: bundleId, appName: name)
                    }
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedApp == nil)
            }
        }
        .padding(30)
        .frame(width: 400)
        .onAppear {
            runningApps = NSWorkspace.shared.runningApplications
                .filter { $0.activationPolicy == .regular }
                .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
        }
    }
}

struct ExportDataSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var startDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    @State private var endDate = Date()
    @State private var selectedFormat: ExportService.ExportFormat = .json
    @State private var exportKeystrokes = true
    @State private var exportMouse = true
    @State private var exportScreenshots = true
    @State private var exportCamera = true
    @State private var exportAppHistory = true
    @State private var exportFileAccess = true
    @State private var exportClipboard = true
    @State private var isExporting = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Export Data")
                .font(.headline)
            
            GroupBox("Date Range") {
                VStack(spacing: 12) {
                    DatePicker("From:", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("To:", selection: $endDate, displayedComponents: [.date, .hourAndMinute])
                }
                .padding(.vertical, 8)
            }
            
            GroupBox("Data Types") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Keystrokes", isOn: $exportKeystrokes)
                    Toggle("Mouse Events", isOn: $exportMouse)
                    Toggle("Screenshots", isOn: $exportScreenshots)
                    Toggle("Camera Captures", isOn: $exportCamera)
                    Toggle("App History", isOn: $exportAppHistory)
                    Toggle("File Access", isOn: $exportFileAccess)
                    Toggle("Clipboard", isOn: $exportClipboard)
                }
                .padding(.vertical, 8)
            }
            
            GroupBox("Format") {
                Picker("Export Format", selection: $selectedFormat) {
                    Text("JSON").tag(ExportService.ExportFormat.json)
                    Text("CSV").tag(ExportService.ExportFormat.csv)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .padding(.vertical, 8)
            }
            
            if showError {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            if showSuccess {
                Text("Export completed successfully!")
                    .foregroundColor(.green)
                    .font(.caption)
            }
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Button("Export") {
                    performExport()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isExporting || !hasSelectedDataTypes)
            }
        }
        .padding(30)
        .frame(width: 400)
    }
    
    private var hasSelectedDataTypes: Bool {
        exportKeystrokes || exportMouse || exportScreenshots || exportCamera ||
        exportAppHistory || exportFileAccess || exportClipboard
    }
    
    private func performExport() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Select Export Folder"
        
        guard panel.runModal() == .OK, let url = panel.url else { return }
        
        isExporting = true
        showError = false
        showSuccess = false
        
        var types: Set<ExportService.ExportType> = []
        if exportKeystrokes { types.insert(.keystrokes) }
        if exportMouse { types.insert(.mouse) }
        if exportScreenshots { types.insert(.screenshots) }
        if exportCamera { types.insert(.camera) }
        if exportAppHistory { types.insert(.appHistory) }
        if exportFileAccess { types.insert(.fileAccess) }
        if exportClipboard { types.insert(.clipboard) }
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try ExportService.shared.exportData(
                    types: types,
                    format: selectedFormat,
                    from: startDate,
                    to: endDate,
                    destinationURL: url
                )
                DispatchQueue.main.async {
                    isExporting = false
                    showSuccess = true
                    NSWorkspace.shared.open(url)
                }
            } catch {
                DispatchQueue.main.async {
                    isExporting = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}
