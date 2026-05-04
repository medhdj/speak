# Speak

A lightweight macOS menu bar app that transcribes your voice and types it directly into any text field — in real time.

Press a hotkey, speak, and watch the text appear wherever your cursor is. Works in any app: browser, terminal, editor, notes.
<img width="352" height="301" alt="Capture d’écran 2026-05-03 à 12 57 25" src="https://github.com/user-attachments/assets/f491c55f-06c3-43a3-9d4e-83a3dbce8abe" />
<img width="352" height="301" alt="Capture d’écran 2026-05-03 à 12 57 36" src="https://github.com/user-attachments/assets/39c6a373-5911-4829-bc3e-de4784a61c5d" />



https://github.com/user-attachments/assets/05701fb7-4435-4aac-8f81-34ecb613fc31






## Requirements

- macOS 13.0 or later
- Apple Silicon (arm64)

## Installation

### From DMG

1. Open `Speak.dmg`
2. Run `Install Speak.command` — it handles everything (removes previous installs, copies to `/Applications`, opens the app)
3. Grant the three permissions when prompted (see [Permissions](#permissions))

### Uninstall

Run `Uninstall Speak.command` from the DMG, or manually:

```bash
pkill -x Speak
rm -rf /Applications/Speak.app
```

Then remove Speak from **System Settings > Privacy & Security > Accessibility**.

## Permissions

Speak needs three permissions to work. It will prompt you on first launch.

| Permission | Why |
|---|---|
| **Speech Recognition** | Transcribes your voice using Apple's `SFSpeechRecognizer` |
| **Microphone** | Captures audio from your mic via `AVAudioEngine` |
| **Accessibility** | Required for the global hotkey (`CGEventTap`) and text injection (`CGEvent`) |

All speech processing is handled by Apple's native Speech framework — no third-party models, no gigabytes of LLM in RAM.

## Usage

1. Press **⌘⇧Space** (default hotkey) to start listening
2. Speak — text appears in real time in the focused text field
3. Press **⌘⇧Space** again to stop

Click the menu bar icon to open the popover:
- **Status tab** — shows current state, live transcription, and hotkey
- **Settings tab** — change the hotkey (modifier keys + key)

## Build from Source

No Xcode project required. Build directly with `swiftc`:

```bash
cd Speak/Speak

swiftc \
  -sdk $(xcrun --show-sdk-path) \
  -target arm64-apple-macosx13.0 -O \
  -framework Cocoa -framework SwiftUI -framework Speech -framework AVFoundation \
  -o Speak \
  main.swift AppDelegate.swift DictationManager.swift TextInjector.swift \
  HotKeyMonitor.swift HotKeySettings.swift PopoverView.swift
```

### Create the app bundle

```bash
# Create bundle structure
mkdir -p Speak.app/Contents/MacOS
mkdir -p Speak.app/Contents/Resources

# Copy binary and resources
cp Speak Speak.app/Contents/MacOS/
cp Info.plist Speak.app/Contents/
cp Resources/*.png Speak.app/Contents/Resources/

# Sign with entitlements
codesign --force --deep --sign - \
  --entitlements Speak.entitlements \
  Speak.app
```

## Project Structure

```
speak/
├── Speak.dmg                     # Distributable disk image
├── scripts/
│   ├── install.command            # Install script (included in DMG)
│   └── uninstall.command          # Uninstall script (included in DMG)
└── Speak/Speak/
    ├── main.swift                 # Entry point
    ├── AppDelegate.swift          # Menu bar, popover, permission onboarding
    ├── DictationManager.swift     # Speech recognition + live text injection
    ├── TextInjector.swift         # CGEvent Unicode keystroke simulation
    ├── HotKeyMonitor.swift        # Global hotkey via CGEventTap
    ├── HotKeySettings.swift       # Configurable hotkey (persisted)
    ├── PopoverView.swift          # SwiftUI popover (Status + Settings)
    ├── Info.plist                 # App metadata
    ├── Speak.entitlements         # Entitlements (audio, no sandbox)
    └── Resources/                 # Menu bar icons (idle, listening, processing)
```

## Planned Features

- Voice commands: "new line", "period", "comma", "question mark"
- Auto-capitalization after punctuation
- Caps mode ("all caps on/off")

## Privacy

- No telemetry, no analytics, no tracking
- No data stored — transcripts exist only in memory during the active session
- No network calls from the app itself
- Speech recognition is handled by Apple's Speech framework; audio may be processed on-device or sent to Apple's servers depending on your device and language settings

## License

MIT License — see [LICENSE](LICENSE).
