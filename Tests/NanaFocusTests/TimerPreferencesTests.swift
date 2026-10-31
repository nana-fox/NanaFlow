import XCTest
@testable import NanaFlow

@MainActor
final class TimerPreferencesTests: XCTestCase {
    func testRoundTripsPreferences() throws {
        let suiteName = "TimerPreferencesTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let persistence = TimerPreferencesPersistence(defaults: defaults)
        let preferences = TimerPreferences(
            autoStartFocus: true,
            autoStartBreaks: false,
            notificationSoundEnabled: false,
            commitmentModeEnabled: true,
            showWindowOnLaunch: true,
            resetCycleOnLaunch: true,
            startTimerOnLaunch: true,
            hideWindowWhenTimerStarts: false,
            fullscreenBreaks: true,
            tickingSoundEnabled: true,
            tickingVolume: 1.4,
            notificationsEnabled: false,
            motivationalQuotesEnabled: false,
            appearance: .dark,
            menuBarIconStyle: .progress,
            showMenuBarTitle: false,
            coloredMenuBarIconDuringBreak: false,
            globalHotkeysEnabled: true,
            globalShortcuts: GlobalShortcutSet(
                toggle: GlobalShortcut(keyCode: 49, modifiers: [.command, .shift]),
                skip: .init(keyCode: 1, modifiers: [.command, .option, .control]),
                reset: .init(keyCode: 15, modifiers: [.command, .option, .control]),
                showOrHideWindow: .init(keyCode: 4, modifiers: [.command, .option, .control])
            ),
            focusCompletionSound: .harp,
            breakCompletionSound: .chime,
            notificationVolume: 0.5,
            sessionTitle: "写作"
        )

        try persistence.save(preferences)

        XCTAssertEqual(persistence.load(), preferences)
    }

    func testCorruptPreferencesFallBackToNil() throws {
        let suiteName = "TimerPreferencesTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(Data("bad".utf8), forKey: TimerPreferencesPersistence.storageKey)

        XCTAssertNil(TimerPreferencesPersistence(defaults: defaults).load())
    }

    func testLegacyPreferencesDefaultCommitmentModeToOff() throws {
        let data = try XCTUnwrap("""
        {"autoStartFocus":false,"autoStartBreaks":false,"notificationSoundEnabled":true}
        """.data(using: .utf8))

        let preferences = try JSONDecoder().decode(TimerPreferences.self, from: data)

        XCTAssertFalse(preferences.commitmentModeEnabled)
        XCTAssertFalse(preferences.showWindowOnLaunch)
        XCTAssertFalse(preferences.resetCycleOnLaunch)
        XCTAssertFalse(preferences.startTimerOnLaunch)
        XCTAssertTrue(preferences.hideWindowWhenTimerStarts)
        XCTAssertFalse(preferences.fullscreenBreaks)
        XCTAssertFalse(preferences.tickingSoundEnabled)
        XCTAssertEqual(preferences.tickingVolume, 1)
        XCTAssertFalse(preferences.notificationsEnabled)
        XCTAssertTrue(preferences.motivationalQuotesEnabled)
        XCTAssertEqual(preferences.appearance, .system)
        XCTAssertEqual(preferences.menuBarIconStyle, .default)
        XCTAssertFalse(preferences.showMenuBarTitle)
        XCTAssertTrue(preferences.coloredMenuBarIconDuringBreak)
        XCTAssertFalse(preferences.globalHotkeysEnabled)
        XCTAssertEqual(preferences.globalShortcuts, .flowDefault)
        XCTAssertEqual(preferences.focusCompletionSound, .bell)
        XCTAssertEqual(preferences.breakCompletionSound, .bell)
        XCTAssertEqual(preferences.notificationVolume, 1)
        XCTAssertEqual(preferences.sessionTitle, "NanaFlow")
    }

    func testLegacyTimerSyncEnabledKeyIsIgnoredOnDecode() throws {
        let data = try XCTUnwrap("""
        {"autoStartFocus":false,"autoStartBreaks":false,"notificationSoundEnabled":true,"timerSyncEnabled":true}
        """.data(using: .utf8))

        let preferences = try JSONDecoder().decode(TimerPreferences.self, from: data)

        XCTAssertFalse(preferences.autoStartFocus)
        XCTAssertFalse(preferences.autoStartBreaks)
        XCTAssertTrue(preferences.notificationSoundEnabled)
    }

    func testLegacyCalendarSyncKeysAreIgnoredOnDecode() throws {
        let data = try XCTUnwrap("""
        {"autoStartFocus":false,"autoStartBreaks":false,"notificationSoundEnabled":true,"calendarSyncEnabled":true,"calendarIdentifier":"calendar.work"}
        """.data(using: .utf8))

        let preferences = try JSONDecoder().decode(TimerPreferences.self, from: data)

        XCTAssertFalse(preferences.autoStartFocus)
        XCTAssertFalse(preferences.autoStartBreaks)
        XCTAssertTrue(preferences.notificationSoundEnabled)
    }

