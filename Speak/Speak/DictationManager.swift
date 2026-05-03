import Foundation
import Cocoa
import Speech
import AVFoundation

enum DictationState {
    case idle
    case listening
    case processing
}

class DictationManager: ObservableObject {

    @Published var state: DictationState = .idle
    @Published var lastText: String = ""
    @Published var errorMessage: String? = nil

    var onStateChange: ((DictationState) -> Void)?

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale.autoupdatingCurrent)
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var hotKeyMonitor: HotKeyMonitor?
    private var isFinishing: Bool = false

    /// Text that has already been injected into the target app.
    /// Used to compute the delta when a new partial result arrives.
    private var injectedText: String = ""

    /// Guards against concurrent injection (since injection runs on a background queue).
    private var isInjecting: Bool = false

    /// Queue of pending deltas waiting to be injected.
    private var pendingDelta: String = ""

    init() {
        setupHotKey()
    }

    // MARK: - HotKey

    private func setupHotKey() {
        hotKeyMonitor = HotKeyMonitor {
            DispatchQueue.main.async {
                self.toggle()
            }
        }
    }

    // MARK: - Toggle

    func toggle() {
        if state == .listening {
            stopListening()
        } else {
            startListening()
        }
    }

    // MARK: - Start

    func startListening() {
        guard state == .idle else { return }

        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            DispatchQueue.main.async { self.errorMessage = "Speech recognition not authorized." }
            return
        }

        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            DispatchQueue.main.async { self.errorMessage = "Speech recognizer not available." }
            return
        }

        injectedText = ""
        pendingDelta = ""
        isInjecting = false
        isFinishing = false

        do {
            try beginAudioSession()
            DispatchQueue.main.async {
                self.state = .listening
                self.lastText = ""
                self.onStateChange?(.listening)
                self.errorMessage = nil
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to start: \(error.localizedDescription)"
            }
        }
    }

    private func beginAudioSession() throws {
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest else {
            throw NSError(domain: "Speak", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not create recognition request"])
        }

        recognitionRequest.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self, !self.isFinishing else { return }

            if let result {
                let fullText = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    self.lastText = fullText
                    self.injectDelta(fullText: fullText)
                }
            }

            if result?.isFinal == true {
                DispatchQueue.main.async { self.finishListening() }
            } else if error != nil {
                DispatchQueue.main.async { self.finishListening() }
            }
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
    }

    // MARK: - Incremental injection

    /// Compare the new full transcription to what we've already injected.
    /// Only inject the new suffix (delta) if the recognizer appended text.
    /// If the recognizer revised earlier words, update tracking but don't
    /// inject — we can't safely backspace when cursor position is unknown.
    private func injectDelta(fullText: String) {
        guard !isFinishing else { return }

        if fullText.hasPrefix(injectedText) {
            // Common case: recognizer appended new words
            let delta = String(fullText.dropFirst(injectedText.count))
            guard !delta.isEmpty else { return }
            injectedText = fullText
            enqueueInjection(delta)
        } else {
            // Recognizer revised earlier text — just update tracking.
            // The correction is visible in the popover; future deltas
            // will append from this new baseline.
            injectedText = fullText
        }
    }

    /// Enqueue text for injection. If an injection is already in flight,
    /// buffer the delta so we don't overlap CGEvent posts.
    private func enqueueInjection(_ text: String) {
        pendingDelta += text

        guard !isInjecting else { return }
        isInjecting = true

        let toInject = pendingDelta
        pendingDelta = ""

        TextInjector.inject(text: toInject) {
            DispatchQueue.main.async {
                self.isInjecting = false
                // If more deltas accumulated while we were injecting, flush them
                if !self.pendingDelta.isEmpty {
                    self.enqueueInjection("")
                }
            }
        }
    }

    // MARK: - Stop

    func stopListening() {
        guard state == .listening else { return }

        state = .processing
        onStateChange?(.processing)

        recognitionRequest?.endAudio()

        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }

        // Give a brief moment for any final partial result to arrive and inject
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.finishListening()
        }
    }

    private func finishListening() {
        guard !isFinishing else { return }
        isFinishing = true

        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil

        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }

        injectedText = ""
        pendingDelta = ""

        state = .idle
        onStateChange?(.idle)
    }
}
