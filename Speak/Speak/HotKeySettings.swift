import Foundation
import Carbon

/// Persisted hotkey configuration.
/// Stores the key code and a bitmask of CGEventFlags modifiers.
class HotKeySettings: ObservableObject {

    static let shared = HotKeySettings()

    // MARK: - Persisted values

    /// CGKeyCode of the trigger key (default: 49 = Space)
    @Published var keyCode: CGKeyCode {
        didSet { UserDefaults.standard.set(Int(keyCode), forKey: "hotkey.keyCode") }
    }

    /// Whether Command (⌘) is required
    @Published var modCommand: Bool {
        didSet { UserDefaults.standard.set(modCommand, forKey: "hotkey.modCommand") }
    }

    /// Whether Shift (⇧) is required
    @Published var modShift: Bool {
        didSet { UserDefaults.standard.set(modShift, forKey: "hotkey.modShift") }
    }

    /// Whether Option (⌥) is required
    @Published var modOption: Bool {
        didSet { UserDefaults.standard.set(modOption, forKey: "hotkey.modOption") }
    }

    /// Whether Control (⌃) is required
    @Published var modControl: Bool {
        didSet { UserDefaults.standard.set(modControl, forKey: "hotkey.modControl") }
    }

    /// Speech recognition locale identifier (e.g. "fr-FR", "en-US").
    /// Empty string means use system default locale.
    @Published var recognitionLocale: String {
        didSet { UserDefaults.standard.set(recognitionLocale, forKey: "recognitionLocale") }
    }

    private init() {
        let ud = UserDefaults.standard
        keyCode  = CGKeyCode(ud.object(forKey: "hotkey.keyCode") as? Int ?? 49)
        modCommand  = ud.object(forKey: "hotkey.modCommand")  as? Bool ?? true
        modShift    = ud.object(forKey: "hotkey.modShift")    as? Bool ?? true
        modOption   = ud.object(forKey: "hotkey.modOption")   as? Bool ?? false
        modControl  = ud.object(forKey: "hotkey.modControl")  as? Bool ?? false
        recognitionLocale = ud.object(forKey: "recognitionLocale") as? String ?? ""
    }

    // MARK: - Helpers

    var cgEventFlags: CGEventFlags {
        var flags: CGEventFlags = []
        if modCommand { flags.insert(.maskCommand) }
        if modShift   { flags.insert(.maskShift) }
        if modOption  { flags.insert(.maskAlternate) }
        if modControl { flags.insert(.maskControl) }
        return flags
    }

    /// Human-readable shortcut string e.g. "⌘⇧Space"
    var displayString: String {
        var parts: [String] = []
        if modControl { parts.append("⌃") }
        if modOption  { parts.append("⌥") }
        if modShift   { parts.append("⇧") }
        if modCommand { parts.append("⌘") }
        parts.append(keyDisplayName(for: keyCode))
        return parts.joined()
    }

    // MARK: - Available keys for the picker

    static let availableKeys: [(label: String, keyCode: CGKeyCode)] = [
        ("Space", 49),
        ("A", 0), ("B", 11), ("C", 8), ("D", 2), ("E", 14), ("F", 3),
        ("G", 5), ("H", 4), ("I", 34), ("J", 38), ("K", 40), ("L", 37),
        ("M", 46), ("N", 45), ("O", 31), ("P", 35), ("Q", 12), ("R", 15),
        ("S", 1), ("T", 17), ("U", 32), ("V", 9), ("W", 13), ("X", 7),
        ("Y", 16), ("Z", 6),
        ("F1", 122), ("F2", 120), ("F3", 99), ("F4", 118),
        ("F5", 96), ("F6", 97), ("F7", 98), ("F8", 100),
    ]

    private func keyDisplayName(for code: CGKeyCode) -> String {
        HotKeySettings.availableKeys.first(where: { $0.keyCode == code })?.label ?? "?\(code)"
    }
}
