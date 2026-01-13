import SwiftUI

struct LogsView: View {
    @State private var selectedLogType: LogType = .keystrokes
    @State private var searchText = ""
    @State private var startDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
    @State private var endDate = Date()
    
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
                .foregroundColor(.secondary)
            
            TextField("Search...", text: $searchText)
                .textFieldStyle(.plain)
            
            Divider()
                .frame(height: 20)
            
            DatePicker("From", selection: $startDate, displayedComponents: .date)
                .labelsHidden()
            
            Text("to")
                .foregroundColor(.secondary)
            
            DatePicker("To", selection: $endDate, displayedComponents: .date)
                .labelsHidden()
            
            Button(action: { }) {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
    
    @ViewBuilder
    private var logContent: some View {
        switch selectedLogType {
        case .keystrokes:
            KeystrokesLogView(searchText: searchText, startDate: startDate, endDate: endDate)
        case .mouse:
            MouseLogView(searchText: searchText, startDate: startDate, endDate: endDate)
        case .screenshots:
            ScreenshotsLogView(searchText: searchText, startDate: startDate, endDate: endDate)
        case .camera:
            CameraLogView(searchText: searchText, startDate: startDate, endDate: endDate)
        case .appHistory:
            AppHistoryLogView(searchText: searchText, startDate: startDate, endDate: endDate)
        case .fileAccess:
            FileAccessLogView(searchText: searchText, startDate: startDate, endDate: endDate)
        case .clipboard:
            ClipboardLogView(searchText: searchText, startDate: startDate, endDate: endDate)
        }
    }
}

struct KeystrokesLogView: View {
    let searchText: String
    let startDate: Date
    let endDate: Date
    
    @State private var events: [KeystrokeEvent] = []
    
    var body: some View {
        Table(filteredEvents) {
            TableColumn("Time") { event in
                Text(formatDate(event.timestamp))
                    .font(.caption)
            }
            .width(min: 150, ideal: 180)
            
            TableColumn("Key") { event in
                Text(event.characters ?? "Key \(event.keyCode)")
            }
            .width(min: 80, ideal: 100)
            
            TableColumn("Modifiers") { event in
                Text(event.modifiers.description)
                    .foregroundColor(.secondary)
            }
            .width(min: 80, ideal: 100)
            
            TableColumn("App") { event in
                Text(event.activeApp ?? "-")
                    .foregroundColor(.secondary)
            }
        }
        .onAppear(perform: loadEvents)
        .onChange(of: startDate) { _ in loadEvents() }
        .onChange(of: endDate) { _ in loadEvents() }
    }
    
    private var filteredEvents: [KeystrokeEvent] {
        if searchText.isEmpty { return events }
        return events.filter { event in
            event.characters?.localizedCaseInsensitiveContains(searchText) == true ||
            event.activeApp?.localizedCaseInsensitiveContains(searchText) == true
        }
    }
    
