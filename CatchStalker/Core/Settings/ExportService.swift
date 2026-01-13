import Foundation

final class ExportService {
    static let shared = ExportService()
    
    enum ExportFormat {
        case json
        case csv
    }
    
    enum ExportType {
        case keystrokes
        case mouse
        case screenshots
        case camera
        case appHistory
        case fileAccess
        case clipboard
        case all
    }
    
    private init() {}
    
    func exportData(
        types: Set<ExportType>,
        format: ExportFormat,
        from startDate: Date,
        to endDate: Date,
        destinationURL: URL
    ) throws {
        var exportedFiles: [URL] = []
        
        if types.contains(.all) || types.contains(.keystrokes) {
            let data = DatabaseManager.shared.fetchKeystrokes(from: startDate, to: endDate)
            let url = try exportKeystrokes(data, format: format, to: destinationURL)
            exportedFiles.append(url)
        }
        
        if types.contains(.all) || types.contains(.mouse) {
            let data = DatabaseManager.shared.fetchMouseEvents(from: startDate, to: endDate)
            let url = try exportMouseEvents(data, format: format, to: destinationURL)
            exportedFiles.append(url)
        }
        
        if types.contains(.all) || types.contains(.screenshots) {
            let data = DatabaseManager.shared.fetchScreenshots(from: startDate, to: endDate)
            let url = try exportScreenshots(data, format: format, to: destinationURL)
            exportedFiles.append(url)
        }
        
        if types.contains(.all) || types.contains(.camera) {
            let data = DatabaseManager.shared.fetchCameraCaptures(from: startDate, to: endDate)
            let url = try exportCameraCaptures(data, format: format, to: destinationURL)
            exportedFiles.append(url)
        }
        
        if types.contains(.all) || types.contains(.appHistory) {
            let data = DatabaseManager.shared.fetchAppHistory(from: startDate, to: endDate)
            let url = try exportAppHistory(data, format: format, to: destinationURL)
            exportedFiles.append(url)
        }
        
        if types.contains(.all) || types.contains(.fileAccess) {
            let data = DatabaseManager.shared.fetchFileAccess(from: startDate, to: endDate)
            let url = try exportFileAccess(data, format: format, to: destinationURL)
            exportedFiles.append(url)
        }
        
        if types.contains(.all) || types.contains(.clipboard) {
            let data = DatabaseManager.shared.fetchClipboard(from: startDate, to: endDate)
            let url = try exportClipboard(data, format: format, to: destinationURL)
            exportedFiles.append(url)
        }
    }
    
    private func exportKeystrokes(_ events: [KeystrokeEvent], format: ExportFormat, to baseURL: URL) throws -> URL {
        let fileName = "keystrokes.\(format == .json ? "json" : "csv")"
        let url = baseURL.appendingPathComponent(fileName)
        
        switch format {
        case .json:
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(events)
            try data.write(to: url)
            
        case .csv:
            var csv = "id,timestamp,keyCode,characters,modifiers,activeApp\n"
            let formatter = ISO8601DateFormatter()
            for event in events {
                let chars = event.characters?.replacingOccurrences(of: ",", with: ";") ?? ""
                let app = event.activeApp?.replacingOccurrences(of: ",", with: ";") ?? ""
                csv += "\(event.id),\(formatter.string(from: event.timestamp)),\(event.keyCode),\"\(chars)\",\(event.modifiers.rawValue),\"\(app)\"\n"
            }
            try csv.write(to: url, atomically: true, encoding: .utf8)
        }
        
        return url
    }
    
    private func exportMouseEvents(_ events: [MouseEvent], format: ExportFormat, to baseURL: URL) throws -> URL {
        let fileName = "mouse_events.\(format == .json ? "json" : "csv")"
        let url = baseURL.appendingPathComponent(fileName)
        
        switch format {
        case .json:
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(events)
            try data.write(to: url)
            
        case .csv:
            var csv = "id,timestamp,eventType,x,y,button,clickCount,activeApp\n"
            let formatter = ISO8601DateFormatter()
            for event in events {
                let button = event.button?.rawValue.description ?? ""
                let clicks = event.clickCount?.description ?? ""
                let app = event.activeApp?.replacingOccurrences(of: ",", with: ";") ?? ""
                csv += "\(event.id),\(formatter.string(from: event.timestamp)),\(event.eventType.rawValue),\(event.x),\(event.y),\(button),\(clicks),\"\(app)\"\n"
            }
            try csv.write(to: url, atomically: true, encoding: .utf8)
        }
        
        return url
    }
    
