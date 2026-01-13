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
    private var hasRequestedAccessibility = false
    private var hasRequestedScreenRecording = false
    private var hasRequestedCamera = false
    
    private init() {
        checkAllPermissions()
        startPeriodicCheck()
    }
    
    private func startPeriodicCheck() {
        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
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
        guard !accessibilityGranted && !isRequestingAccessibility && !hasRequestedAccessibility else { return }
        isRequestingAccessibility = true
        hasRequestedAccessibility = true
        
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.isRequestingAccessibility = false
        }
    }
    
    func checkScreenRecordingPermission() {
        // CGPreflightScreenCaptureAccess is more reliable for checking permission status
        screenRecordingGranted = CGPreflightScreenCaptureAccess()
    }
    
    func requestScreenRecordingPermission() {
        guard !screenRecordingGranted && !isRequestingScreenRecording && !hasRequestedScreenRecording else { return }
        isRequestingScreenRecording = true
        hasRequestedScreenRecording = true
        
        CGRequestScreenCaptureAccess()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.checkScreenRecordingPermission()
            self?.isRequestingScreenRecording = false
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
        guard !cameraGranted && !isRequestingCamera && !hasRequestedCamera else { return }
        isRequestingCamera = true
        hasRequestedCamera = true
        
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
    
    func openSystemPreferencesInputMonitoring() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
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
    
    func resetRequestFlags() {
        hasRequestedAccessibility = false
        hasRequestedScreenRecording = false
        hasRequestedCamera = false
    }
    
    deinit {
        permissionCheckTimer?.invalidate()
    }
}
