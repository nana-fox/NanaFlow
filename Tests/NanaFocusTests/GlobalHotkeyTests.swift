import AppKit
import XCTest
@testable import NanaFlow

final class GlobalHotkeyTests: XCTestCase {
    func testLocalSettingsShortcutMatchesFlowsInvisibleCommandCommaRoute() {
        XCTAssertEqual(
            LocalShortcutResolver.action(
                keyCode: 43,
                modifiers: [.command],
                globalHotkeysEnabled: false,
                shortcuts: .flowDefault
            ),
            .showSettings
        )
        XCTAssertNil(LocalShortcutResolver.action(
            keyCode: 43,
            modifiers: [.command, .option],
            globalHotkeysEnabled: false,
            shortcuts: .flowDefault
        ))
        XCTAssertNil(LocalShortcutResolver.action(
            keyCode: 42,
            modifiers: [.command],
            globalHotkeysEnabled: false,
            shortcuts: .flowDefault
        ))
    }

    func testLocalEventsAlsoResolveEnabledGlobalHotkeys() {
        let modifiers: NSEvent.ModifierFlags = [.command, .option, .control]
        XCTAssertEqual(
            LocalShortcutResolver.action(
                keyCode: 3,
                modifiers: modifiers,
                globalHotkeysEnabled: true,
                shortcuts: .flowDefault
            ),
            .global(.toggle)
        )
        XCTAssertNil(LocalShortcutResolver.action(
            keyCode: 3,
            modifiers: modifiers,
            globalHotkeysEnabled: false,
            shortcuts: .flowDefault
        ))
    }

    func testMenuBarStatusItemMatchesFlowsPrimaryAndSecondaryClickActions() {
        XCTAssertEqual(
            MenuBarStatusItemActionPolicy.action(eventType: .leftMouseUp, modifiers: []),
            .showMenu
        )
        XCTAssertEqual(
            MenuBarStatusItemActionPolicy.action(eventType: .rightMouseUp, modifiers: []),
            .quickToggle
        )
        XCTAssertEqual(
            MenuBarStatusItemActionPolicy.action(eventType: .leftMouseUp, modifiers: .control),
            .quickToggle
        )
        XCTAssertNil(MenuBarStatusItemActionPolicy.action(eventType: .leftMouseDown, modifiers: []))
    }

    func testResolvesSupportedGlobalHotkeys() {
        let shortcuts = GlobalShortcutSet.flowDefault
        let modifiers: NSEvent.ModifierFlags = [.command, .option, .control]
        XCTAssertEqual(GlobalHotkeyResolver.action(keyCode: 3, modifiers: modifiers, shortcuts: shortcuts), .toggle)
        XCTAssertEqual(GlobalHotkeyResolver.action(keyCode: 1, modifiers: modifiers, shortcuts: shortcuts), .skip)
        XCTAssertEqual(GlobalHotkeyResolver.action(keyCode: 15, modifiers: modifiers, shortcuts: shortcuts), .resetCycle)
        XCTAssertEqual(GlobalHotkeyResolver.action(keyCode: 4, modifiers: modifiers, shortcuts: shortcuts), .showOrHideWindow)
    }

    func testRejectsMissingOrAdditionalModifiers() {
        let shortcuts = GlobalShortcutSet.flowDefault
        XCTAssertNil(GlobalHotkeyResolver.action(keyCode: 3, modifiers: [.command], shortcuts: shortcuts))
        XCTAssertNil(GlobalHotkeyResolver.action(
            keyCode: 3,
            modifiers: [.command, .option, .control, .shift],
            shortcuts: shortcuts
        ))
        XCTAssertNil(GlobalHotkeyResolver.action(
            keyCode: 0,
            modifiers: [.command, .option, .control],
            shortcuts: shortcuts
        ))
    }

    func testCustomShortcutSetChangesResolution() {
        var shortcuts = GlobalShortcutSet.flowDefault
        shortcuts.toggle = GlobalShortcut(keyCode: 49, modifiers: [.command, .shift])

        XCTAssertEqual(
            GlobalHotkeyResolver.action(keyCode: 49, modifiers: [.command, .shift], shortcuts: shortcuts),
            .toggle
        )
        XCTAssertNil(GlobalHotkeyResolver.action(
            keyCode: 3,
            modifiers: [.command, .option, .control],
            shortcuts: shortcuts
        ))
    }

    func testShortcutDisplayUsesMacGlyphsAndKnownKeyNames() {
        XCTAssertEqual(GlobalShortcutSet.flowDefault.toggle.displayName, "⌃⌥⌘F")
        XCTAssertEqual(GlobalShortcut(keyCode: 49, modifiers: [.command, .shift]).displayName, "⇧⌘Space")
    }
}
