import Foundation
import AppKit

final class FileAccessMonitor: ObservableObject {
    static let shared = FileAccessMonitor()
    
    @Published var isRunning = false
    @Published var lastEvent: FileAccessEvent?
    
    private var streamRef: FSEventStreamRef?
    private var monitoredPaths: [String] = []
    
    private init() {}
    
    func start() {
        guard !isRunning else { return }
        
        monitoredPaths = SettingsManager.shared.settings.monitoredPaths
        guard !monitoredPaths.isEmpty else { return }
        
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        
        let callback: FSEventStreamCallback = { streamRef, clientCallBackInfo, numEvents, eventPaths, eventFlags, eventIds in
            guard let clientCallBackInfo = clientCallBackInfo else { return }
            let monitor = Unmanaged<FileAccessMonitor>.fromOpaque(clientCallBackInfo).takeUnretainedValue()
            
            guard let paths = unsafeBitCast(eventPaths, to: NSArray.self) as? [String] else { return }
            
            for i in 0..<numEvents {
                let path = paths[i]
                let flags = eventFlags[i]
                monitor.handleFileEvent(path: path, flags: flags)
            }
        }
        
        let pathsToWatch = monitoredPaths as CFArray
        
        streamRef = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            1.0,
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes)
        )
        
        if let stream = streamRef {
            FSEventStreamSetDispatchQueue(stream, DispatchQueue.global(qos: .utility))
            FSEventStreamStart(stream)
            isRunning = true
        }
    }
    
    func stop() {
        guard isRunning, let stream = streamRef else { return }
        
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        
        streamRef = nil
        isRunning = false
    }
    
    func updateMonitoredPaths(_ paths: [String]) {
        let wasRunning = isRunning
        if wasRunning { stop() }
        SettingsManager.shared.settings.monitoredPaths = paths
        if wasRunning { start() }
    }
    
    private func handleFileEvent(path: String, flags: FSEventStreamEventFlags) {
        let eventType: FileEventType
        
        if flags & UInt32(kFSEventStreamEventFlagItemCreated) != 0 {
            eventType = .created
        } else if flags & UInt32(kFSEventStreamEventFlagItemRemoved) != 0 {
            eventType = .deleted
        } else if flags & UInt32(kFSEventStreamEventFlagItemRenamed) != 0 {
            eventType = .renamed
        } else if flags & UInt32(kFSEventStreamEventFlagItemModified) != 0 {
            eventType = .modified
        } else {
            return
        }
        
        let fileName = (path as NSString).lastPathComponent
        let activeApp = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        
        let event = FileAccessEvent(
            filePath: path,
            fileName: fileName,
            eventType: eventType,
            appBundleIdentifier: activeApp
        )
        
        DispatchQueue.main.async { [weak self] in
            self?.lastEvent = event
        }
        
        DatabaseManager.shared.insertFileAccess(event)
    }
}
