import Foundation
import AVFoundation
import Cocoa

final class CameraCapture: NSObject, ObservableObject {
    static let shared = CameraCapture()
    
    @Published var isRunning = false
    @Published var lastCapture: CameraCaptureEvent?
    @Published var availableCameras: [AVCaptureDevice] = []
    
    private var captureSession: AVCaptureSession?
    private var photoOutput: AVCapturePhotoOutput?
    private var timer: Timer?
    private var currentDeviceName: String?
    
    private override init() {
        super.init()
        refreshCameraList()
    }
    
    func refreshCameraList() {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .externalUnknown],
            mediaType: .video,
            position: .unspecified
        )
        availableCameras = discoverySession.devices
    }
    
    func start(camera: AVCaptureDevice? = nil) {
        guard !isRunning else { return }
        guard PermissionsManager.shared.cameraGranted else {
            PermissionsManager.shared.requestCameraPermission()
            return
        }
        
        let selectedCamera = camera ?? AVCaptureDevice.default(for: .video)
        guard let device = selectedCamera else {
            print("No camera available")
            return
        }
        
        currentDeviceName = device.localizedName
        
        do {
            let session = AVCaptureSession()
            session.sessionPreset = .photo
            
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
            }
            
            let output = AVCapturePhotoOutput()
            if session.canAddOutput(output) {
                session.addOutput(output)
            }
            
            captureSession = session
            photoOutput = output
            
            DispatchQueue.global(qos: .userInitiated).async {
                session.startRunning()
            }
            
            let interval = SettingsManager.shared.settings.cameraInterval
            timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                self?.capturePhoto()
            }
            
            isRunning = true
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.capturePhoto()
            }
            
        } catch {
            print("Failed to setup camera: \(error)")
        }
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
        
        captureSession?.stopRunning()
        captureSession = nil
        photoOutput = nil
        
        isRunning = false
    }
    
    func updateInterval(_ interval: TimeInterval) {
        guard isRunning else { return }
        timer?.invalidate()
        SettingsManager.shared.settings.cameraInterval = interval
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.capturePhoto()
        }
    }
    
    private func capturePhoto() {
        guard let output = photoOutput, captureSession?.isRunning == true else { return }
        
        let settings = AVCapturePhotoSettings()
        output.capturePhoto(with: settings, delegate: self)
    }
}

extension CameraCapture: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil, let imageData = photo.fileDataRepresentation() else {
            print("Camera capture error: \(error?.localizedDescription ?? "unknown")")
            return
        }
        
        let timestamp = Date()
        let fileName = "camera_\(Int(timestamp.timeIntervalSince1970 * 1000)).jpg"
        let storagePath = SettingsManager.shared.settings.cameraStoragePath
        let filePath = (storagePath as NSString).appendingPathComponent(fileName)
        
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: storagePath) {
            try? fileManager.createDirectory(atPath: storagePath, withIntermediateDirectories: true)
        }
        
        do {
            try imageData.write(to: URL(fileURLWithPath: filePath))
            
            var width = 0
            var height = 0
            if let image = NSImage(data: imageData) {
                width = Int(image.size.width)
                height = Int(image.size.height)
            }
            
            let event = CameraCaptureEvent(
                timestamp: timestamp,
                filePath: filePath,
                width: width,
                height: height,
                deviceName: currentDeviceName
            )
            
            DispatchQueue.main.async { [weak self] in
                self?.lastCapture = event
            }
            
            DatabaseManager.shared.insertCameraCapture(event)
        } catch {
            print("Failed to save camera capture: \(error)")
        }
    }
}
