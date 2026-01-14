import SwiftUI

struct LogsView: View {
    @State private var selectedLogType: LogType = .keystrokes
    @State private var searchText = ""
    @State private var selectedDateRange: DateRangeOption = .last24Hours
    @State private var customStartDate = Calendar.current.startOfDay(for: Date())
    @State private var customEndDate = Date()
    @State private var showCustomDatePicker = false
    @State private var refreshTrigger = UUID()
    @State private var selectedAppFilter: String = "All Apps"
    @State private var availableApps: [String] = ["All Apps"]
    
    enum DateRangeOption: String, CaseIterable {
        case last24Hours = "Last 24 Hours"
        case last7Days = "Last 7 Days"
        case last30Days = "Last 30 Days"
        case allTime = "All Time"
        case custom = "Custom"
        
        var dateRange: (start: Date?, end: Date?) {
            let now = Date()
            
            switch self {
            case .last24Hours:
                let start = Calendar.current.date(byAdding: .hour, value: -24, to: now)!
                return (start, now)
            case .last7Days:
                let start = Calendar.current.date(byAdding: .day, value: -7, to: now)!
                return (start, now)
            case .last30Days:
                let start = Calendar.current.date(byAdding: .day, value: -30, to: now)!
                return (start, now)
            case .allTime:
                return (nil, nil)
            case .custom:
                return (nil, nil)
            }
        }
    }
    
    private var effectiveStartDate: Date? {
        if selectedDateRange == .custom {
            return Calendar.current.startOfDay(for: customStartDate)
        }
        return selectedDateRange.dateRange.start
    }
    
