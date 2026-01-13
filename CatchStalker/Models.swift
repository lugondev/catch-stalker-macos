import Foundation

// MARK: - Keystroke Event
struct KeystrokeEvent: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let keyCode: Int
    let characters: String?
    let modifiers: KeyModifiers
    let activeApp: String?
    
    init(id: UUID = UUID(), timestamp: Date = Date(), keyCode: Int, characters: String?, modifiers: KeyModifiers, activeApp: String?) {
        self.id = id
        self.timestamp = timestamp
        self.keyCode = keyCode
        self.characters = characters
        self.modifiers = modifiers
        self.activeApp = activeApp
    }
}

struct KeyModifiers: Codable, OptionSet {
    let rawValue: Int
    
    static let shift = KeyModifiers(rawValue: 1 << 0)
    static let control = KeyModifiers(rawValue: 1 << 1)
    static let option = KeyModifiers(rawValue: 1 << 2)
    static let command = KeyModifiers(rawValue: 1 << 3)
    static let capsLock = KeyModifiers(rawValue: 1 << 4)
    
    var description: String {
        var parts: [String] = []
        if contains(.command) { parts.append("⌘") }
        if contains(.control) { parts.append("⌃") }
        if contains(.option) { parts.append("⌥") }
        if contains(.shift) { parts.append("⇧") }
        if contains(.capsLock) { parts.append("⇪") }
        return parts.joined()
    }
}

// MARK: - Mouse Event
struct MouseEvent: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let eventType: MouseEventType
    let x: Double
    let y: Double
    let button: MouseButton?
    let clickCount: Int?
    let activeApp: String?
    
    init(id: UUID = UUID(), timestamp: Date = Date(), eventType: MouseEventType, x: Double, y: Double, button: MouseButton? = nil, clickCount: Int? = nil, activeApp: String?) {
        self.id = id
        self.timestamp = timestamp
        self.eventType = eventType
        self.x = x
        self.y = y
        self.button = button
        self.clickCount = clickCount
        self.activeApp = activeApp
    }
}

enum MouseEventType: String, Codable {
    case move
    case leftClick
    case rightClick
    case middleClick
    case scroll
    case drag
}

enum MouseButton: Int, Codable {
    case left = 0
    case right = 1
    case middle = 2
}

// MARK: - Screenshot Event
struct ScreenshotEvent: Identifiable, Codable, Hashable {
    let id: UUID
    let timestamp: Date
    let filePath: String
    let displayID: UInt32
    let width: Int
    let height: Int
    let activeApp: String?
    
    init(id: UUID = UUID(), timestamp: Date = Date(), filePath: String, displayID: UInt32, width: Int, height: Int, activeApp: String?) {
        self.id = id
        self.timestamp = timestamp
        self.filePath = filePath
        self.displayID = displayID
        self.width = width
        self.height = height
        self.activeApp = activeApp
    }
}

// MARK: - Camera Capture Event
struct CameraCaptureEvent: Identifiable, Codable, Hashable {
    let id: UUID
    let timestamp: Date
    let filePath: String
    let width: Int
    let height: Int
    let deviceName: String?
    
    init(id: UUID = UUID(), timestamp: Date = Date(), filePath: String, width: Int, height: Int, deviceName: String?) {
        self.id = id
        self.timestamp = timestamp
        self.filePath = filePath
        self.width = width
        self.height = height
        self.deviceName = deviceName
    }
}

// MARK: - App History Event
struct AppHistoryEvent: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let bundleIdentifier: String
    let appName: String
    let windowTitle: String?
    let eventType: AppEventType
    let duration: TimeInterval?
    
    init(id: UUID = UUID(), timestamp: Date = Date(), bundleIdentifier: String, appName: String, windowTitle: String?, eventType: AppEventType, duration: TimeInterval? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.bundleIdentifier = bundleIdentifier
        self.appName = appName
        self.windowTitle = windowTitle
        self.eventType = eventType
        self.duration = duration
    }
}

enum AppEventType: String, Codable {
    case activated
    case deactivated
    case launched
    case terminated
}

// MARK: - File Access Event
struct FileAccessEvent: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let filePath: String
    let fileName: String
    let eventType: FileEventType
    let appBundleIdentifier: String?
    
    init(id: UUID = UUID(), timestamp: Date = Date(), filePath: String, fileName: String, eventType: FileEventType, appBundleIdentifier: String?) {
        self.id = id
        self.timestamp = timestamp
        self.filePath = filePath
        self.fileName = fileName
        self.eventType = eventType
        self.appBundleIdentifier = appBundleIdentifier
    }
}

