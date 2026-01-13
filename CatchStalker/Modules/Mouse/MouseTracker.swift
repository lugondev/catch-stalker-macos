import Foundation
import Cocoa

final class MouseTracker: ObservableObject {
    static let shared = MouseTracker()
    
    @Published var isRunning = false
    @Published var lastEvent: MouseEvent?
    
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var lastMoveTime: Date = Date()
    private let moveSampleInterval: TimeInterval = 0.1
    
    private init() {}
    
    func start() {
        guard !isRunning else { return }
        guard PermissionsManager.shared.accessibilityGranted else { return }
        
        let eventMask = (1 << CGEventType.mouseMoved.rawValue) |
                        (1 << CGEventType.leftMouseDown.rawValue) |
                        (1 << CGEventType.leftMouseUp.rawValue) |
                        (1 << CGEventType.rightMouseDown.rawValue) |
                        (1 << CGEventType.rightMouseUp.rawValue) |
                        (1 << CGEventType.otherMouseDown.rawValue) |
                        (1 << CGEventType.otherMouseUp.rawValue) |
                        (1 << CGEventType.scrollWheel.rawValue) |
                        (1 << CGEventType.leftMouseDragged.rawValue) |
                        (1 << CGEventType.rightMouseDragged.rawValue)
        
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { proxy, type, event, refcon in
                return MouseTracker.handleEvent(proxy: proxy, type: type, event: event, refcon: refcon)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("Failed to create mouse event tap")
            return
        }
        
        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        
        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            isRunning = true
        }
    }
    
    func stop() {
        guard isRunning else { return }
        
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        
        eventTap = nil
        runLoopSource = nil
        isRunning = false
    }
    
    private static func handleEvent(
        proxy: CGEventTapProxy,
        type: CGEventType,
        event: CGEvent,
        refcon: UnsafeMutableRawPointer?
    ) -> Unmanaged<CGEvent>? {
        guard let refcon = refcon else { return Unmanaged.passRetained(event) }
        let tracker = Unmanaged<MouseTracker>.fromOpaque(refcon).takeUnretainedValue()
        
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = tracker.eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passRetained(event)
        }
        
        let location = event.location
        let activeApp = NSWorkspace.shared.frontmostApplication?.localizedName
        
        var eventType: MouseEventType
        var button: MouseButton?
        var clickCount: Int?
        
        switch type {
        case .mouseMoved:
            let now = Date()
            if now.timeIntervalSince(tracker.lastMoveTime) < tracker.moveSampleInterval {
                return Unmanaged.passRetained(event)
            }
            tracker.lastMoveTime = now
            eventType = .move
            
        case .leftMouseDown, .leftMouseUp:
            eventType = .leftClick
            button = .left
            clickCount = Int(event.getIntegerValueField(.mouseEventClickState))
            
        case .rightMouseDown, .rightMouseUp:
            eventType = .rightClick
            button = .right
            clickCount = Int(event.getIntegerValueField(.mouseEventClickState))
            
        case .otherMouseDown, .otherMouseUp:
            eventType = .middleClick
            button = .middle
            clickCount = Int(event.getIntegerValueField(.mouseEventClickState))
            
        case .scrollWheel:
            eventType = .scroll
            
        case .leftMouseDragged, .rightMouseDragged:
            eventType = .drag
            
        default:
            return Unmanaged.passRetained(event)
        }
        
        let mouseEvent = MouseEvent(
            eventType: eventType,
            x: location.x,
            y: location.y,
            button: button,
            clickCount: clickCount,
            activeApp: activeApp
        )
        
        DispatchQueue.main.async {
            tracker.lastEvent = mouseEvent
        }
        
        DatabaseManager.shared.insertMouseEvent(mouseEvent)
        
        return Unmanaged.passRetained(event)
    }
}
