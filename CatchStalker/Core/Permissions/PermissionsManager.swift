import Foundation
import Cocoa
import ApplicationServices
import AVFoundation

final class PermissionsManager: ObservableObject {
    static let shared = PermissionsManager()
    
    @Published var accessibilityGranted = false
    @Published var screenRecordingGranted = false
    @Published var cameraGranted = false
    
    private init() {
        checkAllPermissions()
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
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.checkAccessibilityPermission()
        }
    }
    
    func checkScreenRecordingPermission() {
        screenRecordingGranted = CGPreflightScreenCaptureAccess()
    }
    
    func requestScreenRecordingPermission() {
        CGRequestScreenCaptureAccess()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.checkScreenRecordingPermission()
        }
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
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                self?.cameraGranted = granted
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
}