    private func exportScreenshots(_ events: [ScreenshotEvent], format: ExportFormat, to baseURL: URL) throws -> URL {
        let fileName = "screenshots.\(format == .json ? "json" : "csv")"
        let url = baseURL.appendingPathComponent(fileName)
        
        switch format {
        case .json:
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(events)
            try data.write(to: url)
            
        case .csv:
            var csv = "id,timestamp,filePath,displayID,width,height,activeApp\n"
            let formatter = ISO8601DateFormatter()
            for event in events {
                let app = event.activeApp?.replacingOccurrences(of: ",", with: ";") ?? ""
                csv += "\(event.id),\(formatter.string(from: event.timestamp)),\"\(event.filePath)\",\(event.displayID),\(event.width),\(event.height),\"\(app)\"\n"
            }
            try csv.write(to: url, atomically: true, encoding: .utf8)
        }
        
        return url
    }
    
    private func exportCameraCaptures(_ events: [CameraCaptureEvent], format: ExportFormat, to baseURL: URL) throws -> URL {
        let fileName = "camera_captures.\(format == .json ? "json" : "csv")"
        let url = baseURL.appendingPathComponent(fileName)
        
        switch format {
        case .json:
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(events)
            try data.write(to: url)
            
        case .csv:
            var csv = "id,timestamp,filePath,width,height,deviceName\n"
            let formatter = ISO8601DateFormatter()
            for event in events {
                let device = event.deviceName?.replacingOccurrences(of: ",", with: ";") ?? ""
                csv += "\(event.id),\(formatter.string(from: event.timestamp)),\"\(event.filePath)\",\(event.width),\(event.height),\"\(device)\"\n"
            }
            try csv.write(to: url, atomically: true, encoding: .utf8)
        }
        
        return url
    }
    
    private func exportAppHistory(_ events: [AppHistoryEvent], format: ExportFormat, to baseURL: URL) throws -> URL {
        let fileName = "app_history.\(format == .json ? "json" : "csv")"
        let url = baseURL.appendingPathComponent(fileName)
        
        switch format {
        case .json:
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(events)
            try data.write(to: url)
            
        case .csv:
            var csv = "id,timestamp,bundleIdentifier,appName,windowTitle,eventType,duration\n"
            let formatter = ISO8601DateFormatter()
            for event in events {
                let window = event.windowTitle?.replacingOccurrences(of: ",", with: ";") ?? ""
                let duration = event.duration?.description ?? ""
                csv += "\(event.id),\(formatter.string(from: event.timestamp)),\"\(event.bundleIdentifier)\",\"\(event.appName)\",\"\(window)\",\(event.eventType.rawValue),\(duration)\n"
            }
            try csv.write(to: url, atomically: true, encoding: .utf8)
        }
        
        return url
    }
    
    private func exportFileAccess(_ events: [FileAccessEvent], format: ExportFormat, to baseURL: URL) throws -> URL {
        let fileName = "file_access.\(format == .json ? "json" : "csv")"
        let url = baseURL.appendingPathComponent(fileName)
        
        switch format {
        case .json:
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(events)
            try data.write(to: url)
            
        case .csv:
            var csv = "id,timestamp,filePath,fileName,eventType,appBundleIdentifier\n"
            let formatter = ISO8601DateFormatter()
            for event in events {
                let app = event.appBundleIdentifier?.replacingOccurrences(of: ",", with: ";") ?? ""
                csv += "\(event.id),\(formatter.string(from: event.timestamp)),\"\(event.filePath)\",\"\(event.fileName)\",\(event.eventType.rawValue),\"\(app)\"\n"
            }
            try csv.write(to: url, atomically: true, encoding: .utf8)
        }
        
        return url
    }
    
    private func exportClipboard(_ events: [ClipboardEvent], format: ExportFormat, to baseURL: URL) throws -> URL {
        let fileName = "clipboard.\(format == .json ? "json" : "csv")"
        let url = baseURL.appendingPathComponent(fileName)
        
        switch format {
        case .json:
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(events)
            try data.write(to: url)
            
        case .csv:
            var csv = "id,timestamp,contentType,textContent,dataSize,sourceApp\n"
            let formatter = ISO8601DateFormatter()
            for event in events {
                let text = event.textContent?.replacingOccurrences(of: ",", with: ";").replacingOccurrences(of: "\n", with: " ") ?? ""
                let app = event.sourceApp?.replacingOccurrences(of: ",", with: ";") ?? ""
                csv += "\(event.id),\(formatter.string(from: event.timestamp)),\(event.contentType.rawValue),\"\(text)\",\(event.dataSize),\"\(app)\"\n"
            }
            try csv.write(to: url, atomically: true, encoding: .utf8)
        }
        
        return url
    }
}
