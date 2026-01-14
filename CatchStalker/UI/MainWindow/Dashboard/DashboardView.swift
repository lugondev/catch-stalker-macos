import SwiftUI
import Charts

struct DashboardView: View {
    @State private var stats = DashboardStats()
    @State private var isLoading = true
    @State private var showCleanupConfirmation = false
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 20) {
                    statsGrid
                    
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: 20) {
                            activityChart
                            topAppsView
                        }
                        VStack(spacing: 16) {
                            activityChart
                            topAppsView
                        }
                    }
                    
                    storageInfo
                    
                    permissionsSection
                }
                .padding()
            }
            .opacity(isLoading ? 0.5 : 1.0)
            .disabled(isLoading)
            
            if isLoading {
                loadingOverlay
            }
        }
        .navigationTitle("Dashboard")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: loadStats) {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isLoading)
            }
        }
        .onAppear(perform: loadStats)
    }
    
    private var loadingOverlay: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading stats...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
    }
    
    private var statsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.adaptive(minimum: 140, maximum: 200), spacing: 16)
        ], spacing: 16) {
            StatCard(title: "Keystrokes", value: "\(stats.totalKeystrokes)", icon: "keyboard", color: .blue)
            StatCard(title: "Mouse Events", value: "\(stats.totalMouseEvents)", icon: "cursorarrow.motionlines", color: .green)
            StatCard(title: "Screenshots", value: "\(stats.totalScreenshots)", icon: "camera.viewfinder", color: .purple)
            StatCard(title: "Camera", value: "\(stats.totalCameraCaptures)", icon: "camera.fill", color: .orange)
            StatCard(title: "App Switches", value: "\(stats.totalAppSwitches)", icon: "app.badge", color: .pink)
            StatCard(title: "File Access", value: "\(stats.totalFileAccesses)", icon: "folder", color: .cyan)
            StatCard(title: "Clipboard", value: "\(stats.totalClipboardEvents)", icon: "doc.on.clipboard", color: .indigo)
            StatCard(title: "Storage", value: formatBytes(stats.storageUsed), icon: "internaldrive", color: .gray)
        }
    }
    
    private var activityChart: some View {
        GroupBox("Keystrokes Today") {
            if stats.keystrokesPerHour.isEmpty {
                EmptyStateView(
                    icon: "keyboard",
                    title: "No Activity Yet",
                    message: "Start typing to see your keystroke activity"
                )
                .frame(height: 150)
            } else {
                ActivityChartView(data: stats.keystrokesPerHour)
                    .frame(height: 150)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private var topAppsView: some View {
        GroupBox("Top Apps by Time Spent") {
            if stats.topApps.isEmpty {
                EmptyStateView(
                    icon: "app.badge",
                    title: "No Data Yet",
                    message: "App usage will appear here"
                )
                .frame(height: 150)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(stats.topApps.prefix(5), id: \.name) { app in
                        HStack {
                            Text(app.name)
                                .lineLimit(1)
                            Spacer()
                            Text(formatDuration(app.duration))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                }
                .frame(height: 150)
            }
        }
        .frame(minWidth: 200, maxWidth: 320)
    }
    
    private var storageInfo: some View {
        GroupBox("Storage Usage") {
            HStack(alignment: .top, spacing: 32) {
                VStack(alignment: .leading, spacing: 12) {
                    storageRow(
                        icon: "internaldrive",
                        label: "Total Used",
                        value: stats.storageUsed
                    )
                    
                    storageRow(
                        icon: "camera.viewfinder",
                        label: "Screenshots",
                        value: getDirectorySize(SettingsManager.shared.settings.screenshotStoragePath)
                    )
                    
                    storageRow(
                        icon: "camera.fill",
                        label: "Camera",
                        value: getDirectorySize(SettingsManager.shared.settings.cameraStoragePath)
                    )
                }
                
                Spacer()
                
                Button("Clean Up Now") {
                    showCleanupConfirmation = true
                }
                .buttonStyle(.bordered)
                .disabled(stats.storageUsed == 0)
            }
            .padding(.vertical, 8)
        }
        .frame(maxWidth: .infinity)
        .alert("Clean Up All Data", isPresented: $showCleanupConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete All", role: .destructive) {
                CleanupService.shared.deleteAllStorage()
                loadStats()
            }
        } message: {
            Text("This will permanently delete all screenshots, camera captures, and database records. This action cannot be undone.")
        }
    }
    
    private func storageRow(icon: String, label: String, value: Int64) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 20)
            Text("\(label):")
                .foregroundColor(.secondary)
            Text(formatBytes(value))
                .fontWeight(.medium)
        }
    }
    
    private var permissionsSection: some View {
        GroupBox("Permissions Status") {
            HStack(spacing: 20) {
                PermissionStatusView(
                    title: "Accessibility",
                    isGranted: PermissionsManager.shared.accessibilityGranted,
                    action: {
                        PermissionsManager.shared.resetRequestFlags()
                        PermissionsManager.shared.requestAccessibilityPermission()
                    }
                )
                
                PermissionStatusView(
                    title: "Screen Recording",
                    isGranted: PermissionsManager.shared.screenRecordingGranted,
                    action: {
                        PermissionsManager.shared.resetRequestFlags()
                        PermissionsManager.shared.requestScreenRecordingPermission()
                    }
                )
                
                PermissionStatusView(
                    title: "Camera",
                    isGranted: PermissionsManager.shared.cameraGranted,
                    action: {
                        PermissionsManager.shared.resetRequestFlags()
                        PermissionsManager.shared.requestCameraPermission()
                    }
                )
            }
            .padding(.vertical, 8)
        }
    }
    
    private func loadStats() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let dbStats = DatabaseManager.shared.getStats()
            var updatedStats = dbStats
            updatedStats.storageUsed = CleanupService.shared.getStorageUsage()
            
            DispatchQueue.main.async {
                self.stats = updatedStats
                self.isLoading = false
            }
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%d min", minutes)
        } else {
            return String(format: "%d sec", Int(seconds))
        }
    }
    
    private func getDirectorySize(_ path: String) -> Int64 {
        let fileManager = FileManager.default
        var size: Int64 = 0
        
        guard let enumerator = fileManager.enumerator(atPath: path) else { return 0 }
        
        while let file = enumerator.nextObject() as? String {
            let filePath = (path as NSString).appendingPathComponent(file)
            if let attributes = try? fileManager.attributesOfItem(atPath: filePath),
               let fileSize = attributes[.size] as? Int64,
               attributes[.type] as? FileAttributeType == .typeRegular {
                size += fileSize
            }
        }
        
        return size
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.gradient)
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    )
                
                Spacer()
            }
            
            Spacer()
            
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 120)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(isHovered ? 0.15 : 0.08), radius: isHovered ? 8 : 4, y: isHovered ? 4 : 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(isHovered ? 0.3 : 0.1), lineWidth: 1)
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeOut(duration: 0.2), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct PermissionStatusView: View {
    let title: String
    let isGranted: Bool
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: isGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.title)
                .foregroundColor(isGranted ? .green : .red)
            
            Text(title)
                .font(.caption)
            
            if !isGranted {
                Button("Grant", action: action)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct ActivityChartView: View {
    let data: [Int: Int]
    
    private var chartData: [HourlyData] {
        (0..<24).map { hour in
            HourlyData(hour: hour, count: data[hour] ?? 0)
        }
    }
    
    var body: some View {
        Chart(chartData) { item in
            BarMark(
                x: .value("Hour", item.hour),
                y: .value("Keystrokes", item.count)
            )
            .foregroundStyle(Color.accentColor.gradient)
            .cornerRadius(3)
        }
        .chartXAxis {
            AxisMarks(values: [0, 6, 12, 18, 23]) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                    .foregroundStyle(.tertiary)
                AxisValueLabel {
                    if let hour = value.as(Int.self) {
                        Text("\(hour)h")
                            .font(.caption2)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                    .foregroundStyle(.tertiary)
                AxisValueLabel()
                    .font(.caption2)
            }
        }
    }
}

private struct HourlyData: Identifiable {
    let id = UUID()
    let hour: Int
    let count: Int
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
