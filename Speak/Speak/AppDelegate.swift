import Cocoa
import SwiftUI
import Speech
import AVFoundation

class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private let dictationManager = DictationManager()

    func setup() {
        setupMenuBar()
        setupPopover()
        dictationManager.onStateChange = { [weak self] state in
            DispatchQueue.main.async {
                self?.updateIcon(state: state)
            }
        }
        // Run permission onboarding after run loop is fully active
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.runPermissionOnboarding()
        }
    }

    // MARK: - Permission onboarding (sequential)

    private func runPermissionOnboarding() {
        requestMicrophoneAndSpeech {
            self.requestAccessibilityIfNeeded()
        }
    }

    private func requestMicrophoneAndSpeech(completion: @escaping () -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                if status != .authorized {
                    let alert = NSAlert()
                    alert.messageText = "Speech Recognition Required"
                    alert.informativeText = "Speak needs Speech Recognition access.\n\nPlease go to:\nSystem Settings → Privacy & Security → Speech Recognition\n→ Enable Speak"
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "Open System Settings")
                    alert.addButton(withTitle: "Later")
                    if alert.runModal() == .alertFirstButtonReturn {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_SpeechRecognition")!)
                    }
                }
                // Request mic regardless
                AVCaptureDevice.requestAccess(for: .audio) { _ in
                    DispatchQueue.main.async { completion() }
                }
            }
        }
    }

    private func requestAccessibilityIfNeeded() {
        if !AXIsProcessTrusted() {
            // Trigger the system prompt
            let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)

            let alert = NSAlert()
            alert.messageText = "Accessibility Permission Required"
            alert.informativeText = "Speak needs Accessibility access to:\n• Capture the global hotkey (⌘⇧Space)\n• Inject transcribed text into any app\n\nPlease go to:\nSystem Settings → Privacy & Security → Accessibility\n→ Enable Speak\n\nThen restart Speak."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Later")
            if alert.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
            }
        }
    }

    // MARK: - Menu Bar

    private func tabBarImage(named resourceName: String) -> NSImage? {
        // Use @2x on Retina screens, 1x otherwise
        let scale = NSScreen.main?.backingScaleFactor ?? 1.0
        let suffix = scale >= 2.0 ? "@2x" : ""
        let name = "\(resourceName)\(suffix)"

        guard let path = Bundle.main.path(forResource: name, ofType: "png"),
              let img = NSImage(contentsOfFile: path) else {
            // fallback to 1x
            guard let path1x = Bundle.main.path(forResource: resourceName, ofType: "png"),
                  let img1x = NSImage(contentsOfFile: path1x) else { return nil }
            img1x.size = NSSize(width: 18, height: 18)
            return img1x
        }
        // The image pixels are 36x36 (@2x) but we tell AppKit it's 18x18pt
        img.size = NSSize(width: 18, height: 18)
        return img
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = statusItem?.button else { return }
        button.image = tabBarImage(named: "icon_tabbar_idle_blue_waves")
        button.action = #selector(handleStatusBarClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.target = self
    }

    private func setupPopover() {
        let p = NSPopover()
        p.contentSize = NSSize(width: 280, height: 240)
        p.behavior = .transient
        p.contentViewController = NSHostingController(
            rootView: PopoverView(dictationManager: dictationManager)
        )
        popover = p
    }

    @objc private func handleStatusBarClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover(sender)
        }
    }

    private func togglePopover(_ sender: NSStatusBarButton) {
        guard let popover else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Quit Speak", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    func updateIcon(state: DictationState) {
        guard let button = statusItem?.button else { return }
        switch state {
        case .idle:
            button.image = tabBarImage(named: "icon_tabbar_idle_blue_waves")
        case .listening:
            button.image = tabBarImage(named: "icon_tabbar_listening_red_waves")
        case .processing:
            button.image = tabBarImage(named: "icon_tabbar_processing_orange_waves")
        }
    }
}
