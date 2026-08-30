import AppKit

struct GlobalShortcut: Codable, Equatable, Sendable {
    let keyCode: UInt16
    private let modifiersRawValue: UInt

    init(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        self.keyCode = keyCode
        self.modifiersRawValue = Self.normalized(modifiers).rawValue
    }

    var modifiers: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: modifiersRawValue)
    }

    var displayName: String {
        let glyphs = [
            modifiers.contains(.control) ? "⌃" : "",
            modifiers.contains(.option) ? "⌥" : "",
            modifiers.contains(.shift) ? "⇧" : "",
            modifiers.contains(.command) ? "⌘" : ""
        ].joined()
        return glyphs + Self.keyNames[keyCode, default: "Key \(keyCode)"]
    }

    func matches(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> Bool {
        self.keyCode == keyCode && self.modifiers == Self.normalized(modifiers)
    }

    static func normalized(_ modifiers: NSEvent.ModifierFlags) -> NSEvent.ModifierFlags {
        let ignored: NSEvent.ModifierFlags = [.capsLock, .numericPad, .function]
        return modifiers.intersection(.deviceIndependentFlagsMask).subtracting(ignored)
    }

    private static let keyNames: [UInt16: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
        8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y",
        17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 24: "=",
        25: "9", 26: "7", 27: "-", 28: "8", 29: "0", 30: "]", 31: "O", 32: "U",
        33: "[", 34: "I", 35: "P", 36: "Return", 37: "L", 38: "J", 39: "'",
        40: "K", 41: ";", 42: "\\", 43: ",", 44: "/", 45: "N", 46: "M", 47: ".",
        48: "Tab", 49: "Space", 50: "`", 51: "Delete", 53: "Esc",
        123: "←", 124: "→", 125: "↓", 126: "↑"
    ]
}

struct GlobalShortcutSet: Codable, Equatable, Sendable {
    static let flowDefault = GlobalShortcutSet(
        toggle: GlobalShortcut(keyCode: 3, modifiers: [.command, .option, .control]),
        skip: GlobalShortcut(keyCode: 1, modifiers: [.command, .option, .control]),
        reset: GlobalShortcut(keyCode: 15, modifiers: [.command, .option, .control]),
        showOrHideWindow: GlobalShortcut(keyCode: 4, modifiers: [.command, .option, .control])
    )

    var toggle: GlobalShortcut
    var skip: GlobalShortcut
    var reset: GlobalShortcut
    var showOrHideWindow: GlobalShortcut
}

enum GlobalHotkeyAction: Equatable {
    case toggle
    case skip
    case resetCycle
    case showOrHideWindow
}

enum LocalShortcutAction: Equatable {
    case showSettings
    case global(GlobalHotkeyAction)
}

enum LocalShortcutResolver {
    static func action(
        keyCode: UInt16,
        modifiers: NSEvent.ModifierFlags,
        globalHotkeysEnabled: Bool,
        shortcuts: GlobalShortcutSet
    ) -> LocalShortcutAction? {
        if keyCode == 43,
           GlobalShortcut.normalized(modifiers) == .command {
            return .showSettings
        }
        guard globalHotkeysEnabled,
              let action = GlobalHotkeyResolver.action(
                  keyCode: keyCode,
                  modifiers: modifiers,
                  shortcuts: shortcuts
              ) else { return nil }
        return .global(action)
    }
}

enum GlobalHotkeyResolver {
    static func action(
        keyCode: UInt16,
        modifiers: NSEvent.ModifierFlags,
        shortcuts: GlobalShortcutSet
    ) -> GlobalHotkeyAction? {
        if shortcuts.toggle.matches(keyCode: keyCode, modifiers: modifiers) { return .toggle }
        if shortcuts.skip.matches(keyCode: keyCode, modifiers: modifiers) { return .skip }
        if shortcuts.reset.matches(keyCode: keyCode, modifiers: modifiers) { return .resetCycle }
        if shortcuts.showOrHideWindow.matches(keyCode: keyCode, modifiers: modifiers) { return .showOrHideWindow }
        return nil
    }
}

@MainActor
final class GlobalHotkeyMonitor {
    static let shared = GlobalHotkeyMonitor()

    private var eventMonitor: Any?
    private var localEventMonitor: Any?

    func configure(enabled: Bool, controller: TimerController) {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
        if let localEventMonitor {
            NSEvent.removeMonitor(localEventMonitor)
            self.localEventMonitor = nil
        }
        let shortcuts = controller.preferences.globalShortcuts

        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak controller] event in
            guard let action = LocalShortcutResolver.action(
                keyCode: event.keyCode,
                modifiers: event.modifierFlags,
                globalHotkeysEnabled: enabled,
                shortcuts: shortcuts
            ) else { return event }
            switch action {
            case .showSettings:
                Task { @MainActor in Self.showSettings() }
            case let .global(action):
                guard let controller else { return event }
                Task { @MainActor in Self.perform(action, controller: controller) }
            }
            return nil
        }

        guard enabled else { return }

        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak controller] event in
            guard let action = GlobalHotkeyResolver.action(
                keyCode: event.keyCode,
                modifiers: event.modifierFlags,
                shortcuts: shortcuts
            ) else { return }
            Task { @MainActor in
                guard let controller else { return }
                Self.perform(action, controller: controller)
            }
        }
    }

    private static func perform(_ action: GlobalHotkeyAction, controller: TimerController) {
        switch action {
        case .toggle: controller.toggle()
        case .skip: controller.skip()
        case .resetCycle: controller.resetCycle()
        case .showOrHideWindow: showOrHideTimerWindow()
        }
    }

    static func showOrHideTimerWindow() {
        guard let window = AppWindowActivation.timerWindow else { return }
        if window.isVisible {
            AppWindowActivation.hideTimerWindow()
        } else {
            window.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate()
        }
    }

    private static func showSettings() {
        guard let window = AppWindowActivation.timerWindow else { return }
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate()
        NotificationCenter.default.post(name: .showSettings, object: nil)
    }
}
