import Cocoa

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let delegate = AppDelegate()
app.delegate = delegate

// Schedule setup on main runloop after app starts
DispatchQueue.main.async {
    delegate.setup()
}

app.run()
