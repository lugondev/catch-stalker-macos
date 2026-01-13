import Foundation
import Cocoa
import ScreenCaptureKit

final class ScreenshotCapture: NSObject, ObservableObject {
    static let shared = ScreenshotCapture()
    
    @Published var isRunning = false
    @Published var lastCapture: ScreenshotEvent?
    
    private var timer: Timer?
    
    private override init() {
        super.init()
    }
    
    func start() {
        guard !isRunning else { return }
        guard PermissionsManager.shared.screenRecordingGranted else { return }
        
        let interval = SettingsManager.shared.settings.screenshotInterval
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.captureAllDisplays()
        }
        isRunning = true
        captureAllDisplays()
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
    }
    
    func updateInterval(_ interval: TimeInterval) {
        guard isRunning else { return }
        stop()
        SettingsManager.shared.settings.screenshotInterval = interval
        start()
    }
    
    private func captureAllDisplays() {
        if #available(macOS 14.0, *) {
            captureWithScreenCaptureKit()
        } else {
            captureWithCGDisplay()
        }
    }
    
    @available(macOS 14.0, *)
    private func captureWithScreenCaptureKit() {
        Task {
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                
                for display in content.displays {
                    await captureDisplayModern(display)
                }
            } catch {
                print("Failed to get shareable content: \(error)")
                captureWithCGDisplay()
            }
        }
    }
    
    @available(macOS 14.0, *)
    private func captureDisplayModern(_ display: SCDisplay) async {
        let filter = SCContentFilter(display: display, excludingWindows: [])
        
        let config = SCStreamConfiguration()
        config.width = display.width
        config.height = display.height
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = true
        
        do {
            let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
            await MainActor.run {
                saveScreenshot(image: image, displayID: UInt32(display.displayID))
            }
        } catch {
            print("ScreenCaptureKit capture failed for display \(display.displayID): \(error)")
        }
    }
    
    private func captureWithCGDisplay() {
        let onlineDisplays = UnsafeMutablePointer<CGDirectDisplayID>.allocate(capacity: 16)
        defer { onlineDisplays.deallocate() }
        
        var displayCount: UInt32 = 0
        CGGetOnlineDisplayList(16, onlineDisplays, &displayCount)
        
        for i in 0..<Int(displayCount) {
            let displayID = onlineDisplays[i]
            captureDisplayLegacy(displayID: displayID)
        }
    }
    
    private func captureDisplayLegacy(displayID: CGDirectDisplayID) {
        guard let image = CGDisplayCreateImage(displayID) else { return }
        saveScreenshot(image: image, displayID: displayID)
    }
    
    private func saveScreenshot(image: CGImage, displayID: UInt32) {
        let timestamp = Date()
        let fileName = "screenshot_\(displayID)_\(Int(timestamp.timeIntervalSince1970 * 1000)).png"
        let storagePath = SettingsManager.shared.settings.screenshotStoragePath
        let filePath = (storagePath as NSString).appendingPathComponent(fileName)
        
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: storagePath) {
            try? fileManager.createDirectory(atPath: storagePath, withIntermediateDirectories: true)
        }
        
        let bitmapRep = NSBitmapImageRep(cgImage: image)
        guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else { return }
        
        do {
            try pngData.write(to: URL(fileURLWithPath: filePath))
            
            let activeApp = NSWorkspace.shared.frontmostApplication?.localizedName
            let event = ScreenshotEvent(
                timestamp: timestamp,
                filePath: filePath,
                displayID: displayID,
                width: image.width,
                height: image.height,
                activeApp: activeApp
            )
            
            DispatchQueue.main.async { [weak self] in
                self?.lastCapture = event
            }
            
            DatabaseManager.shared.insertScreenshot(event)
        } catch {
            print("Failed to save screenshot: \(error)")
        }
    }
}
