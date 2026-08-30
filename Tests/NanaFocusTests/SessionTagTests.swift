import XCTest
@testable import NanaFlow

@MainActor
final class SessionTagTests: XCTestCase {
    func testStandardTagsMatchFlow48NamesAndColors() {
        XCTAssertEqual(SessionTagSettings.standard.tags, ["工作", "个人", "学习"])
        XCTAssertEqual(SessionTagSettings.standard.colorHex(for: "工作"), "#FF5B8CC0")
        XCTAssertEqual(SessionTagSettings.standard.colorHex(for: "个人"), "#FFE2B658")
        XCTAssertEqual(SessionTagSettings.standard.colorHex(for: "学习"), "#FFD96D5A")
    }

    func testLegacyTagSettingsGainStableColorsWhenDecoded() throws {
        let legacy = #"{"tags":["工作","学习"],"selectedTag":"学习"}"#.data(using: .utf8)!

        let settings = try JSONDecoder().decode(SessionTagSettings.self, from: legacy)

        XCTAssertEqual(settings.colorHex(for: "工作"), "#FF5B8CC0")
        XCTAssertEqual(settings.colorHex(for: "学习"), "#FFE2B658")
    }

    func testTagSettingsRoundTripAndSelection() throws {
        let suiteName = "SessionTagTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let persistence = SessionTagPersistence(defaults: defaults)
        let settings = SessionTagSettings(tags: ["工作", "学习"], selectedTag: "学习")

        try persistence.save(settings)

        XCTAssertEqual(persistence.load(), settings)
    }

    func testStatisticsCanFilterByTag() {
        let now = Date(timeIntervalSince1970: 10_000)
        let sessions = [
            FocusSession(id: UUID(), startedAt: now.addingTimeInterval(-1_200), endedAt: now, duration: 1_200, completed: true, title: "NanaFlow", tag: "工作"),
            FocusSession(id: UUID(), startedAt: now.addingTimeInterval(-600), endedAt: now, duration: 600, completed: true, title: "NanaFlow", tag: "学习")
        ]

        let statistics = SessionStatistics(sessions: sessions, period: .day, anchor: now, tag: "工作")

        XCTAssertEqual(statistics.totalCount, 1)
        XCTAssertEqual(statistics.totalDuration, 1_200)
    }

    func testControllerRecordsSelectedTagAndRemovesItSafely() {
        let tags = TagMemoryPersistence()
        let history = TagHistoryPersistence()
        let controller = TimerController(
            configuration: TimerConfiguration(
                focusDuration: 60,
                shortBreakDuration: 60,
                longBreakDuration: 60,
                sessionsPerCycle: 1
            ),
            persistence: TagTimerPersistence(),
            preferencesPersistence: TagPreferencesPersistence(),
            historyPersistence: history,
            tagPersistence: tags,
            notifications: TagNotifications(),
            now: Date(timeIntervalSince1970: 1_000)
        )

        controller.addTag(" 阅读 ")
        controller.addTag("阅读")
        XCTAssertNil(controller.tagSettings.selectedTag)
        controller.selectTag("阅读")
        controller.toggle(at: Date(timeIntervalSince1970: 1_000))
        controller.tick(at: Date(timeIntervalSince1970: 1_060))

        XCTAssertEqual(controller.tagSettings.tags, ["工作", "个人", "学习", "阅读"])
        XCTAssertEqual(controller.tagSettings.colorHex(for: "阅读"), "#FF5B8CC0")
        XCTAssertEqual(history.sessions.first?.tag, "阅读")

        controller.removeTag("阅读")
        XCTAssertNil(controller.tagSettings.selectedTag)
        XCTAssertEqual(tags.settings?.tags, ["工作", "个人", "学习"])
    }