    func testNotificationsRequireExplicitOptInByDefault() {
        XCTAssertFalse(TimerPreferences.standard.notificationsEnabled)
    }

    func testLegacyDisabledSoundDefaultsBothCompletionSoundsToNone() throws {
        let data = try XCTUnwrap("""
        {"autoStartFocus":false,"autoStartBreaks":false,"notificationSoundEnabled":false}
        """.data(using: .utf8))

        let preferences = try JSONDecoder().decode(TimerPreferences.self, from: data)

        XCTAssertEqual(preferences.focusCompletionSound, .none)
        XCTAssertEqual(preferences.breakCompletionSound, .none)
    }

    func testBundledSoundNamesAreUnique() {
        let names = CompletionSound.allCases.compactMap(\.fileName)
        XCTAssertEqual(names.count, CompletionSound.allCases.count - 1)
        XCTAssertEqual(Set(names).count, names.count)
    }

    func testCompletionSoundSelectsNearestBundledVolume() {
        XCTAssertNil(CompletionSound.none.fileName(volume: 1))
        XCTAssertNil(CompletionSound.bell.fileName(volume: 0))
        XCTAssertEqual(CompletionSound.bell.fileName(volume: 2), "NanaFlow-bell.aiff")
        XCTAssertEqual(CompletionSound.bell.fileName(volume: 1.04), "NanaFlow-bell-v2.aiff")
    }

    func testCompletionSoundMenuIncludesNoneAndPreservesSoundOrder() {
        XCTAssertEqual(
            CompletionSound.menuOrder.map(\.title),
            ["无", "铃声", "唱钵", "闹钟", "铃铛", "风铃", "和弦", "竖琴", "重要事件", "脉冲", "波纹", "吹口哨"]
        )
        XCTAssertTrue(CompletionSound.menuOrder.contains(.none))
    }

    func testCompletionSoundsRemainIndependentAndRoundTripLegacyFractionalVolume() throws {
        var preferences = TimerPreferences.standard
        preferences.setCompletionSound(.none, for: .shortBreak)
        preferences.setCompletionSound(.harp, for: .focus)
        XCTAssertEqual(preferences.focusCompletionSound, .harp)
        XCTAssertEqual(preferences.breakCompletionSound, .none)
        XCTAssertTrue(preferences.notificationSoundEnabled)
        preferences.setCompletionSound(.none, for: .focus)
        XCTAssertFalse(preferences.notificationSoundEnabled)
        preferences.notificationVolume = 0.2
        let decoded = try JSONDecoder().decode(TimerPreferences.self, from: JSONEncoder().encode(preferences))
        XCTAssertEqual(decoded.notificationVolume, 0.2)
        XCTAssertEqual(SettingsVolumeContract.percentage(for: decoded.notificationVolume), 0)
        XCTAssertNil(decoded.focusCompletionSound.fileName(volume: decoded.notificationVolume))
        XCTAssertFalse(decoded.notificationsEnabled)
    }

    func testSoundResourceAndDisplayedVolumeUseTheSameFiveEffectiveLevels() {
        for (volume, level) in [(0.0, 0), (0.2, 0), (0.25, 1), (0.5, 1), (0.75, 2), (1.0, 2), (1.25, 3), (1.5, 3), (1.75, 4), (2.0, 4)] {
            XCTAssertEqual(CompletionSound.volumeLevel(volume), level)
            XCTAssertEqual(SettingsVolumeContract.percentage(for: volume), level * 25)
            let expected = level == 0 ? nil : level == 4 ? "NanaFlow-bell.aiff" : "NanaFlow-bell-v\(level).aiff"
            XCTAssertEqual(CompletionSound.bell.fileName(volume: volume), expected)
        }
        for volume in [Double.nan, .infinity, -.infinity] {
            XCTAssertEqual(CompletionSound.volumeLevel(volume), 0)
            XCTAssertNil(CompletionSound.bell.fileName(volume: volume))
        }
    }

    func testFlowVolumeRangesAreClamped() {
        let preferences = TimerPreferences(
            autoStartFocus: false,
            autoStartBreaks: false,
            notificationSoundEnabled: true,
            tickingVolume: 3,
            notificationVolume: -1
        )

        XCTAssertEqual(preferences.tickingVolume, 2)
        XCTAssertEqual(preferences.notificationVolume, 0)

        let loud = TimerPreferences(
            autoStartFocus: false,
            autoStartBreaks: false,
            notificationSoundEnabled: true,
            notificationVolume: 3
        )
        XCTAssertEqual(loud.notificationVolume, 2)
    }

    func testAllMenuBarIconStylesRemainAvailable() {
        XCTAssertEqual(MenuBarIconStyle.allCases, [.default, .circle, .progress])
    }
}
