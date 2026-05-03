import SwiftUI

struct PopoverView: View {
    @ObservedObject var dictationManager: DictationManager
    @ObservedObject private var hotKeySettings = HotKeySettings.shared

    var body: some View {
        TabView {
            StatusTab(dictationManager: dictationManager, hotKeySettings: hotKeySettings)
                .tabItem { Label("Status", systemImage: "mic") }

            SettingsTab(hotKeySettings: hotKeySettings)
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .frame(width: 280, height: 220)
        .padding(.top, 4)
    }
}

// MARK: - Status Tab

struct StatusTab: View {
    @ObservedObject var dictationManager: DictationManager
    @ObservedObject var hotKeySettings: HotKeySettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Accessibility warning
            if !AXIsProcessTrusted() {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text("Accessibility access needed")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Spacer()
                    Button("Fix") {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                    }
                    .font(.caption)
                    .controlSize(.mini)
                }
                .padding(6)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(6)
            }

            // State indicator
            HStack(spacing: 8) {
                if let path = Bundle.main.path(forResource: appIconName + "@2x", ofType: "png")
                    ?? Bundle.main.path(forResource: appIconName, ofType: "png"),
                   let nsImg = NSImage(contentsOfFile: path) {
                    Image(nsImage: nsImg)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 28, height: 28)
                } else {
                    Image(systemName: "mic")
                        .font(.title2)
                }
                Text(statusText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
            }

            // Last recognized text
            Group {
                if dictationManager.lastText.isEmpty {
                    Text("No transcription yet.")
                        .foregroundColor(.secondary)
                } else {
                    Text(dictationManager.lastText)
                        .foregroundColor(.primary)
                }
            }
            .font(.caption)
            .lineLimit(3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(6)

            // Error
            if let error = dictationManager.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            Spacer()

            Divider()

            HStack {
                Text(hotKeySettings.displayString)
                    .font(.system(.caption, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(4)
                Text("to toggle")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button(dictationManager.state == .listening ? "Stop" : "Start") {
                    dictationManager.toggle()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(dictationManager.state == .listening ? .red : .accentColor)
            }
        }
        .padding(14)
    }

    private var appIconName: String {
        switch dictationManager.state {
        case .idle:       return "icon_tabbar_idle_blue_waves"
        case .listening:  return "icon_tabbar_listening_red_waves"
        case .processing: return "icon_tabbar_processing_orange_waves"
        }
    }

    private var statusText: String {
        switch dictationManager.state {
        case .idle:       return "Idle"
        case .listening:  return "Listening..."
        case .processing: return "Processing..."
        }
    }
}

// MARK: - Settings Tab

struct SettingsTab: View {
    @ObservedObject var hotKeySettings: HotKeySettings

    // Local state for the key picker selection
    @State private var selectedKeyCode: CGKeyCode = HotKeySettings.shared.keyCode

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            Text("Hotkey")
                .font(.headline)

            // Modifier checkboxes
            HStack(spacing: 16) {
                Toggle("⌃ Control", isOn: $hotKeySettings.modControl)
                Toggle("⌥ Option",  isOn: $hotKeySettings.modOption)
            }
            HStack(spacing: 16) {
                Toggle("⇧ Shift",   isOn: $hotKeySettings.modShift)
                Toggle("⌘ Command", isOn: $hotKeySettings.modCommand)
            }
            .toggleStyle(.checkbox)

            Divider()

            // Key picker
            HStack {
                Text("Key:")
                    .font(.subheadline)
                Picker("", selection: $selectedKeyCode) {
                    ForEach(HotKeySettings.availableKeys, id: \.keyCode) { entry in
                        Text(entry.label).tag(entry.keyCode)
                    }
                }
                .labelsHidden()
                .frame(width: 120)
                .onChange(of: selectedKeyCode) { newValue in
                    hotKeySettings.keyCode = newValue
                }
            }

            // Preview
            HStack {
                Text("Shortcut:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(hotKeySettings.displayString)
                    .font(.system(.caption, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(4)
            }

            Spacer()
        }
        .toggleStyle(.checkbox)
        .padding(14)
        .onAppear {
            selectedKeyCode = hotKeySettings.keyCode
        }
    }
}
