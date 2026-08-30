import AppKit

@MainActor
enum AppWindowActivation {
    static var timerWindow: NSWindow? {
        NSApplication.shared.windows.first { $0.identifier?.rawValue == "timer" }
            ?? NSApplication.shared.windows.first { $0.title == "NanaFlow" }
    }

    static func hideTimerWindow() {
        timerWindow?.orderOut(nil)
    }

    static func bringToFront(title: String, miniaturizable: Bool? = nil) {
        NSApplication.shared.activate()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            let window = NSApplication.shared.windows.first { $0.title == title }
            if let miniaturizable {
                window?.standardWindowButton(.miniaturizeButton)?.isEnabled = miniaturizable
            }
            window?.makeKeyAndOrderFront(nil)
            if window?.canBecomeKey == false {
                window?.orderFrontRegardless()
            }
        }
    }
}