enum FileEventType: String, Codable {
    case created
    case modified
    case deleted
    case renamed
    case opened
}

// MARK: - Clipboard Event
struct ClipboardEvent: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let contentType: ClipboardContentType
    let textContent: String?
    let dataSize: Int
    let sourceApp: String?
    
    init(id: UUID = UUID(), timestamp: Date = Date(), contentType: ClipboardContentType, textContent: String?, dataSize: Int, sourceApp: String?) {
        self.id = id
        self.timestamp = timestamp
        self.contentType = contentType
        self.textContent = textContent
        self.dataSize = dataSize
        self.sourceApp = sourceApp
    }
}

enum ClipboardContentType: String, Codable {
    case text
    case image
    case file
    case rtf
    case html
    case other
}

// MARK: - Anti-Sleep Schedule
struct AntiSleepSchedule: Identifiable, Codable {
    let id: UUID
    var name: String
    var isEnabled: Bool
    var startTime: Date
    var endTime: Date
    var weekdays: Set<Weekday>
    
    init(id: UUID = UUID(), name: String, isEnabled: Bool = true, startTime: Date, endTime: Date, weekdays: Set<Weekday>) {
        self.id = id
        self.name = name
        self.isEnabled = isEnabled
        self.startTime = startTime
        self.endTime = endTime
        self.weekdays = weekdays
    }
}

enum Weekday: Int, Codable, CaseIterable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7
    
    var shortName: String {
        switch self {
        case .sunday: return "Sun"
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        }
    }
}

// MARK: - Anti-Sleep App Rule
struct AntiSleepAppRule: Identifiable, Codable {
    let id: UUID
    var bundleIdentifier: String
    var appName: String
    var isEnabled: Bool
    
    init(id: UUID = UUID(), bundleIdentifier: String, appName: String, isEnabled: Bool = true) {
        self.id = id
        self.bundleIdentifier = bundleIdentifier
        self.appName = appName
        self.isEnabled = isEnabled
    }
}

// MARK: - App Settings
struct AppSettings: Codable {
    // Module toggles
    var keystrokeEnabled: Bool = false
    var mouseEnabled: Bool = false
    var screenshotEnabled: Bool = false
    var cameraEnabled: Bool = false
    var appHistoryEnabled: Bool = false
    var fileAccessEnabled: Bool = false
    var clipboardEnabled: Bool = false
    
    // Intervals (in seconds)
    var screenshotInterval: TimeInterval = 10
    var cameraInterval: TimeInterval = 10
    
    // Storage
    var screenshotStoragePath: String = ""
    var cameraStoragePath: String = ""
    var autoDeleteDays: Int = 30
    
    // Anti-sleep
    var antiSleepGlobalEnabled: Bool = false
    var antiSleepSchedules: [AntiSleepSchedule] = []
    var antiSleepAppRules: [AntiSleepAppRule] = []
    
    // Security
    var passwordProtectionEnabled: Bool = false
    var passwordHash: String?
    
    // File access monitoring paths
    var monitoredPaths: [String] = []
    
    static var `default`: AppSettings {
        var settings = AppSettings()
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let baseDir = appSupport.appendingPathComponent("CatchStalker")
        settings.screenshotStoragePath = baseDir.appendingPathComponent("screenshots").path
        settings.cameraStoragePath = baseDir.appendingPathComponent("camera").path
        settings.monitoredPaths = [NSHomeDirectory()]
        return settings
    }
}

// MARK: - Dashboard Stats
struct DashboardStats {
    var totalKeystrokes: Int = 0
    var totalMouseEvents: Int = 0
    var totalScreenshots: Int = 0
    var totalCameraCaptures: Int = 0
    var totalAppSwitches: Int = 0
    var totalFileAccesses: Int = 0
    var totalClipboardEvents: Int = 0
    
    var topApps: [(name: String, duration: TimeInterval)] = []
    var keystrokesPerHour: [Int: Int] = [:] // hour -> count
    var storageUsed: Int64 = 0
}

// MARK: - Log Filter
struct LogFilter {
    var startDate: Date?
    var endDate: Date?
    var searchText: String = ""
    var selectedApps: Set<String> = []
    var eventTypes: Set<String> = []
}
