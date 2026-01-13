import Foundation
import Cocoa

final class ClipboardMonitor: ObservableObject {
    static let shared = ClipboardMonitor()
    
    @Published var isRunning = false
    @Published var lastEvent: ClipboardEvent?
    @Published var history: [ClipboardEvent] = []
    
    private var timer: Timer?
    private var lastChangeCount: Int = 0
    
    private init() {
        lastChangeCount = NSPasteboard.general.changeCount
    }
    
    func start() {
        guard !isRunning else { return }
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
        isRunning = true
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
    }
    
    private func checkClipboard() {
        let pasteboard = NSPasteboard.general
        let currentChangeCount = pasteboard.changeCount
        
        guard currentChangeCount != lastChangeCount else { return }
        lastChangeCount = currentChangeCount
        
        let contentType: ClipboardContentType
        var textContent: String?
        var dataSize: Int = 0
        
        if let string = pasteboard.string(forType: .string) {
            contentType = .text
            textContent = string
            dataSize = string.utf8.count
        } else if let rtf = pasteboard.data(forType: .rtf) {
            contentType = .rtf
            dataSize = rtf.count
            if let attributedString = try? NSAttributedString(data: rtf, options: [:], documentAttributes: nil) {
                textContent = attributedString.string
            }
        } else if let html = pasteboard.data(forType: .html) {
            contentType = .html
            dataSize = html.count
            textContent = String(data: html, encoding: .utf8)
        } else if pasteboard.data(forType: .png) != nil || pasteboard.data(forType: .tiff) != nil {
            contentType = .image
            if let pngData = pasteboard.data(forType: .png) {
                dataSize = pngData.count
            } else if let tiffData = pasteboard.data(forType: .tiff) {
                dataSize = tiffData.count
            }
        } else if pasteboard.data(forType: .fileURL) != nil {
            contentType = .file
            if let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL] {
                textContent = urls.map { $0.path }.joined(separator: "\n")
                dataSize = textContent?.utf8.count ?? 0
            }
        } else {
            contentType = .other
            for type in pasteboard.types ?? [] {
                if let data = pasteboard.data(forType: type) {
                    dataSize = max(dataSize, data.count)
                }
            }
        }
        
        let sourceApp = NSWorkspace.shared.frontmostApplication?.localizedName
        
        let event = ClipboardEvent(
            contentType: contentType,
            textContent: textContent,
            dataSize: dataSize,
            sourceApp: sourceApp
        )
        
        DispatchQueue.main.async { [weak self] in
            self?.lastEvent = event
            self?.history.insert(event, at: 0)
            if self?.history.count ?? 0 > 100 {
                self?.history.removeLast()
            }
        }
        
        DatabaseManager.shared.insertClipboard(event)
    }
    
    func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
