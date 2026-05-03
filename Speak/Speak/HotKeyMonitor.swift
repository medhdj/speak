import Cocoa

/// Registers a global hotkey using CGEventTap.
/// Automatically re-enables the tap if macOS disables it (e.g. after app switch).
class HotKeyMonitor {

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let callback: () -> Void
    private var retryTimer: Timer?
    private var watchdogTimer: Timer?

    init(callback: @escaping () -> Void) {
        self.callback = callback
        startOrRetry()
    }

    deinit {
        retryTimer?.invalidate()
        watchdogTimer?.invalidate()
        stop()
    }

    // MARK: - Setup with retry until AX permission granted

    private func startOrRetry() {
        if AXIsProcessTrusted() {
            start()
        } else {
            retryTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
                if AXIsProcessTrusted() {
                    timer.invalidate()
                    self?.start()
                }
            }
        }
    }

    private func start() {
        stop() // clean up any existing tap first

        // FIX 3: listen for both keyDown AND tapDisabled events
        let eventMask = CGEventMask(1 << CGEventType.keyDown.rawValue)
                      | CGEventMask(1 << CGEventType.tapDisabledByTimeout.rawValue)
                      | CGEventMask(1 << CGEventType.tapDisabledByUserInput.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { proxy, type, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon else { return Unmanaged.passRetained(event) }
                let monitor = Unmanaged<HotKeyMonitor>.fromOpaque(refcon).takeUnretainedValue()
                return monitor.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            // Tap creation failed — retry in 2s
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                self?.start()
            }
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        // FIX 3: watchdog — check every 3s and re-enable tap if macOS disabled it
        watchdogTimer?.invalidate()
        watchdogTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.ensureTapEnabled()
        }
    }

    private func stop() {
        watchdogTimer?.invalidate()
        watchdogTimer = nil
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            }
        }
        eventTap = nil
        runLoopSource = nil
    }

    // MARK: - Watchdog

    private func ensureTapEnabled() {
        guard let tap = eventTap else { return }
        if !CGEvent.tapIsEnabled(tap: tap) {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }

    // MARK: - Event handling

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // FIX 3: re-enable immediately when macOS sends a disable notification
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return nil
        }

        guard type == .keyDown else { return Unmanaged.passRetained(event) }

        // Ignore synthetic events posted by TextInjector (private source state = 0)
        let sourceState = event.getIntegerValueField(.eventSourceStateID)
        if sourceState == TextInjector.sourceStateID.rawValue {
            return Unmanaged.passRetained(event)
        }

        let settings = HotKeySettings.shared
        let targetKeyCode = settings.keyCode
        let targetFlags   = settings.cgEventFlags

        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let relevantMask: CGEventFlags = [.maskCommand, .maskShift, .maskAlternate, .maskControl]
        let flags = event.flags.intersection(relevantMask)

        if keyCode == targetKeyCode && flags == targetFlags {
            callback()
            return nil // consume the event
        }

        return Unmanaged.passRetained(event)
    }
}
