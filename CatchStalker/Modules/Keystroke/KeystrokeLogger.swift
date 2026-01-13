import Foundation
import Cocoa
import Carbon

final class KeystrokeLogger: ObservableObject {
    static let shared = KeystrokeLogger()
    
    @Published var isRunning = false
    @Published var lastKeystroke: KeystrokeEvent?
    
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    
    private init() {}
    
    func start() {
        guard !isRunning else { return }
        guard PermissionsManager.shared.accessibilityGranted else {
            PermissionsManager.shared.requestAccessibilityPermission()
            return
        }
        
        let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
        
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { proxy, type, event, refcon in
                return KeystrokeLogger.handleEvent(proxy: proxy, type: type, event: event, refcon: refcon)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("Failed to create event tap")
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
        let logger = Unmanaged<KeystrokeLogger>.fromOpaque(refcon).takeUnretainedValue()
        
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = logger.eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passRetained(event)
        }
        
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        
        var modifiers = KeyModifiers(rawValue: 0)
        if flags.contains(.maskShift) { modifiers.insert(.shift) }
        if flags.contains(.maskControl) { modifiers.insert(.control) }
        if flags.contains(.maskAlternate) { modifiers.insert(.option) }
        if flags.contains(.maskCommand) { modifiers.insert(.command) }
        if flags.contains(.maskAlphaShift) { modifiers.insert(.capsLock) }
        
        var characters: String?
        if type == .keyDown {
            if let nsEvent = NSEvent(cgEvent: event) {
                characters = nsEvent.characters
            }
        }
        
        let activeApp = NSWorkspace.shared.frontmostApplication?.localizedName
        
        let keystrokeEvent = KeystrokeEvent(
            keyCode: Int(keyCode),
            characters: characters,
            modifiers: modifiers,
            activeApp: activeApp
        )
        
        DispatchQueue.main.async {
            logger.lastKeystroke = keystrokeEvent
        }
        
        DatabaseManager.shared.insertKeystroke(keystrokeEvent)
        
        return Unmanaged.passRetained(event)
    }
    
    func getKeyName(keyCode: Int) -> String {
        let keyMap: [Int: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
            11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T", 18: "1", 19: "2",
            20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8",
            29: "0", 30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "Return",
            37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/",
            45: "N", 46: "M", 47: ".", 48: "Tab", 49: "Space", 50: "`", 51: "Delete",
            53: "Escape", 55: "Command", 56: "Shift", 57: "CapsLock", 58: "Option",
            59: "Control", 60: "RightShift", 61: "RightOption", 62: "RightControl",
            63: "Function", 64: "F17", 65: "Keypad.", 67: "Keypad*", 69: "Keypad+",
            71: "KeypadClear", 75: "Keypad/", 76: "KeypadEnter", 78: "Keypad-",
            79: "F18", 80: "F19", 81: "Keypad=", 82: "Keypad0", 83: "Keypad1",
            84: "Keypad2", 85: "Keypad3", 86: "Keypad4", 87: "Keypad5", 88: "Keypad6",
            89: "Keypad7", 91: "Keypad8", 92: "Keypad9", 96: "F5", 97: "F6", 98: "F7",
            99: "F3", 100: "F8", 101: "F9", 103: "F11", 105: "F13", 106: "F16",
            107: "F14", 109: "F10", 111: "F12", 113: "F15", 114: "Help", 115: "Home",
            116: "PageUp", 117: "ForwardDelete", 118: "F4", 119: "End", 120: "F2",
            121: "PageDown", 122: "F1", 123: "LeftArrow", 124: "RightArrow",
            125: "DownArrow", 126: "UpArrow"
        ]
        return keyMap[keyCode] ?? "Key\(keyCode)"
    }
}
