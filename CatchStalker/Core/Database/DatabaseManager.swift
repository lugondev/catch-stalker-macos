import Foundation
import SQLite3

// SQLITE_TRANSIENT tells SQLite to make its own copy of the string data
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

final class DatabaseManager {
    static let shared = DatabaseManager()
    
    private var db: OpaquePointer?
    private let dbQueue = DispatchQueue(label: "com.catchstalker.database", qos: .userInitiated)
    
    private init() {
        setupDatabase()
    }
    
    deinit {
        if let db = db {
            sqlite3_close(db)
        }
    }
    
    private func setupDatabase() {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dbDirectory = appSupport.appendingPathComponent("CatchStalker")
        
        do {
            try fileManager.createDirectory(at: dbDirectory, withIntermediateDirectories: true)
        } catch {
            print("Failed to create database directory: \(error)")
            return
        }
        
        let dbPath = dbDirectory.appendingPathComponent("catchstalker.db").path
        
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            print("Failed to open database")
            return
        }
        
        createTables()
    }
    
    private func createTables() {
        let tables = [
            """
            CREATE TABLE IF NOT EXISTS keystrokes (
                id TEXT PRIMARY KEY,
                timestamp REAL NOT NULL,
                key_code INTEGER NOT NULL,
                characters TEXT,
                modifiers INTEGER NOT NULL,
                active_app TEXT
            )
            """,
            """
            CREATE TABLE IF NOT EXISTS mouse_events (
                id TEXT PRIMARY KEY,
                timestamp REAL NOT NULL,
                event_type TEXT NOT NULL,
                x REAL NOT NULL,
                y REAL NOT NULL,
                button INTEGER,
                click_count INTEGER,
                active_app TEXT
            )
            """,
            """
            CREATE TABLE IF NOT EXISTS screenshots (
                id TEXT PRIMARY KEY,
                timestamp REAL NOT NULL,
                file_path TEXT NOT NULL,
                display_id INTEGER NOT NULL,
                width INTEGER NOT NULL,
                height INTEGER NOT NULL,
                active_app TEXT
            )
            """,
            """
            CREATE TABLE IF NOT EXISTS camera_captures (
                id TEXT PRIMARY KEY,
                timestamp REAL NOT NULL,
                file_path TEXT NOT NULL,
                width INTEGER NOT NULL,
                height INTEGER NOT NULL,
                device_name TEXT
            )
            """,
            """
            CREATE TABLE IF NOT EXISTS app_history (
                id TEXT PRIMARY KEY,
                timestamp REAL NOT NULL,
                bundle_identifier TEXT NOT NULL,
                app_name TEXT NOT NULL,
                window_title TEXT,
                event_type TEXT NOT NULL,
                duration REAL
            )
            """,
            """
            CREATE TABLE IF NOT EXISTS file_access (
                id TEXT PRIMARY KEY,
                timestamp REAL NOT NULL,
                file_path TEXT NOT NULL,
                file_name TEXT NOT NULL,
                event_type TEXT NOT NULL,
                app_bundle_identifier TEXT
            )
            """,
            """
            CREATE TABLE IF NOT EXISTS clipboard (
                id TEXT PRIMARY KEY,
                timestamp REAL NOT NULL,
                content_type TEXT NOT NULL,
                text_content TEXT,
                data_size INTEGER NOT NULL,
                source_app TEXT
            )
            """,
            "CREATE INDEX IF NOT EXISTS idx_keystrokes_timestamp ON keystrokes(timestamp)",
            "CREATE INDEX IF NOT EXISTS idx_mouse_events_timestamp ON mouse_events(timestamp)",
            "CREATE INDEX IF NOT EXISTS idx_screenshots_timestamp ON screenshots(timestamp)",
            "CREATE INDEX IF NOT EXISTS idx_camera_captures_timestamp ON camera_captures(timestamp)",
            "CREATE INDEX IF NOT EXISTS idx_app_history_timestamp ON app_history(timestamp)",
            "CREATE INDEX IF NOT EXISTS idx_file_access_timestamp ON file_access(timestamp)",
            "CREATE INDEX IF NOT EXISTS idx_clipboard_timestamp ON clipboard(timestamp)"
        ]
        
        for sql in tables {
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                if sqlite3_step(statement) != SQLITE_DONE {
                    print("Failed to execute: \(sql)")
                }
            }
            sqlite3_finalize(statement)
        }
    }
    
    func insertKeystroke(_ event: KeystrokeEvent) {
        dbQueue.async { [weak self] in
            guard let self = self, let db = self.db else { return }
            
            let sql = "INSERT INTO keystrokes (id, timestamp, key_code, characters, modifiers, active_app) VALUES (?, ?, ?, ?, ?, ?)"
            var statement: OpaquePointer?
            
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, (event.id.uuidString as NSString).utf8String, -1, SQLITE_TRANSIENT)
                sqlite3_bind_double(statement, 2, event.timestamp.timeIntervalSince1970)
                sqlite3_bind_int(statement, 3, Int32(event.keyCode))
                if let chars = event.characters {
                    sqlite3_bind_text(statement, 4, (chars as NSString).utf8String, -1, SQLITE_TRANSIENT)
                } else {
                    sqlite3_bind_null(statement, 4)
                }
                sqlite3_bind_int(statement, 5, Int32(event.modifiers.rawValue))
                if let app = event.activeApp {
                    sqlite3_bind_text(statement, 6, (app as NSString).utf8String, -1, SQLITE_TRANSIENT)
                } else {
                    sqlite3_bind_null(statement, 6)
                }
                
                let result = sqlite3_step(statement)
                if result != SQLITE_DONE {
                    print("[DatabaseManager] ERROR: Failed to insert keystroke - \(String(cString: sqlite3_errmsg(db)))")
                }
            } else {
                print("[DatabaseManager] ERROR: Failed to prepare keystroke insert - \(String(cString: sqlite3_errmsg(db)))")
            }
            sqlite3_finalize(statement)
        }
    }
    
    func insertMouseEvent(_ event: MouseEvent) {
        dbQueue.async { [weak self] in
            guard let self = self, let db = self.db else { return }
            
            let sql = "INSERT INTO mouse_events (id, timestamp, event_type, x, y, button, click_count, active_app) VALUES (?, ?, ?, ?, ?, ?, ?, ?)"
            var statement: OpaquePointer?
            
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, (event.id.uuidString as NSString).utf8String, -1, SQLITE_TRANSIENT)
                sqlite3_bind_double(statement, 2, event.timestamp.timeIntervalSince1970)
                sqlite3_bind_text(statement, 3, (event.eventType.rawValue as NSString).utf8String, -1, SQLITE_TRANSIENT)
                sqlite3_bind_double(statement, 4, event.x)
                sqlite3_bind_double(statement, 5, event.y)
                if let button = event.button {
                    sqlite3_bind_int(statement, 6, Int32(button.rawValue))
                } else {
                    sqlite3_bind_null(statement, 6)
                }
                if let count = event.clickCount {
                    sqlite3_bind_int(statement, 7, Int32(count))
                } else {
                    sqlite3_bind_null(statement, 7)
                }
                if let app = event.activeApp {
                    sqlite3_bind_text(statement, 8, (app as NSString).utf8String, -1, SQLITE_TRANSIENT)
                } else {
                    sqlite3_bind_null(statement, 8)
                }
                
                let result = sqlite3_step(statement)
                if result != SQLITE_DONE {
                    print("[DatabaseManager] ERROR: Failed to insert mouse event - \(String(cString: sqlite3_errmsg(db)))")
                }
            } else {
                print("[DatabaseManager] ERROR: Failed to prepare mouse event insert - \(String(cString: sqlite3_errmsg(db)))")
            }
            sqlite3_finalize(statement)
        }
    }
    
    func insertScreenshot(_ event: ScreenshotEvent) {
        dbQueue.async { [weak self] in
            guard let self = self, let db = self.db else { return }
            
            let sql = "INSERT INTO screenshots (id, timestamp, file_path, display_id, width, height, active_app) VALUES (?, ?, ?, ?, ?, ?, ?)"
            var statement: OpaquePointer?
            
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, (event.id.uuidString as NSString).utf8String, -1, SQLITE_TRANSIENT)
                sqlite3_bind_double(statement, 2, event.timestamp.timeIntervalSince1970)
                sqlite3_bind_text(statement, 3, (event.filePath as NSString).utf8String, -1, SQLITE_TRANSIENT)
                sqlite3_bind_int(statement, 4, Int32(event.displayID))
                sqlite3_bind_int(statement, 5, Int32(event.width))
                sqlite3_bind_int(statement, 6, Int32(event.height))
                if let app = event.activeApp {
                    sqlite3_bind_text(statement, 7, (app as NSString).utf8String, -1, SQLITE_TRANSIENT)
                } else {
                    sqlite3_bind_null(statement, 7)
                }
                
                let result = sqlite3_step(statement)
                if result != SQLITE_DONE {
                    print("[DatabaseManager] ERROR: Failed to insert screenshot - \(String(cString: sqlite3_errmsg(db)))")
                }
            } else {
                print("[DatabaseManager] ERROR: Failed to prepare screenshot insert - \(String(cString: sqlite3_errmsg(db)))")
            }
            sqlite3_finalize(statement)
        }
    }
    
    func insertCameraCapture(_ event: CameraCaptureEvent) {
        dbQueue.async { [weak self] in
            guard let self = self, let db = self.db else { return }
            
            let sql = "INSERT INTO camera_captures (id, timestamp, file_path, width, height, device_name) VALUES (?, ?, ?, ?, ?, ?)"
            var statement: OpaquePointer?
            
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, (event.id.uuidString as NSString).utf8String, -1, SQLITE_TRANSIENT)
                sqlite3_bind_double(statement, 2, event.timestamp.timeIntervalSince1970)
                sqlite3_bind_text(statement, 3, (event.filePath as NSString).utf8String, -1, SQLITE_TRANSIENT)
                sqlite3_bind_int(statement, 4, Int32(event.width))
                sqlite3_bind_int(statement, 5, Int32(event.height))
                if let name = event.deviceName {
                    sqlite3_bind_text(statement, 6, (name as NSString).utf8String, -1, SQLITE_TRANSIENT)
                } else {
                    sqlite3_bind_null(statement, 6)
                }
                
                let result = sqlite3_step(statement)
                if result != SQLITE_DONE {
                    print("[DatabaseManager] ERROR: Failed to insert camera capture - \(String(cString: sqlite3_errmsg(db)))")
                }
            } else {
                print("[DatabaseManager] ERROR: Failed to prepare camera capture insert - \(String(cString: sqlite3_errmsg(db)))")
            }
            sqlite3_finalize(statement)
        }
    }
    
    func insertAppHistory(_ event: AppHistoryEvent) {
        dbQueue.async { [weak self] in
            guard let self = self, let db = self.db else { return }
            
            let sql = "INSERT INTO app_history (id, timestamp, bundle_identifier, app_name, window_title, event_type, duration) VALUES (?, ?, ?, ?, ?, ?, ?)"
            var statement: OpaquePointer?
            
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, (event.id.uuidString as NSString).utf8String, -1, SQLITE_TRANSIENT)
                sqlite3_bind_double(statement, 2, event.timestamp.timeIntervalSince1970)
                sqlite3_bind_text(statement, 3, (event.bundleIdentifier as NSString).utf8String, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(statement, 4, (event.appName as NSString).utf8String, -1, SQLITE_TRANSIENT)
                if let title = event.windowTitle {
                    sqlite3_bind_text(statement, 5, (title as NSString).utf8String, -1, SQLITE_TRANSIENT)
                } else {
                    sqlite3_bind_null(statement, 5)
                }
                sqlite3_bind_text(statement, 6, (event.eventType.rawValue as NSString).utf8String, -1, SQLITE_TRANSIENT)
                if let duration = event.duration {
                    sqlite3_bind_double(statement, 7, duration)
                } else {
                    sqlite3_bind_null(statement, 7)
                }
                
                let result = sqlite3_step(statement)
                if result != SQLITE_DONE {
                    print("[DatabaseManager] ERROR: Failed to insert app history - \(String(cString: sqlite3_errmsg(db)))")
                }
            } else {
                print("[DatabaseManager] ERROR: Failed to prepare app history insert - \(String(cString: sqlite3_errmsg(db)))")
            }
            sqlite3_finalize(statement)
        }
    }
    
    func insertFileAccess(_ event: FileAccessEvent) {
        dbQueue.async { [weak self] in
            guard let self = self, let db = self.db else { return }
            
            let sql = "INSERT INTO file_access (id, timestamp, file_path, file_name, event_type, app_bundle_identifier) VALUES (?, ?, ?, ?, ?, ?)"
            var statement: OpaquePointer?
            
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, (event.id.uuidString as NSString).utf8String, -1, SQLITE_TRANSIENT)
                sqlite3_bind_double(statement, 2, event.timestamp.timeIntervalSince1970)
                sqlite3_bind_text(statement, 3, (event.filePath as NSString).utf8String, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(statement, 4, (event.fileName as NSString).utf8String, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(statement, 5, (event.eventType.rawValue as NSString).utf8String, -1, SQLITE_TRANSIENT)
                if let bundleId = event.appBundleIdentifier {
                    sqlite3_bind_text(statement, 6, (bundleId as NSString).utf8String, -1, SQLITE_TRANSIENT)
                } else {
                    sqlite3_bind_null(statement, 6)
                }
                
                let result = sqlite3_step(statement)
                if result != SQLITE_DONE {
                    print("[DatabaseManager] ERROR: Failed to insert file access - \(String(cString: sqlite3_errmsg(db)))")
                }
            } else {
                print("[DatabaseManager] ERROR: Failed to prepare file access insert - \(String(cString: sqlite3_errmsg(db)))")
            }
            sqlite3_finalize(statement)
        }
    }
    
    func insertClipboard(_ event: ClipboardEvent) {
        dbQueue.async { [weak self] in
            guard let self = self, let db = self.db else { return }
            
            let sql = "INSERT INTO clipboard (id, timestamp, content_type, text_content, data_size, source_app) VALUES (?, ?, ?, ?, ?, ?)"
            var statement: OpaquePointer?
            
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, (event.id.uuidString as NSString).utf8String, -1, SQLITE_TRANSIENT)
                sqlite3_bind_double(statement, 2, event.timestamp.timeIntervalSince1970)
                sqlite3_bind_text(statement, 3, (event.contentType.rawValue as NSString).utf8String, -1, SQLITE_TRANSIENT)
                if let text = event.textContent {
                    sqlite3_bind_text(statement, 4, (text as NSString).utf8String, -1, SQLITE_TRANSIENT)
                } else {
                    sqlite3_bind_null(statement, 4)
                }
                sqlite3_bind_int(statement, 5, Int32(event.dataSize))
                if let app = event.sourceApp {
                    sqlite3_bind_text(statement, 6, (app as NSString).utf8String, -1, SQLITE_TRANSIENT)
                } else {
                    sqlite3_bind_null(statement, 6)
                }
                
                let result = sqlite3_step(statement)
                if result != SQLITE_DONE {
                    print("[DatabaseManager] ERROR: Failed to insert clipboard - \(String(cString: sqlite3_errmsg(db)))")
                }
            } else {
                print("[DatabaseManager] ERROR: Failed to prepare clipboard insert - \(String(cString: sqlite3_errmsg(db)))")
            }
            sqlite3_finalize(statement)
        }
    }
    
    func fetchKeystrokes(from: Date? = nil, to: Date? = nil, limit: Int = 1000, offset: Int = 0) -> [KeystrokeEvent] {
        var events: [KeystrokeEvent] = []
        var sql = "SELECT id, timestamp, key_code, characters, modifiers, active_app FROM keystrokes"
        var conditions: [String] = []
        
        if from != nil { conditions.append("timestamp >= ?") }
        if to != nil { conditions.append("timestamp <= ?") }
        
        if !conditions.isEmpty {
            sql += " WHERE " + conditions.joined(separator: " AND ")
        }
        sql += " ORDER BY timestamp DESC LIMIT ? OFFSET ?"
        
        dbQueue.sync {
            guard let db = db else { return }
            var statement: OpaquePointer?
            
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                var bindIndex: Int32 = 1
                if let from = from {
                    sqlite3_bind_double(statement, bindIndex, from.timeIntervalSince1970)
                    bindIndex += 1
                }
                if let to = to {
                    sqlite3_bind_double(statement, bindIndex, to.timeIntervalSince1970)
                    bindIndex += 1
                }
                sqlite3_bind_int(statement, bindIndex, Int32(limit))
                bindIndex += 1
                sqlite3_bind_int(statement, bindIndex, Int32(offset))
                
                while sqlite3_step(statement) == SQLITE_ROW {
                    let idString = String(cString: sqlite3_column_text(statement, 0))
                    let timestamp = Date(timeIntervalSince1970: sqlite3_column_double(statement, 1))
                    let keyCode = Int(sqlite3_column_int(statement, 2))
                    let characters: String? = sqlite3_column_text(statement, 3).map { String(cString: $0) }
                    let modifiers = KeyModifiers(rawValue: Int(sqlite3_column_int(statement, 4)))
                    let activeApp: String? = sqlite3_column_text(statement, 5).map { String(cString: $0) }
                    
                    if let id = UUID(uuidString: idString) {
                        events.append(KeystrokeEvent(id: id, timestamp: timestamp, keyCode: keyCode, characters: characters, modifiers: modifiers, activeApp: activeApp))
                    }
                }
            }
            sqlite3_finalize(statement)
        }
        
        return events
    }
    
    func fetchDistinctApps() -> [String] {
        var apps: [String] = []
        let sql = """
            SELECT DISTINCT active_app FROM keystrokes WHERE active_app IS NOT NULL AND active_app != ''
            UNION
            SELECT DISTINCT active_app FROM mouse_events WHERE active_app IS NOT NULL AND active_app != ''
            UNION
            SELECT DISTINCT active_app FROM screenshots WHERE active_app IS NOT NULL AND active_app != ''
            UNION
            SELECT DISTINCT source_app FROM clipboard WHERE source_app IS NOT NULL AND source_app != ''
        """
        
        dbQueue.sync {
            guard let db = db else { return }
            var statement: OpaquePointer?
            
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                while sqlite3_step(statement) == SQLITE_ROW {
                    if let appName = sqlite3_column_text(statement, 0) {
                        apps.append(String(cString: appName))
                    }
                }
            }
            sqlite3_finalize(statement)
        }
        
        return apps
    }
    
    func fetchMouseEvents(from: Date? = nil, to: Date? = nil, limit: Int = 1000, offset: Int = 0) -> [MouseEvent] {
        var events: [MouseEvent] = []
        var sql = "SELECT id, timestamp, event_type, x, y, button, click_count, active_app FROM mouse_events"
        var conditions: [String] = []
        
        if from != nil { conditions.append("timestamp >= ?") }
        if to != nil { conditions.append("timestamp <= ?") }
        
        if !conditions.isEmpty {
            sql += " WHERE " + conditions.joined(separator: " AND ")
        }
        sql += " ORDER BY timestamp DESC LIMIT ? OFFSET ?"
        
        dbQueue.sync {
            guard let db = db else { return }
            var statement: OpaquePointer?
            
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                var bindIndex: Int32 = 1
                if let from = from {
                    sqlite3_bind_double(statement, bindIndex, from.timeIntervalSince1970)
                    bindIndex += 1
                }
                if let to = to {
                    sqlite3_bind_double(statement, bindIndex, to.timeIntervalSince1970)
                    bindIndex += 1
                }
                sqlite3_bind_int(statement, bindIndex, Int32(limit))
                bindIndex += 1
                sqlite3_bind_int(statement, bindIndex, Int32(offset))
                
                while sqlite3_step(statement) == SQLITE_ROW {
                    let idString = String(cString: sqlite3_column_text(statement, 0))
                    let timestamp = Date(timeIntervalSince1970: sqlite3_column_double(statement, 1))
                    let eventTypeStr = String(cString: sqlite3_column_text(statement, 2))
                    let x = sqlite3_column_double(statement, 3)
                    let y = sqlite3_column_double(statement, 4)
                    let button: MouseButton? = sqlite3_column_type(statement, 5) != SQLITE_NULL ? MouseButton(rawValue: Int(sqlite3_column_int(statement, 5))) : nil
                    let clickCount: Int? = sqlite3_column_type(statement, 6) != SQLITE_NULL ? Int(sqlite3_column_int(statement, 6)) : nil
                    let activeApp: String? = sqlite3_column_text(statement, 7).map { String(cString: $0) }
                    
                    if let id = UUID(uuidString: idString), let eventType = MouseEventType(rawValue: eventTypeStr) {
                        events.append(MouseEvent(id: id, timestamp: timestamp, eventType: eventType, x: x, y: y, button: button, clickCount: clickCount, activeApp: activeApp))
                    }
                }
            }
            sqlite3_finalize(statement)
        }
        
        return events
    }
    
    func fetchScreenshots(from: Date? = nil, to: Date? = nil, limit: Int = 100, offset: Int = 0) -> [ScreenshotEvent] {
        var events: [ScreenshotEvent] = []
        var sql = "SELECT id, timestamp, file_path, display_id, width, height, active_app FROM screenshots"
        var conditions: [String] = []
        
        if from != nil { conditions.append("timestamp >= ?") }
        if to != nil { conditions.append("timestamp <= ?") }
        
        if !conditions.isEmpty {
            sql += " WHERE " + conditions.joined(separator: " AND ")
        }
        sql += " ORDER BY timestamp DESC LIMIT ? OFFSET ?"
        
        dbQueue.sync {
            guard let db = db else { return }
            var statement: OpaquePointer?
            
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                var bindIndex: Int32 = 1
                if let from = from {
                    sqlite3_bind_double(statement, bindIndex, from.timeIntervalSince1970)
                    bindIndex += 1
                }
                if let to = to {
                    sqlite3_bind_double(statement, bindIndex, to.timeIntervalSince1970)
                    bindIndex += 1
                }
                sqlite3_bind_int(statement, bindIndex, Int32(limit))
                bindIndex += 1
                sqlite3_bind_int(statement, bindIndex, Int32(offset))
                
                while sqlite3_step(statement) == SQLITE_ROW {
                    let idString = String(cString: sqlite3_column_text(statement, 0))
                    let timestamp = Date(timeIntervalSince1970: sqlite3_column_double(statement, 1))
                    let filePath = String(cString: sqlite3_column_text(statement, 2))
                    let displayID = UInt32(sqlite3_column_int(statement, 3))
                    let width = Int(sqlite3_column_int(statement, 4))
                    let height = Int(sqlite3_column_int(statement, 5))
                    let activeApp: String? = sqlite3_column_text(statement, 6).map { String(cString: $0) }
                    
                    if let id = UUID(uuidString: idString) {
                        events.append(ScreenshotEvent(id: id, timestamp: timestamp, filePath: filePath, displayID: displayID, width: width, height: height, activeApp: activeApp))
                    }
                }
            }
            sqlite3_finalize(statement)
        }
        
        return events
    }
    
    func fetchCameraCaptures(from: Date? = nil, to: Date? = nil, limit: Int = 100, offset: Int = 0) -> [CameraCaptureEvent] {
        var events: [CameraCaptureEvent] = []
        var sql = "SELECT id, timestamp, file_path, width, height, device_name FROM camera_captures"
        var conditions: [String] = []
        
        if from != nil { conditions.append("timestamp >= ?") }
        if to != nil { conditions.append("timestamp <= ?") }
        
        if !conditions.isEmpty {
            sql += " WHERE " + conditions.joined(separator: " AND ")
        }
        sql += " ORDER BY timestamp DESC LIMIT ? OFFSET ?"
        
        dbQueue.sync {
            guard let db = db else { return }
            var statement: OpaquePointer?
            
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                var bindIndex: Int32 = 1
                if let from = from {
                    sqlite3_bind_double(statement, bindIndex, from.timeIntervalSince1970)
                    bindIndex += 1
                }
                if let to = to {
                    sqlite3_bind_double(statement, bindIndex, to.timeIntervalSince1970)
                    bindIndex += 1
                }
                sqlite3_bind_int(statement, bindIndex, Int32(limit))
                bindIndex += 1
                sqlite3_bind_int(statement, bindIndex, Int32(offset))
                
                while sqlite3_step(statement) == SQLITE_ROW {
                    let idString = String(cString: sqlite3_column_text(statement, 0))
                    let timestamp = Date(timeIntervalSince1970: sqlite3_column_double(statement, 1))
                    let filePath = String(cString: sqlite3_column_text(statement, 2))
                    let width = Int(sqlite3_column_int(statement, 3))
                    let height = Int(sqlite3_column_int(statement, 4))
                    let deviceName: String? = sqlite3_column_text(statement, 5).map { String(cString: $0) }
                    
                    if let id = UUID(uuidString: idString) {
                        events.append(CameraCaptureEvent(id: id, timestamp: timestamp, filePath: filePath, width: width, height: height, deviceName: deviceName))
                    }
                }
            }
            sqlite3_finalize(statement)
        }
        
        return events
    }
    
    func fetchAppHistory(from: Date? = nil, to: Date? = nil, limit: Int = 1000, offset: Int = 0) -> [AppHistoryEvent] {
        var events: [AppHistoryEvent] = []
        var sql = "SELECT id, timestamp, bundle_identifier, app_name, window_title, event_type, duration FROM app_history"
        var conditions: [String] = []
        
        if from != nil { conditions.append("timestamp >= ?") }
        if to != nil { conditions.append("timestamp <= ?") }
        
        if !conditions.isEmpty {
            sql += " WHERE " + conditions.joined(separator: " AND ")
        }
        sql += " ORDER BY timestamp DESC LIMIT ? OFFSET ?"
        
        dbQueue.sync {
            guard let db = db else { return }
            var statement: OpaquePointer?
            
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                var bindIndex: Int32 = 1
                if let from = from {
                    sqlite3_bind_double(statement, bindIndex, from.timeIntervalSince1970)
                    bindIndex += 1
                }
                if let to = to {
                    sqlite3_bind_double(statement, bindIndex, to.timeIntervalSince1970)
                    bindIndex += 1
                }
                sqlite3_bind_int(statement, bindIndex, Int32(limit))
                bindIndex += 1
                sqlite3_bind_int(statement, bindIndex, Int32(offset))
                
                while sqlite3_step(statement) == SQLITE_ROW {
                    let idString = String(cString: sqlite3_column_text(statement, 0))
                    let timestamp = Date(timeIntervalSince1970: sqlite3_column_double(statement, 1))
                    let bundleId = String(cString: sqlite3_column_text(statement, 2))
                    let appName = String(cString: sqlite3_column_text(statement, 3))
                    let windowTitle: String? = sqlite3_column_text(statement, 4).map { String(cString: $0) }
                    let eventTypeStr = String(cString: sqlite3_column_text(statement, 5))
                    let duration: TimeInterval? = sqlite3_column_type(statement, 6) != SQLITE_NULL ? sqlite3_column_double(statement, 6) : nil
                    
                    if let id = UUID(uuidString: idString), let eventType = AppEventType(rawValue: eventTypeStr) {
                        events.append(AppHistoryEvent(id: id, timestamp: timestamp, bundleIdentifier: bundleId, appName: appName, windowTitle: windowTitle, eventType: eventType, duration: duration))
                    }
                }
            }
            sqlite3_finalize(statement)
        }
        
        return events
    }
    
    func fetchFileAccess(from: Date? = nil, to: Date? = nil, limit: Int = 1000, offset: Int = 0) -> [FileAccessEvent] {
        var events: [FileAccessEvent] = []
        var sql = "SELECT id, timestamp, file_path, file_name, event_type, app_bundle_identifier FROM file_access"
        var conditions: [String] = []
        
        if from != nil { conditions.append("timestamp >= ?") }
        if to != nil { conditions.append("timestamp <= ?") }
        
        if !conditions.isEmpty {
            sql += " WHERE " + conditions.joined(separator: " AND ")
        }
        sql += " ORDER BY timestamp DESC LIMIT ? OFFSET ?"
        
        dbQueue.sync {
            guard let db = db else { return }
            var statement: OpaquePointer?
            
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                var bindIndex: Int32 = 1
                if let from = from {
                    sqlite3_bind_double(statement, bindIndex, from.timeIntervalSince1970)
                    bindIndex += 1
                }
                if let to = to {
                    sqlite3_bind_double(statement, bindIndex, to.timeIntervalSince1970)
                    bindIndex += 1
                }
                sqlite3_bind_int(statement, bindIndex, Int32(limit))
                bindIndex += 1
                sqlite3_bind_int(statement, bindIndex, Int32(offset))
                
                while sqlite3_step(statement) == SQLITE_ROW {
                    let idString = String(cString: sqlite3_column_text(statement, 0))
                    let timestamp = Date(timeIntervalSince1970: sqlite3_column_double(statement, 1))
                    let filePath = String(cString: sqlite3_column_text(statement, 2))
                    let fileName = String(cString: sqlite3_column_text(statement, 3))
                    let eventTypeStr = String(cString: sqlite3_column_text(statement, 4))
                    let appBundleId: String? = sqlite3_column_text(statement, 5).map { String(cString: $0) }
                    
                    if let id = UUID(uuidString: idString), let eventType = FileEventType(rawValue: eventTypeStr) {
                        events.append(FileAccessEvent(id: id, timestamp: timestamp, filePath: filePath, fileName: fileName, eventType: eventType, appBundleIdentifier: appBundleId))
                    }
                }
            }
            sqlite3_finalize(statement)
        }
        
        return events
    }
    
    func fetchClipboard(from: Date? = nil, to: Date? = nil, limit: Int = 500, offset: Int = 0) -> [ClipboardEvent] {
        var events: [ClipboardEvent] = []
        var sql = "SELECT id, timestamp, content_type, text_content, data_size, source_app FROM clipboard"
        var conditions: [String] = []
        
        if from != nil { conditions.append("timestamp >= ?") }
        if to != nil { conditions.append("timestamp <= ?") }
        
        if !conditions.isEmpty {
            sql += " WHERE " + conditions.joined(separator: " AND ")
        }
        sql += " ORDER BY timestamp DESC LIMIT ? OFFSET ?"
        
        dbQueue.sync {
            guard let db = db else { return }
            var statement: OpaquePointer?
            
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                var bindIndex: Int32 = 1
                if let from = from {
                    sqlite3_bind_double(statement, bindIndex, from.timeIntervalSince1970)
                    bindIndex += 1
                }
                if let to = to {
                    sqlite3_bind_double(statement, bindIndex, to.timeIntervalSince1970)
                    bindIndex += 1
                }
                sqlite3_bind_int(statement, bindIndex, Int32(limit))
                bindIndex += 1
                sqlite3_bind_int(statement, bindIndex, Int32(offset))
                
                while sqlite3_step(statement) == SQLITE_ROW {
                    let idString = String(cString: sqlite3_column_text(statement, 0))
                    let timestamp = Date(timeIntervalSince1970: sqlite3_column_double(statement, 1))
                    let contentTypeStr = String(cString: sqlite3_column_text(statement, 2))
                    let textContent: String? = sqlite3_column_text(statement, 3).map { String(cString: $0) }
                    let dataSize = Int(sqlite3_column_int(statement, 4))
                    let sourceApp: String? = sqlite3_column_text(statement, 5).map { String(cString: $0) }
                    
                    if let id = UUID(uuidString: idString), let contentType = ClipboardContentType(rawValue: contentTypeStr) {
                        events.append(ClipboardEvent(id: id, timestamp: timestamp, contentType: contentType, textContent: textContent, dataSize: dataSize, sourceApp: sourceApp))
                    }
                }
            }
            sqlite3_finalize(statement)
        }
        
        return events
    }
    
    func deleteOldData(olderThan date: Date) {
        dbQueue.async { [weak self] in
            guard let self = self, let db = self.db else { return }
            
            let timestamp = date.timeIntervalSince1970
            let tables = ["keystrokes", "mouse_events", "screenshots", "camera_captures", "app_history", "file_access", "clipboard"]
            
            for table in tables {
                let sql = "DELETE FROM \(table) WHERE timestamp < ?"
                var statement: OpaquePointer?
                
                if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                    sqlite3_bind_double(statement, 1, timestamp)
                    sqlite3_step(statement)
                }
                sqlite3_finalize(statement)
            }
        }
    }
    
    func deleteAllData() {
        dbQueue.async { [weak self] in
            guard let self = self, let db = self.db else { return }
            
            let tables = ["keystrokes", "mouse_events", "screenshots", "camera_captures", "app_history", "file_access", "clipboard"]
            
            for table in tables {
                let sql = "DELETE FROM \(table)"
                var statement: OpaquePointer?
                
                if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                    sqlite3_step(statement)
                }
                sqlite3_finalize(statement)
            }
            
            print("[DatabaseManager] All data deleted from all tables")
        }
    }
    
    func getStats() -> DashboardStats {
        var stats = DashboardStats()
        
        dbQueue.sync {
            guard let db = db else { return }
            
            let countQueries = [
                ("keystrokes", \DashboardStats.totalKeystrokes),
                ("mouse_events", \DashboardStats.totalMouseEvents),
                ("screenshots", \DashboardStats.totalScreenshots),
                ("camera_captures", \DashboardStats.totalCameraCaptures),
                ("app_history", \DashboardStats.totalAppSwitches),
                ("file_access", \DashboardStats.totalFileAccesses),
                ("clipboard", \DashboardStats.totalClipboardEvents)
            ]
            
            for (table, keyPath) in countQueries {
                let sql = "SELECT COUNT(*) FROM \(table)"
                var statement: OpaquePointer?
                if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                    if sqlite3_step(statement) == SQLITE_ROW {
                        stats[keyPath: keyPath] = Int(sqlite3_column_int(statement, 0))
                    }
                }
                sqlite3_finalize(statement)
            }
            
            stats.topApps = fetchTopApps(db: db, limit: 10)
            stats.keystrokesPerHour = fetchKeystrokesPerHour(db: db)
        }
        
        return stats
    }
    
    private func fetchTopApps(db: OpaquePointer, limit: Int) -> [(name: String, duration: TimeInterval)] {
        var results: [(name: String, duration: TimeInterval)] = []
        
        let sql = """
            SELECT app_name, SUM(duration) as total_duration 
            FROM app_history 
            WHERE event_type = 'deactivated' AND duration IS NOT NULL
            GROUP BY app_name 
            ORDER BY total_duration DESC 
            LIMIT ?
            """
        
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_int(statement, 1, Int32(limit))
            
            while sqlite3_step(statement) == SQLITE_ROW {
                if let appNamePtr = sqlite3_column_text(statement, 0) {
                    let appName = String(cString: appNamePtr)
                    let duration = sqlite3_column_double(statement, 1)
                    results.append((name: appName, duration: duration))
                }
            }
        }
        sqlite3_finalize(statement)
        
        return results
    }
    
    private func fetchKeystrokesPerHour(db: OpaquePointer) -> [Int: Int] {
        var results: [Int: Int] = [:]
        
        let todayStart = Calendar.current.startOfDay(for: Date())
        let sql = """
            SELECT CAST(strftime('%H', datetime(timestamp, 'unixepoch', 'localtime')) AS INTEGER) as hour, 
                   COUNT(*) as count 
            FROM keystrokes 
            WHERE timestamp >= ?
            GROUP BY hour
            """
        
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_double(statement, 1, todayStart.timeIntervalSince1970)
            
            while sqlite3_step(statement) == SQLITE_ROW {
                let hour = Int(sqlite3_column_int(statement, 0))
                let count = Int(sqlite3_column_int(statement, 1))
                results[hour] = count
            }
        }
        sqlite3_finalize(statement)
        
        return results
    }
}
