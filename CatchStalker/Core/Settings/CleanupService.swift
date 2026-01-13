import Foundation

final class CleanupService {
    static let shared = CleanupService()
    
    private var timer: Timer?
    
    private init() {}
    
    func startAutoCleanup() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            self?.performCleanup()
        }
        performCleanup()
    }
    
    func stopAutoCleanup() {
        timer?.invalidate()
        timer = nil
    }
    
    func performCleanup() {
        let settings = SettingsManager.shared.settings
        guard settings.autoDeleteDays > 0 else {
            print("[CleanupService] Auto-delete disabled (set to Never)")
            return
        }
        
        guard let cutoffDate = Calendar.current.date(byAdding: .day, value: -settings.autoDeleteDays, to: Date()) else {
            print("[CleanupService] Failed to calculate cutoff date")
            return
        }
        
        print("[CleanupService] Starting cleanup for data older than \(cutoffDate)")
        
        DatabaseManager.shared.deleteOldData(olderThan: cutoffDate)
        
        let screenshotCount = cleanupOldFiles(in: settings.screenshotStoragePath, olderThan: cutoffDate)
        let cameraCount = cleanupOldFiles(in: settings.cameraStoragePath, olderThan: cutoffDate)
        
        print("[CleanupService] Cleanup completed - Deleted \(screenshotCount) screenshots, \(cameraCount) camera captures")
    }
    
    @discardableResult
    private func cleanupOldFiles(in directory: String, olderThan date: Date) -> Int {
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(atPath: directory) else { return 0 }
        
        var deletedCount = 0
        for file in files {
            let filePath = (directory as NSString).appendingPathComponent(file)
            guard let attributes = try? fileManager.attributesOfItem(atPath: filePath),
                  let creationDate = attributes[.creationDate] as? Date else { continue }
            
            if creationDate < date {
                if (try? fileManager.removeItem(atPath: filePath)) != nil {
                    deletedCount += 1
                }
            }
        }
        
        return deletedCount
    }
    
    func getStorageUsage() -> Int64 {
        let settings = SettingsManager.shared.settings
        var totalSize: Int64 = 0
        
        totalSize += directorySize(settings.screenshotStoragePath)
        totalSize += directorySize(settings.cameraStoragePath)
        
        return totalSize
    }
    
    private func directorySize(_ path: String) -> Int64 {
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
