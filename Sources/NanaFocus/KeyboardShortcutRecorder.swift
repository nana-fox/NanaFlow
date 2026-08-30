import AppKit
import SwiftUI

struct KeyboardShortcutRecorder: NSViewRepresentable {
    @Binding var shortcut: GlobalShortcut

    func makeNSView(context _: Context) -> ShortcutRecorderButton {
        let button = ShortcutRecorderButton()
        button.shortcut = shortcut
        button.onChange = { shortcut = $0 }
        return button
    }

    func updateNSView(_ button: ShortcutRecorderButton, context _: Context) {
        button.shortcut = shortcut
        button.onChange = { shortcut = $0 }
    }
}

final class ShortcutRecorderButton: NSButton {
    var shortcut = GlobalShortcutSet.flowDefault.toggle {
        didSet { if !isRecording { title = shortcut.displayName } }
    }
    var onChange: ((GlobalShortcut) -> Void)?
    private var isRecording = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        bezelStyle = .rounded
        controlSize = .small
        font = .monospacedSystemFont(ofSize: 12, weight: .medium)
        target = self
        action = #selector(beginRecording)
        title = shortcut.displayName
        setAccessibilityLabel(String(localized: "录制快捷键"))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { nil }

    override var acceptsFirstResponder: Bool { true }

    @objc private func beginRecording() {
        isRecording = true
        title = String(localized: "输入快捷键…")
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        _ = capture(event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        isRecording ? capture(event) : super.performKeyEquivalent(with: event)
    }

    override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        if resigned {
            isRecording = false
            title = shortcut.displayName
        }
        return resigned
    }

    private func capture(_ event: NSEvent) -> Bool {
        guard isRecording, event.type == .keyDown else { return false }
        if event.keyCode == 53 {
            isRecording = false
            title = shortcut.displayName
            window?.makeFirstResponder(nil)
            return true
        }

        let modifiers = GlobalShortcut.normalized(event.modifierFlags)
        guard !modifiers.isEmpty else {
            NSSound.beep()
            return true
        }

        let recorded = GlobalShortcut(keyCode: event.keyCode, modifiers: modifiers)
        shortcut = recorded
        onChange?(recorded)
        isRecording = false
        title = recorded.displayName
        window?.makeFirstResponder(nil)
        return true
    }
}
