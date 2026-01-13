import SwiftUI

struct DashboardView: View {
    @State private var stats = DashboardStats()
    @State private var isLoading = true
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                statsGrid
                
                HStack(spacing: 20) {
                    activityChart
                    storageInfo
                }
                
                permissionsSection
            }
            .padding()
        }
        .navigationTitle("Dashboard")
        .onAppear(perform: loadStats)
    }
    
    private var statsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
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
        GroupBox("Activity Over Time") {
            if stats.keystrokesPerHour.isEmpty {
                Text("No activity data yet")
                    .foregroundColor(.secondary)
                    .frame(height: 150)
            } else {
                ActivityChartView(data: stats.keystrokesPerHour)
                    .frame(height: 150)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private var storageInfo: some View {
        GroupBox("Storage Usage") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "internaldrive")
                    Text("Total Used: \(formatBytes(stats.storageUsed))")
                }
                
                HStack {
                    Image(systemName: "camera.viewfinder")
                    Text("Screenshots: \(formatBytes(getDirectorySize(SettingsManager.shared.settings.screenshotStoragePath)))")
                }
                
                HStack {
                    Image(systemName: "camera.fill")
                    Text("Camera: \(formatBytes(getDirectorySize(SettingsManager.shared.settings.cameraStoragePath)))")
                }
                
                Spacer()
                
                Button("Clean Up Now") {
                    CleanupService.shared.performCleanup()
                    loadStats()
                }
                .buttonStyle(.bordered)
            }
            .frame(height: 150)
        }
        .frame(width: 250)
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
    
    var body: some View {
        GroupBox {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(value)
                    .font(.title)
                    .fontWeight(.bold)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
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
    
    var body: some View {
        GeometryReader { geometry in
            let maxValue = data.values.max() ?? 1
            let barWidth = geometry.size.width / 24
            
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(0..<24, id: \.self) { hour in
                    let value = data[hour] ?? 0
                    let height = maxValue > 0 ? CGFloat(value) / CGFloat(maxValue) * geometry.size.height : 0
                    
                    VStack {
                        Rectangle()
                            .fill(Color.accentColor.opacity(0.8))
                            .frame(width: barWidth - 4, height: max(height, 2))
                        
                        if hour % 6 == 0 {
                            Text("\(hour)")
                                .font(.system(size: 8))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }
}