    func testUpdatingTagRenamesAndRecolorsEveryReference() {
        let tags = TagMemoryPersistence()
        tags.settings = SessionTagSettings(
            tags: ["工作", "学习"],
            selectedTag: "工作",
            colors: ["工作": "#FF5B8CC0", "学习": "#FFD96D5A"]
        )
        let history = TagHistoryPersistence()
        history.sessions = [
            FocusSession(
                id: UUID(),
                startedAt: Date(timeIntervalSince1970: 100),
                endedAt: Date(timeIntervalSince1970: 700),
                duration: 600,
                completed: true,
                title: "第一段",
                tag: "工作"
            )
        ]
        let controller = TimerController(
            persistence: TagTimerPersistence(),
            preferencesPersistence: TagPreferencesPersistence(),
            historyPersistence: history,
            tagPersistence: tags,
            notifications: TagNotifications(),
            now: Date(timeIntervalSince1970: 2_000)
        )

        controller.updateTag("工作", name: "深度工作", colorHex: "#FFD96D5A")

        XCTAssertEqual(controller.tagSettings.tags, ["深度工作", "学习"])
        XCTAssertEqual(controller.tagSettings.colorHex(for: "深度工作"), "#FFD96D5A")
        XCTAssertNil(controller.tagSettings.colors["工作"])
        XCTAssertEqual(controller.tagSettings.selectedTag, "深度工作")
        XCTAssertEqual(controller.sessions.first?.tag, "深度工作")
        XCTAssertEqual(history.sessions.first?.tag, "深度工作")
    }

    func testRemovingTagClearsEveryHistoricalReferenceAndPersistsSessions() {
        let tags = TagMemoryPersistence()
        tags.settings = SessionTagSettings(tags: ["工作", "学习"], selectedTag: "工作")
        let history = TagHistoryPersistence()
        history.sessions = [
            FocusSession(
                id: UUID(),
                startedAt: Date(timeIntervalSince1970: 100),
                endedAt: Date(timeIntervalSince1970: 700),
                duration: 600,
                completed: true,
                title: "第一段",
                tag: "工作"
            ),
            FocusSession(
                id: UUID(),
                startedAt: Date(timeIntervalSince1970: 800),
                endedAt: Date(timeIntervalSince1970: 1_400),
                duration: 600,
                completed: true,
                title: "第二段",
                tag: "学习"
            )
        ]
        let controller = TimerController(
            persistence: TagTimerPersistence(),
            preferencesPersistence: TagPreferencesPersistence(),
            historyPersistence: history,
            tagPersistence: tags,
            notifications: TagNotifications(),
            now: Date(timeIntervalSince1970: 2_000)
        )

        controller.removeTag("工作")

        XCTAssertEqual(controller.tagSettings.tags, ["学习"])
        XCTAssertNil(controller.tagSettings.colors["工作"])
        XCTAssertNil(controller.tagSettings.selectedTag)
        XCTAssertNil(controller.sessions.first(where: { $0.title == "第一段" })?.tag)
        XCTAssertEqual(controller.sessions.first(where: { $0.title == "第二段" })?.tag, "学习")
        XCTAssertNil(history.sessions.first(where: { $0.title == "第一段" })?.tag)
    }
}

@MainActor
private final class TagMemoryPersistence: SessionTagPersisting {
    var settings: SessionTagSettings?
    func load() -> SessionTagSettings? { settings }
    func save(_ settings: SessionTagSettings) throws { self.settings = settings }
}

@MainActor
private final class TagHistoryPersistence: SessionHistoryPersisting {
    var sessions: [FocusSession] = []
    func load() -> [FocusSession] { sessions }
    func save(_ sessions: [FocusSession]) throws { self.sessions = sessions }
}

@MainActor
private struct TagTimerPersistence: TimerPersisting {
    func load() -> TimerEngine? { nil }
    func save(_: TimerEngine) throws {}
}

@MainActor
private struct TagPreferencesPersistence: TimerPreferencesPersisting {
    func load() -> TimerPreferences? { nil }
    func save(_: TimerPreferences) throws {}
}

@MainActor
private struct TagNotifications: SessionNotificationScheduling {
    func scheduleCompletion(at _: Date, nextPhase _: SessionPhase, sound _: CompletionSound, volume _: Double, quote _: String?) {}
    func cancelCompletion() {}
}
