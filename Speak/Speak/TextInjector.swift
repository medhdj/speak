import Cocoa

/// Injects text into the currently focused UI element using CGEvent
/// Unicode keystroke simulation — works in Terminal, browsers, any app.
enum TextInjector {

    /// Custom source-state ID so HotKeyMonitor can identify and ignore our synthetic events.
    /// Value chosen to avoid collision with system IDs (0 = private, 1 = combined, 2 = hid).
    static let sourceStateID = CGEventSourceStateID(rawValue: 0)!

    /// Dispatch queue dedicated to keystroke injection (avoids blocking the main thread).
    private static let injectionQueue = DispatchQueue(label: "com.speak.textinjector", qos: .userInteractive)

    static func inject(text: String, completion: (() -> Void)? = nil) {
        injectionQueue.async {
            performInjection(text: text)
            if let completion { completion() }
        }
    }

    private static func performInjection(text: String) {
        // Use a private event source so synthetic events carry NO residual modifier flags
        // and can be distinguished from real user input by their sourceStateID.
        guard let source = CGEventSource(stateID: sourceStateID) else { return }

        for scalar in text.unicodeScalars {
            // Backspace (\u{8}) → send Delete key (virtualKey 51)
            if scalar.value == 0x08 {
                if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 51, keyDown: true) {
                    keyDown.flags = CGEventFlags()
                    keyDown.post(tap: .cghidEventTap)
                }
                if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 51, keyDown: false) {
                    keyUp.flags = CGEventFlags()
                    keyUp.post(tap: .cghidEventTap)
                }
                usleep(3000)
                continue
            }

            var uchar = UniChar(scalar.value & 0xFFFF)

            if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true) {
                keyDown.keyboardSetUnicodeString(stringLength: 1, unicodeString: &uchar)
                keyDown.flags = CGEventFlags()   // explicitly clear all modifier flags
                keyDown.post(tap: .cghidEventTap)
            }
            if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) {
                keyUp.keyboardSetUnicodeString(stringLength: 1, unicodeString: &uchar)
                keyUp.flags = CGEventFlags()
                keyUp.post(tap: .cghidEventTap)
            }
            usleep(3000)
        }
    }
}
