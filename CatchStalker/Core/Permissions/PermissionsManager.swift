import Foundation
import Cocoa
import ApplicationServices
import AVFoundation
import ScreenCaptureKit

final class PermissionsManager: ObservableObject {
    static let shared = PermissionsManager()
    
    @Published var accessibilityGranted = false
    @Published var screenRecordingGranted = false
    @Published var cameraGranted = false
    
    private var permissionCheckTimer: Timer?
    private var isRequestingAccessibility = false
    private var isRequestingScreenRecording = false
    private var isRequestingCamera = false
    
    private init() {
        checkAllPermissions()
        startPeriodicCheck()
    }
    
    private func startPeriodicCheck() {
        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.checkAllPermissions()
        }
    }
    
    func checkAllPermissions() {
        checkAccessibilityPermission()
        checkScreenRecordingPermission()
        checkCameraPermission()
    }
    
    func checkAccessibilityPermission() {
        accessibilityGranted = AXIsProcessTrusted()
    }
    
    func requestAccessibilityPermission() {
        guard !accessibilityGranted && !isRequestingAccessibility else { return }
        isRequestingAccessibility = true
        
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.isRequestingAccessibility = false
        }
    }
    
    func checkScreenRecordingPermission() {
        if #available(macOS 12.3, *) {
            Task { @MainActor in
                do {
                    let content = try await SCShareableContent.current
                    self.screenRecordingGranted = !content.displays.isEmpty
                } catch {
                    // SCShareableContent throws when permission is denied
                    self.screenRecordingGranted = false
                }
            }
        } else {
            screenRecordingGranted = CGPreflightScreenCaptureAccess()
        }
    }
    
    func requestScreenRecordingPermission() {
        guard !screenRecordingGranted && !isRequestingScreenRecording else { return }
        isRequestingScreenRecording = true
        
        if #available(macOS 12.3, *) {
            Task { @MainActor in
                do {
                    _ = try await SCShareableContent.current
                    checkScreenRecordingPermission()
                    
                    if !self.screenRecordingGranted {
                        showScreenRecordingPermissionAlert()
                    }
                } catch {
                    showScreenRecordingPermissionAlert()
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
                    self?.isRequestingScreenRecording = false
                }
            }
        } else {
            CGRequestScreenCaptureAccess()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.checkScreenRecordingPermission()
                
                if self?.screenRecordingGranted == false {
                    self?.showScreenRecordingPermissionAlert()
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                    self?.isRequestingScreenRecording = false
                }
            }
        }
    }
    
    private func showScreenRecordingPermissionAlert() {
        guard !isRequestingScreenRecording else { return }
        
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Screen Recording Permission Required"
            alert.informativeText = "CatchStalker needs Screen Recording permission to capture screenshots.\n\nSteps:\n1. Click 'Open System Settings' below\n2. Enable CatchStalker in the list\n3. Restart CatchStalker app"
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Later")
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                self.openSystemPreferencesScreenRecording()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    let restartAlert = NSAlert()
                    restartAlert.messageText = "Restart Required"
                    restartAlert.informativeText = "After enabling Screen Recording permission, you need to restart CatchStalker for changes to take effect."
                    restartAlert.alertStyle = .informational
                    restartAlert.addButton(withTitle: "Restart Now")
                    restartAlert.addButton(withTitle: "Restart Later")
                    
                    if restartAlert.runModal() == .alertFirstButtonReturn {
                        self.restartApp()
                    }
                }
            }
        }
    }
    
    private func restartApp() {
        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", "sleep 0.5; open '\(Bundle.main.bundlePath)'"]
        task.launch()
        NSApplication.shared.terminate(nil)
    }
    
    func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraGranted = true
        case .notDetermined, .denied, .restricted:
            cameraGranted = false
        @unknown default:
            cameraGranted = false
        }
    }
    
    func requestCameraPermission() {
        guard !cameraGranted && !isRequestingCamera else { return }
        isRequestingCamera = true
        
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                self?.cameraGranted = granted
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    self?.isRequestingCamera = false
                }
            }
        }
    }
    
    func openSystemPreferencesAccessibility() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
    
    func openSystemPreferencesScreenRecording() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
    
    func openSystemPreferencesCamera() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
            NSWorkspace.shared.open(url)
        }
    }
    
    var allPermissionsGranted: Bool {
        accessibilityGranted && screenRecordingGranted && cameraGranted
    }
    
    deinit {
        permissionCheckTimer?.invalidate()
    }
}