    private var effectiveEndDate: Date? {
        if selectedDateRange == .custom {
            return Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: customEndDate)
        }
        return selectedDateRange.dateRange.end
    }
    
    enum LogType: String, CaseIterable {
        case keystrokes = "Keystrokes"
        case mouse = "Mouse"
        case screenshots = "Screenshots"
        case camera = "Camera"
        case appHistory = "App History"
        case fileAccess = "File Access"
        case clipboard = "Clipboard"
        
        var icon: String {
            switch self {
            case .keystrokes: return "keyboard"
            case .mouse: return "cursorarrow.motionlines"
            case .screenshots: return "camera.viewfinder"
            case .camera: return "camera.fill"
            case .appHistory: return "app.badge"
            case .fileAccess: return "folder"
            case .clipboard: return "doc.on.clipboard"
            }
        }
    }
    
    var body: some View {
        HSplitView {
            logTypeSidebar
                .frame(minWidth: 150, maxWidth: 200)
            
            VStack(spacing: 0) {
                filterBar
                Divider()
                logContent
            }
        }
        .navigationTitle("Logs")
    }
    
    private var logTypeSidebar: some View {
        List(LogType.allCases, id: \.self, selection: $selectedLogType) { type in
            Label(type.rawValue, systemImage: type.icon)
        }
        .listStyle(.sidebar)
    }
    
    private var filterBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            
            TextField("Search...", text: $searchText)
                .textFieldStyle(.plain)
            
            Divider()
                .frame(height: 20)
            
            if selectedLogType == .keystrokes || selectedLogType == .mouse || selectedLogType == .clipboard {
                Picker("App", selection: $selectedAppFilter) {
                    ForEach(availableApps, id: \.self) { app in
                        Text(app).tag(app)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 140)
                
                Divider()
                    .frame(height: 20)
            }
            
            Picker("Date Range", selection: $selectedDateRange) {
                ForEach(DateRangeOption.allCases, id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 130)
            
            if selectedDateRange == .custom {
                DatePicker("", selection: $customStartDate, displayedComponents: .date)
                    .labelsHidden()
                    .frame(width: 100)
                
                Text("to")
                    .foregroundStyle(.secondary)
                
                DatePicker("", selection: $customEndDate, displayedComponents: .date)
                    .labelsHidden()
                    .frame(width: 100)
            }
            
            Button(action: { 
                refreshTrigger = UUID()
                loadAvailableApps()
            }) {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .onAppear {
            loadAvailableApps()
        }
        .onChange(of: selectedLogType) { _ in
            selectedAppFilter = "All Apps"
            loadAvailableApps()
        }
    }
    
    private func loadAvailableApps() {
        let apps = DatabaseManager.shared.fetchDistinctApps()
        availableApps = ["All Apps"] + apps.sorted()
    }
    
    @ViewBuilder
    private var logContent: some View {
        let appFilter = selectedAppFilter == "All Apps" ? nil : selectedAppFilter
        
        switch selectedLogType {
        case .keystrokes:
            KeystrokesLogView(searchText: searchText, startDate: effectiveStartDate, endDate: effectiveEndDate, appFilter: appFilter)
                .id(refreshTrigger)
        case .mouse:
            MouseLogView(searchText: searchText, startDate: effectiveStartDate, endDate: effectiveEndDate, appFilter: appFilter)
                .id(refreshTrigger)
        case .screenshots:
            ScreenshotsLogView(searchText: searchText, startDate: effectiveStartDate, endDate: effectiveEndDate)
                .id(refreshTrigger)
        case .camera:
            CameraLogView(searchText: searchText, startDate: effectiveStartDate, endDate: effectiveEndDate)
                .id(refreshTrigger)
        case .appHistory:
            AppHistoryLogView(searchText: searchText, startDate: effectiveStartDate, endDate: effectiveEndDate)
                .id(refreshTrigger)
        case .fileAccess:
            FileAccessLogView(searchText: searchText, startDate: effectiveStartDate, endDate: effectiveEndDate)
                .id(refreshTrigger)
        case .clipboard:
            ClipboardLogView(searchText: searchText, startDate: effectiveStartDate, endDate: effectiveEndDate, appFilter: appFilter)
                .id(refreshTrigger)
        }
    }
}

struct KeystrokesLogView: View {
    let searchText: String
    let startDate: Date?
    let endDate: Date?
    var appFilter: String? = nil
    
    @State private var events: [KeystrokeEvent] = []
    @State private var currentPage = 0
    @State private var hasMoreData = true
    private let pageSize = 100
    
    var body: some View {
        VStack(spacing: 0) {
            Table(filteredEvents) {
                TableColumn("Time") { (event: KeystrokeEvent) in
                    Text(formatDate(event.timestamp))
                        .font(.caption)
                }
                .width(min: 150, ideal: 180)
                
                TableColumn("Key") { (event: KeystrokeEvent) in
                    Text(event.characters ?? "Key \(event.keyCode)")
                }
                .width(min: 80, ideal: 100)
                
                TableColumn("Modifiers") { (event: KeystrokeEvent) in
                    Text(event.modifiers.description)
                        .foregroundStyle(.secondary)
                }
                .width(min: 80, ideal: 100)
                
                TableColumn("App") { (event: KeystrokeEvent) in
                    Text(event.activeApp ?? "-")
                        .foregroundStyle(.secondary)
                }
            }
            
            paginationControls
        }
        .onAppear(perform: loadEvents)
        .onChange(of: startDate) { _ in resetAndLoad() }
        .onChange(of: endDate) { _ in resetAndLoad() }
    }
    
    private var paginationControls: some View {
        HStack {
            Text("\(filteredEvents.count) items")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Button(action: previousPage) {
                Image(systemName: "chevron.left")
            }
            .disabled(currentPage == 0)
            .buttonStyle(.bordered)
            
            Text("Page \(currentPage + 1)")
                .font(.caption)
            
            Button(action: nextPage) {
                Image(systemName: "chevron.right")
            }
            .disabled(!hasMoreData)
            .buttonStyle(.bordered)
        }
        .padding(.horizontal)
        .padding(.vertical, Spacing.sm)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private var filteredEvents: [KeystrokeEvent] {
        var result = events
        
        if let appFilter = appFilter {
            result = result.filter { $0.activeApp == appFilter }
        }
        
        if !searchText.isEmpty {
            result = result.filter { event in
                event.characters?.localizedCaseInsensitiveContains(searchText) == true ||
                event.activeApp?.localizedCaseInsensitiveContains(searchText) == true
            }
        }
        
        return result
    }
    
    private func resetAndLoad() {
        currentPage = 0
        loadEvents()
    }
    
    private func loadEvents() {
        let offset = currentPage * pageSize
        events = DatabaseManager.shared.fetchKeystrokes(from: startDate, to: endDate, limit: pageSize, offset: offset)
        hasMoreData = events.count == pageSize
    }
    
    private func previousPage() {
        if currentPage > 0 {
            currentPage -= 1
            loadEvents()
        }
    }
    
    private func nextPage() {
        if hasMoreData {
            currentPage += 1
            loadEvents()
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

struct MouseLogView: View {
    let searchText: String
    let startDate: Date?
    let endDate: Date?
    var appFilter: String? = nil
    
    @State private var events: [MouseEvent] = []
    @State private var currentPage = 0
    @State private var hasMoreData = true
    private let pageSize = 100
    
    private var filteredEvents: [MouseEvent] {
        var result = events
        
        if let appFilter = appFilter {
            result = result.filter { $0.activeApp == appFilter }
        }
        
        return result
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Table(filteredEvents) {
                TableColumn("Time") { (event: MouseEvent) in
                    Text(formatDate(event.timestamp))
                        .font(.caption)
                }
                .width(min: 150, ideal: 180)
                
                TableColumn("Type") { (event: MouseEvent) in
                    Text(event.eventType.rawValue)
                }
                .width(min: 80, ideal: 100)
                
                TableColumn("Position") { (event: MouseEvent) in
                    Text("(\(Int(event.x)), \(Int(event.y)))")
                        .font(.caption.monospaced())
                }
                .width(min: 100, ideal: 120)
                
                TableColumn("App") { (event: MouseEvent) in
                    Text(event.activeApp ?? "-")
                        .foregroundStyle(.secondary)
                }
            }
            
            paginationControls
        }
        .onAppear(perform: loadEvents)
        .onChange(of: startDate) { _ in resetAndLoad() }
        .onChange(of: endDate) { _ in resetAndLoad() }
    }
    
    private var paginationControls: some View {
        HStack {
            Text("\(filteredEvents.count) items")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button(action: previousPage) {
                Image(systemName: "chevron.left")
            }
            .disabled(currentPage == 0)
            .buttonStyle(.bordered)
            Text("Page \(currentPage + 1)")
                .font(.caption)
            Button(action: nextPage) {
                Image(systemName: "chevron.right")
            }
            .disabled(!hasMoreData)
            .buttonStyle(.bordered)
        }
        .padding(.horizontal)
        .padding(.vertical, Spacing.sm)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private func resetAndLoad() {
        currentPage = 0
        loadEvents()
    }
    
    private func loadEvents() {
        let offset = currentPage * pageSize
        events = DatabaseManager.shared.fetchMouseEvents(from: startDate, to: endDate, limit: pageSize, offset: offset)
        hasMoreData = events.count == pageSize
    }
    
    private func previousPage() {
        if currentPage > 0 { currentPage -= 1; loadEvents() }
    }
    
    private func nextPage() {
        if hasMoreData { currentPage += 1; loadEvents() }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

struct ScreenshotsLogView: View {
    let searchText: String
    let startDate: Date?
    let endDate: Date?
    
    @State private var events: [ScreenshotEvent] = []
    @State private var selectedEvent: ScreenshotEvent?
    @State private var currentPage = 0
    @State private var hasMoreData = true
    private let pageSize = 50
    
    var body: some View {
        VStack(spacing: 0) {
            HSplitView {
                List(events, id: \.id, selection: $selectedEvent) { event in
                    VStack(alignment: .leading) {
                        Text(formatDate(event.timestamp))
                            .font(.caption)
                        Text("\(event.width) x \(event.height)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .tag(event)
                }
                .frame(minWidth: 200)
                
                if let event = selectedEvent {
                    VStack {
                        if let image = NSImage(contentsOfFile: event.filePath) {
                            Image(nsImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } else {
                            Text("Image not found")
                                .foregroundStyle(.secondary)
                        }
                        
                        Text(event.filePath)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .padding()
                } else {
                    Text("Select a screenshot to preview")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            
            paginationControls
        }
        .onAppear(perform: loadEvents)
        .onChange(of: startDate) { _ in resetAndLoad() }
        .onChange(of: endDate) { _ in resetAndLoad() }
    }
    
    private var paginationControls: some View {
        HStack {
            Text("\(events.count) items")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button(action: previousPage) { Image(systemName: "chevron.left") }
                .disabled(currentPage == 0)
                .buttonStyle(.bordered)
            Text("Page \(currentPage + 1)").font(.caption)
            Button(action: nextPage) { Image(systemName: "chevron.right") }
                .disabled(!hasMoreData)
                .buttonStyle(.bordered)
        }
        .padding(.horizontal)
        .padding(.vertical, Spacing.sm)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private func resetAndLoad() {
        currentPage = 0
        selectedEvent = nil
        loadEvents()
    }
    
    private func loadEvents() {
        let offset = currentPage * pageSize
        events = DatabaseManager.shared.fetchScreenshots(from: startDate, to: endDate, limit: pageSize, offset: offset)
        hasMoreData = events.count == pageSize
    }
    
    private func previousPage() { if currentPage > 0 { currentPage -= 1; loadEvents() } }
    private func nextPage() { if hasMoreData { currentPage += 1; loadEvents() } }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

struct CameraLogView: View {
    let searchText: String
    let startDate: Date?
    let endDate: Date?
    
    @State private var events: [CameraCaptureEvent] = []
    @State private var selectedEvent: CameraCaptureEvent?
    @State private var currentPage = 0
    @State private var hasMoreData = true
    private let pageSize = 50
    
    var body: some View {
        VStack(spacing: 0) {
            HSplitView {
                List(events, id: \.id, selection: $selectedEvent) { event in
                    VStack(alignment: .leading) {
                        Text(formatDate(event.timestamp))
                            .font(.caption)
                        Text(event.deviceName ?? "Unknown camera")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .tag(event)
                }
                .frame(minWidth: 200)
                
                if let event = selectedEvent {
                    VStack {
                        if let image = NSImage(contentsOfFile: event.filePath) {
                            Image(nsImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } else {
                            Text("Image not found")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                } else {
                    Text("Select a capture to preview")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            
            paginationControls
        }
        .onAppear(perform: loadEvents)
        .onChange(of: startDate) { _ in resetAndLoad() }
        .onChange(of: endDate) { _ in resetAndLoad() }
    }
    
    private var paginationControls: some View {
        HStack {
            Text("\(events.count) items")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button(action: previousPage) { Image(systemName: "chevron.left") }
                .disabled(currentPage == 0)
                .buttonStyle(.bordered)
            Text("Page \(currentPage + 1)").font(.caption)
            Button(action: nextPage) { Image(systemName: "chevron.right") }
                .disabled(!hasMoreData)
                .buttonStyle(.bordered)
        }
        .padding(.horizontal)
        .padding(.vertical, Spacing.sm)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private func resetAndLoad() {
        currentPage = 0
        selectedEvent = nil
        loadEvents()
    }
    
    private func loadEvents() {
        let offset = currentPage * pageSize
        events = DatabaseManager.shared.fetchCameraCaptures(from: startDate, to: endDate, limit: pageSize, offset: offset)
        hasMoreData = events.count == pageSize
    }
    
    private func previousPage() { if currentPage > 0 { currentPage -= 1; loadEvents() } }
    private func nextPage() { if hasMoreData { currentPage += 1; loadEvents() } }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

struct AppHistoryLogView: View {
    let searchText: String
    let startDate: Date?
    let endDate: Date?
    
    @State private var events: [AppHistoryEvent] = []
    @State private var currentPage = 0
    @State private var hasMoreData = true
    private let pageSize = 100
    
    var body: some View {
        VStack(spacing: 0) {
            Table(filteredEvents) {
                TableColumn("Time") { (event: AppHistoryEvent) in
                    Text(formatDate(event.timestamp))
                        .font(.caption)
                }
                .width(min: 150, ideal: 180)
                
                TableColumn("App") { (event: AppHistoryEvent) in
                    Text(event.appName)
                }
                .width(min: 150, ideal: 200)
                
                TableColumn("Event") { (event: AppHistoryEvent) in
                    Text(event.eventType.rawValue)
                        .foregroundStyle(event.eventType == .activated ? StatusColor.success : StatusColor.warning)
                }
                .width(min: 80, ideal: 100)
                
                TableColumn("Duration") { (event: AppHistoryEvent) in
                    if let duration = event.duration {
                        Text(formatDuration(duration))
                    } else {
                        Text("-")
                    }
                }
                .width(min: 80, ideal: 100)
                
                TableColumn("Window") { (event: AppHistoryEvent) in
                    Text(event.windowTitle ?? "-")
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            
            paginationControls
        }
        .onAppear(perform: loadEvents)
        .onChange(of: startDate) { _ in resetAndLoad() }
        .onChange(of: endDate) { _ in resetAndLoad() }
    }
    
    private var paginationControls: some View {
        HStack {
            Text("\(filteredEvents.count) items")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button(action: previousPage) { Image(systemName: "chevron.left") }
                .disabled(currentPage == 0)
                .buttonStyle(.bordered)
            Text("Page \(currentPage + 1)").font(.caption)
            Button(action: nextPage) { Image(systemName: "chevron.right") }
                .disabled(!hasMoreData)
                .buttonStyle(.bordered)
        }
        .padding(.horizontal)
        .padding(.vertical, Spacing.sm)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private var filteredEvents: [AppHistoryEvent] {
        if searchText.isEmpty { return events }
        return events.filter { event in
            event.appName.localizedCaseInsensitiveContains(searchText) ||
            event.windowTitle?.localizedCaseInsensitiveContains(searchText) == true
        }
    }
    
    private func resetAndLoad() {
        currentPage = 0
        loadEvents()
    }
    
    private func loadEvents() {
        let offset = currentPage * pageSize
        events = DatabaseManager.shared.fetchAppHistory(from: startDate, to: endDate, limit: pageSize, offset: offset)
        hasMoreData = events.count == pageSize
    }
    
    private func previousPage() { if currentPage > 0 { currentPage -= 1; loadEvents() } }
    private func nextPage() { if hasMoreData { currentPage += 1; loadEvents() } }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        if hours > 0 { return String(format: "%dh %dm", hours, minutes) }
        else if minutes > 0 { return String(format: "%dm %ds", minutes, secs) }
        else { return String(format: "%ds", secs) }
    }
}

struct FileAccessLogView: View {
    let searchText: String
    let startDate: Date?
    let endDate: Date?
    
    @State private var events: [FileAccessEvent] = []
    @State private var currentPage = 0
    @State private var hasMoreData = true
    private let pageSize = 100
    
    var body: some View {
        VStack(spacing: 0) {
            Table(filteredEvents) {
                TableColumn("Time") { (event: FileAccessEvent) in
                    Text(formatDate(event.timestamp))
                        .font(.caption)
                }
                .width(min: 150, ideal: 180)
                
                TableColumn("Event") { (event: FileAccessEvent) in
                    Text(event.eventType.rawValue)
                }
                .width(min: 80, ideal: 100)
                
                TableColumn("File") { (event: FileAccessEvent) in
                    Text(event.fileName)
                }
                .width(min: 150, ideal: 200)
                
                TableColumn("Path") { (event: FileAccessEvent) in
                    Text(event.filePath)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            
            paginationControls
        }
        .onAppear(perform: loadEvents)
        .onChange(of: startDate) { _ in resetAndLoad() }
        .onChange(of: endDate) { _ in resetAndLoad() }
    }
    
    private var paginationControls: some View {
        HStack {
            Text("\(filteredEvents.count) items")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button(action: previousPage) { Image(systemName: "chevron.left") }
                .disabled(currentPage == 0)
                .buttonStyle(.bordered)
            Text("Page \(currentPage + 1)").font(.caption)
            Button(action: nextPage) { Image(systemName: "chevron.right") }
                .disabled(!hasMoreData)
                .buttonStyle(.bordered)
        }
        .padding(.horizontal)
        .padding(.vertical, Spacing.sm)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private var filteredEvents: [FileAccessEvent] {
        if searchText.isEmpty { return events }
        return events.filter { event in
            event.fileName.localizedCaseInsensitiveContains(searchText) ||
            event.filePath.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private func resetAndLoad() {
        currentPage = 0
        loadEvents()
    }
    
    private func loadEvents() {
        let offset = currentPage * pageSize
        events = DatabaseManager.shared.fetchFileAccess(from: startDate, to: endDate, limit: pageSize, offset: offset)
        hasMoreData = events.count == pageSize
    }
    
    private func previousPage() { if currentPage > 0 { currentPage -= 1; loadEvents() } }
    private func nextPage() { if hasMoreData { currentPage += 1; loadEvents() } }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

struct ClipboardLogView: View {
    let searchText: String
    let startDate: Date?
    let endDate: Date?
    var appFilter: String? = nil
    
    @State private var events: [ClipboardEvent] = []
    @State private var currentPage = 0
    @State private var hasMoreData = true
    private let pageSize = 100
    
    var body: some View {
        VStack(spacing: 0) {
            Table(filteredEvents) {
                TableColumn("Time") { (event: ClipboardEvent) in
                    Text(formatDate(event.timestamp))
                        .font(.caption)
                }
                .width(min: 150, ideal: 180)
                
                TableColumn("Type") { (event: ClipboardEvent) in
                    Text(event.contentType.rawValue)
                }
                .width(min: 80, ideal: 100)
                
                TableColumn("Content") { (event: ClipboardEvent) in
                    Text(event.textContent ?? "(binary data)")
                        .lineLimit(2)
                }
                
                TableColumn("Size") { (event: ClipboardEvent) in
                    Text(ByteCountFormatter.string(fromByteCount: Int64(event.dataSize), countStyle: .file))
                        .foregroundStyle(.secondary)
                }
                .width(min: 80, ideal: 100)
                
                TableColumn("Source") { (event: ClipboardEvent) in
                    Text(event.sourceApp ?? "-")
                        .foregroundStyle(.secondary)
                }
                .width(min: 100, ideal: 150)
            }
            
            paginationControls
        }
        .onAppear(perform: loadEvents)
        .onChange(of: startDate) { _ in resetAndLoad() }
        .onChange(of: endDate) { _ in resetAndLoad() }
    }
    
    private var paginationControls: some View {
        HStack {
            Text("\(filteredEvents.count) items")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button(action: previousPage) { Image(systemName: "chevron.left") }
                .disabled(currentPage == 0)
                .buttonStyle(.bordered)
            Text("Page \(currentPage + 1)").font(.caption)
            Button(action: nextPage) { Image(systemName: "chevron.right") }
                .disabled(!hasMoreData)
                .buttonStyle(.bordered)
        }
        .padding(.horizontal)
        .padding(.vertical, Spacing.sm)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private var filteredEvents: [ClipboardEvent] {
        var result = events
        
        if let appFilter = appFilter {
            result = result.filter { $0.sourceApp == appFilter }
        }
        
        if !searchText.isEmpty {
            result = result.filter { event in
                event.textContent?.localizedCaseInsensitiveContains(searchText) == true ||
                event.sourceApp?.localizedCaseInsensitiveContains(searchText) == true
            }
        }
        
        return result
    }
    
    private func resetAndLoad() {
        currentPage = 0
        loadEvents()
    }
    
    private func loadEvents() {
        let offset = currentPage * pageSize
        events = DatabaseManager.shared.fetchClipboard(from: startDate, to: endDate, limit: pageSize, offset: offset)
        hasMoreData = events.count == pageSize
    }
    
    private func previousPage() { if currentPage > 0 { currentPage -= 1; loadEvents() } }
    private func nextPage() { if hasMoreData { currentPage += 1; loadEvents() } }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}