    private func loadEvents() {
        events = DatabaseManager.shared.fetchKeystrokes(from: startDate, to: endDate)
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
    let startDate: Date
    let endDate: Date
    
    @State private var events: [MouseEvent] = []
    
    var body: some View {
        Table(events) {
            TableColumn("Time") { event in
                Text(formatDate(event.timestamp))
                    .font(.caption)
            }
            .width(min: 150, ideal: 180)
            
            TableColumn("Type") { event in
                Text(event.eventType.rawValue)
            }
            .width(min: 80, ideal: 100)
            
            TableColumn("Position") { event in
                Text("(\(Int(event.x)), \(Int(event.y)))")
                    .font(.caption.monospaced())
            }
            .width(min: 100, ideal: 120)
            
            TableColumn("App") { event in
                Text(event.activeApp ?? "-")
                    .foregroundColor(.secondary)
            }
        }
        .onAppear(perform: loadEvents)
        .onChange(of: startDate) { _ in loadEvents() }
        .onChange(of: endDate) { _ in loadEvents() }
    }
    
    private func loadEvents() {
        events = DatabaseManager.shared.fetchMouseEvents(from: startDate, to: endDate)
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
    let startDate: Date
    let endDate: Date
    
    @State private var events: [ScreenshotEvent] = []
    @State private var selectedEvent: ScreenshotEvent?
    
    var body: some View {
        HSplitView {
            List(events, selection: $selectedEvent) { event in
                VStack(alignment: .leading) {
                    Text(formatDate(event.timestamp))
                        .font(.caption)
                    Text("\(event.width) x \(event.height)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
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
                            .foregroundColor(.secondary)
                    }
                    
                    Text(event.filePath)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .padding()
            } else {
                Text("Select a screenshot to preview")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear(perform: loadEvents)
        .onChange(of: startDate) { _ in loadEvents() }
        .onChange(of: endDate) { _ in loadEvents() }
    }
    
    private func loadEvents() {
        events = DatabaseManager.shared.fetchScreenshots(from: startDate, to: endDate)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

struct CameraLogView: View {
    let searchText: String
    let startDate: Date
    let endDate: Date
    
    @State private var events: [CameraCaptureEvent] = []
    @State private var selectedEvent: CameraCaptureEvent?
    
    var body: some View {
        HSplitView {
            List(events, selection: $selectedEvent) { event in
                VStack(alignment: .leading) {
                    Text(formatDate(event.timestamp))
                        .font(.caption)
                    Text(event.deviceName ?? "Unknown camera")
                        .font(.caption2)
                        .foregroundColor(.secondary)
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
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            } else {
                Text("Select a capture to preview")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear(perform: loadEvents)
        .onChange(of: startDate) { _ in loadEvents() }
        .onChange(of: endDate) { _ in loadEvents() }
    }
    
    private func loadEvents() {
        events = DatabaseManager.shared.fetchCameraCaptures(from: startDate, to: endDate)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

struct AppHistoryLogView: View {
    let searchText: String
    let startDate: Date
    let endDate: Date
    
    @State private var events: [AppHistoryEvent] = []
    
    var body: some View {
        Table(filteredEvents) {
            TableColumn("Time") { event in
                Text(formatDate(event.timestamp))
                    .font(.caption)
            }
            .width(min: 150, ideal: 180)
            
            TableColumn("App") { event in
                Text(event.appName)
            }
            .width(min: 150, ideal: 200)
            
            TableColumn("Event") { event in
                Text(event.eventType.rawValue)
                    .foregroundColor(event.eventType == .activated ? .green : .orange)
            }
            .width(min: 80, ideal: 100)
            
            TableColumn("Duration") { event in
                if let duration = event.duration {
                    Text(formatDuration(duration))
                } else {
                    Text("-")
                }
            }
            .width(min: 80, ideal: 100)
            
            TableColumn("Window") { event in
                Text(event.windowTitle ?? "-")
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .onAppear(perform: loadEvents)
        .onChange(of: startDate) { _ in loadEvents() }
        .onChange(of: endDate) { _ in loadEvents() }
    }
    
    private var filteredEvents: [AppHistoryEvent] {
        if searchText.isEmpty { return events }
        return events.filter { event in
            event.appName.localizedCaseInsensitiveContains(searchText) ||
            event.windowTitle?.localizedCaseInsensitiveContains(searchText) == true
        }
    }
    
    private func loadEvents() {
        events = DatabaseManager.shared.fetchAppHistory(from: startDate, to: endDate)
    }
    
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
        
        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, secs)
        } else {
            return String(format: "%ds", secs)
        }
    }
}

struct FileAccessLogView: View {
    let searchText: String
    let startDate: Date
    let endDate: Date
    
    @State private var events: [FileAccessEvent] = []
    
    var body: some View {
        Table(filteredEvents) {
            TableColumn("Time") { event in
                Text(formatDate(event.timestamp))
                    .font(.caption)
            }
            .width(min: 150, ideal: 180)
            
            TableColumn("Event") { event in
                Text(event.eventType.rawValue)
            }
            .width(min: 80, ideal: 100)
            
            TableColumn("File") { event in
                Text(event.fileName)
            }
            .width(min: 150, ideal: 200)
            
            TableColumn("Path") { event in
                Text(event.filePath)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .onAppear(perform: loadEvents)
        .onChange(of: startDate) { _ in loadEvents() }
        .onChange(of: endDate) { _ in loadEvents() }
    }
    
    private var filteredEvents: [FileAccessEvent] {
        if searchText.isEmpty { return events }
        return events.filter { event in
            event.fileName.localizedCaseInsensitiveContains(searchText) ||
            event.filePath.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private func loadEvents() {
        events = DatabaseManager.shared.fetchFileAccess(from: startDate, to: endDate)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

struct ClipboardLogView: View {
    let searchText: String
    let startDate: Date
    let endDate: Date
    
    @State private var events: [ClipboardEvent] = []
    
    var body: some View {
        Table(filteredEvents) {
            TableColumn("Time") { event in
                Text(formatDate(event.timestamp))
                    .font(.caption)
            }
            .width(min: 150, ideal: 180)
            
            TableColumn("Type") { event in
                Text(event.contentType.rawValue)
            }
            .width(min: 80, ideal: 100)
            
            TableColumn("Content") { event in
                Text(event.textContent ?? "(binary data)")
                    .lineLimit(2)
            }
            
            TableColumn("Size") { event in
                Text(ByteCountFormatter.string(fromByteCount: Int64(event.dataSize), countStyle: .file))
                    .foregroundColor(.secondary)
            }
            .width(min: 80, ideal: 100)
            
            TableColumn("Source") { event in
                Text(event.sourceApp ?? "-")
                    .foregroundColor(.secondary)
            }
            .width(min: 100, ideal: 150)
        }
        .onAppear(perform: loadEvents)
        .onChange(of: startDate) { _ in loadEvents() }
        .onChange(of: endDate) { _ in loadEvents() }
    }
    
    private var filteredEvents: [ClipboardEvent] {
        if searchText.isEmpty { return events }
        return events.filter { event in
            event.textContent?.localizedCaseInsensitiveContains(searchText) == true ||
            event.sourceApp?.localizedCaseInsensitiveContains(searchText) == true
        }
    }
    
    private func loadEvents() {
        events = DatabaseManager.shared.fetchClipboard(from: startDate, to: endDate)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}
