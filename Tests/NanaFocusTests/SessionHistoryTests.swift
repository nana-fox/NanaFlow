import XCTest
@testable import NanaFlow

@MainActor
final class SessionHistoryTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    func testHistoryRoundTripsSessions() throws {
        let suiteName = "SessionHistoryTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let persistence = SessionHistoryPersistence(defaults: defaults)
        let sessions = [
            FocusSession(
                id: UUID(),
                startedAt: start,
                endedAt: start.addingTimeInterval(25 * 60),
                duration: 25 * 60,
                completed: true,
                title: "NanaFlow"
            )
        ]

        try persistence.save(sessions)

        XCTAssertEqual(persistence.load(), sessions)
    }

    func testHistoryMirrorsSessionsForWidgets() throws {
        let primaryName = "SessionHistoryPrimary-\(UUID().uuidString)"
        let sharedName = "SessionHistoryShared-\(UUID().uuidString)"
        let primary = try XCTUnwrap(UserDefaults(suiteName: primaryName))
        let shared = try XCTUnwrap(UserDefaults(suiteName: sharedName))
        defer {
            primary.removePersistentDomain(forName: primaryName)
            shared.removePersistentDomain(forName: sharedName)
        }
        let persistence = SessionHistoryPersistence(defaults: primary, sharedDefaults: shared)
        let sessions = [session(on: start, minutes: 25)]

        try persistence.save(sessions)

        let data = try XCTUnwrap(shared.data(forKey: SessionHistoryPersistence.storageKey))
        XCTAssertEqual(try JSONDecoder().decode([FocusSession].self, from: data), sessions)
    }

    func testLoadMergesPrimaryAndSharedHistoriesAndRepairsBothStores() throws {
        let stores = try HistoryStores()
        defer { stores.clear() }
        let onlyInPrimary = session(on: start, minutes: 25)
        let onlyInShared = session(on: start.addingTimeInterval(3_600), minutes: 10)
        let conflictID = UUID()
        var primaryEdit = session(on: start.addingTimeInterval(7_200), minutes: 50, id: conflictID)
        primaryEdit.title = "主记录标题"
        var staleMirror = primaryEdit
        staleMirror.title = "旧镜像标题"
        try stores.write([onlyInPrimary, primaryEdit], to: stores.primary)
        try stores.write([onlyInShared, staleMirror], to: stores.shared)

        let loaded = stores.persistence.load()

        XCTAssertEqual(Set(loaded.map(\.id)), [onlyInPrimary.id, onlyInShared.id, conflictID])
        XCTAssertEqual(loaded.count, 3)
        XCTAssertEqual(loaded.first { $0.id == conflictID }?.title, "主记录标题")
        XCTAssertEqual(loaded, loaded.sorted { $0.endedAt > $1.endedAt })
        XCTAssertEqual(try stores.read(stores.primary), loaded)
        XCTAssertEqual(try stores.read(stores.shared), loaded)
    }

    func testLoadRecoversFromSharedHistoryWhenPrimaryIsMissing() throws {
        let stores = try HistoryStores()
        defer { stores.clear() }
        let mirrored = [session(on: start, minutes: 25)]
        try stores.write(mirrored, to: stores.shared)

        let loaded = stores.persistence.load()

        XCTAssertEqual(loaded, mirrored)
        XCTAssertEqual(try stores.read(stores.primary), mirrored)
    }

    func testLoadKeepsPrimaryHistoryWhenSharedDataIsCorrupt() throws {
        let stores = try HistoryStores()
        defer { stores.clear() }
        let primarySessions = [session(on: start, minutes: 25)]
        try stores.write(primarySessions, to: stores.primary)
        stores.shared.set(Data("not json".utf8), forKey: SessionHistoryPersistence.storageKey)

        let loaded = stores.persistence.load()

        XCTAssertEqual(loaded, primarySessions)
        XCTAssertEqual(try stores.read(stores.primary), primarySessions)
        XCTAssertEqual(try stores.read(stores.shared), primarySessions)
    }

    func testLoadReturnsEmptyWhenBothHistoriesAreInvalid() throws {
        let stores = try HistoryStores()
        defer { stores.clear() }
        stores.primary.set(Data("not json".utf8), forKey: SessionHistoryPersistence.storageKey)
        stores.shared.set(Data([0x00, 0x01]), forKey: SessionHistoryPersistence.storageKey)

        XCTAssertTrue(stores.persistence.load().isEmpty)
        XCTAssertNotNil(stores.primary.data(forKey: SessionHistoryPersistence.storageKey))
        XCTAssertNotNil(stores.shared.data(forKey: SessionHistoryPersistence.storageKey))
    }

    func testLoadWithoutSharedDefaultsKeepsSingleStoreBehaviour() throws {
        let suiteName = "SessionHistoryPrimary-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let sessions = [session(on: start, minutes: 25)]
        defaults.set(try JSONEncoder().encode(sessions), forKey: SessionHistoryPersistence.storageKey)

        XCTAssertEqual(SessionHistoryPersistence(defaults: defaults).load(), sessions)
    }

    func testLegacySessionJSONDecodesWithNewDefaults() throws {
        struct LegacySession: Encodable {
            let id: UUID
            let startedAt: Date
            let endedAt: Date
            let duration: TimeInterval
            let completed: Bool
            let title: String
            let tag: String?
        }

        let legacy = LegacySession(
            id: UUID(),
            startedAt: start,
            endedAt: start.addingTimeInterval(90),
            duration: 90,
            completed: false,
            title: "旧会话",
            tag: "工作"
        )

        let decoded = try JSONDecoder().decode(FocusSession.self, from: JSONEncoder().encode(legacy))

        XCTAssertEqual(decoded.id, legacy.id)
        XCTAssertEqual(decoded.type, .focus)
        XCTAssertEqual(decoded.interruptions, [])
        XCTAssertNil(decoded.completedAt)
    }

    func testCloudHistoryMergeKeepsUniqueNewestSessions() {
        let id = UUID()
        let local = FocusSession(
            id: id,
            startedAt: start,
            endedAt: start.addingTimeInterval(60),
            duration: 60,
            completed: true,
            title: "旧标题"
        )
        let remote = FocusSession(
            id: id,
            startedAt: start,
            endedAt: start.addingTimeInterval(60),
            duration: 60,
            completed: true,
            title: "新标题"
        )
        let second = session(on: start.addingTimeInterval(120), minutes: 25)

        let merged = SessionHistoryPersistence.merge(local: [local], incoming: [remote, second])

        XCTAssertEqual(merged.map(\.id), [second.id, id])
        XCTAssertEqual(merged.last?.title, "新标题")
    }

    func testMergeSurvivesDuplicateIDsOnEitherSide() {
        let duplicated = UUID()
        var localFirst = session(on: start, minutes: 25, id: duplicated)
        localFirst.title = "镜像旧值"
        var localSecond = localFirst
        localSecond.title = "镜像新值"
        var incomingFirst = session(on: start, minutes: 25, id: duplicated)
        incomingFirst.title = "主记录旧值"
        var incomingSecond = incomingFirst
        incomingSecond.title = "主记录新值"

        let merged = SessionHistoryPersistence.merge(
            local: [localFirst, localSecond],
            incoming: [incomingFirst, incomingSecond]
        )

        XCTAssertEqual(merged.map(\.id), [duplicated])
        XCTAssertEqual(merged.first?.title, "主记录新值")
    }

    func testMergeOrdersSessionsWithEqualEndDatesByID() {
        let sameEnd = (0 ..< 5).map { index in
            session(on: start, minutes: 25, id: UUID(uuidString: "0000000\(index)-0000-0000-0000-000000000000")!)
        }
        let expected = sameEnd.sorted { $0.id.uuidString < $1.id.uuidString }

        XCTAssertEqual(SessionHistoryPersistence.merge(local: [], incoming: sameEnd.shuffled()), expected)
        XCTAssertEqual(SessionHistoryPersistence.merge(local: sameEnd.shuffled(), incoming: []), expected)
    }

    func testLoadLeavesBothStoresUntouchedWhenTheyAlreadyAgree() throws {
        let stores = try HistoryStores()
        defer { stores.clear() }
        let tied = (0 ..< 5)
            .map { index in
                session(on: start, minutes: 25, id: UUID(uuidString: "0000000\(index)-0000-0000-0000-000000000000")!)
            }
            .sorted { $0.id.uuidString < $1.id.uuidString }
        try stores.write(tied, to: stores.primary)
        try stores.write(tied, to: stores.shared)
        let primaryBefore = stores.primary.data(forKey: SessionHistoryPersistence.storageKey)
        let sharedBefore = stores.shared.data(forKey: SessionHistoryPersistence.storageKey)

        XCTAssertEqual(stores.persistence.load(), tied)

        XCTAssertEqual(stores.primary.data(forKey: SessionHistoryPersistence.storageKey), primaryBefore)
        XCTAssertEqual(stores.shared.data(forKey: SessionHistoryPersistence.storageKey), sharedBefore)
    }

    func testWeeklyStatisticsCountOnlySessionsInSelectedWeek() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        let monday = calendar.date(from: DateComponents(year: 2026, month: 8, day: 24))!
        let sessions = [
            session(on: monday, minutes: 25),
            session(on: monday.addingTimeInterval(2 * 86_400), minutes: 50),
            session(on: monday.addingTimeInterval(-86_400), minutes: 30)
        ]

        let statistics = SessionStatistics(
            sessions: sessions,
            period: .week,
            anchor: monday.addingTimeInterval(3 * 86_400),
            calendar: calendar
        )

        XCTAssertEqual(statistics.totalCount, 2)
        XCTAssertEqual(statistics.totalDuration, 75 * 60)
        XCTAssertEqual(statistics.buckets.count, 7)
        XCTAssertEqual(statistics.buckets.map(\.sessionCount).reduce(0, +), 2)
    }

    func testStatisticsBucketsMatchCalendarPeriodLengths() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2

        func bucketCount(_ period: StatisticsPeriod, year: Int, month: Int, day: Int) -> Int {
            let anchor = calendar.date(from: DateComponents(year: year, month: month, day: day))!
            return SessionStatistics(
                sessions: [],
                period: period,
                anchor: anchor,
                calendar: calendar
            ).buckets.count
        }

        XCTAssertEqual(bucketCount(.day, year: 2026, month: 8, day: 30), 24)
        XCTAssertEqual(bucketCount(.week, year: 2026, month: 8, day: 30), 7)
        XCTAssertEqual(bucketCount(.month, year: 2026, month: 6, day: 15), 30)
        XCTAssertEqual(bucketCount(.month, year: 2026, month: 8, day: 15), 31)
        XCTAssertEqual(bucketCount(.month, year: 2028, month: 2, day: 15), 29)
        XCTAssertEqual(bucketCount(.year, year: 2026, month: 8, day: 30), 12)
    }

    func testStatisticsBucketTooltipShowsOnlyTheExactFlowCount() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = calendar.date(from: DateComponents(year: 2026, month: 8, day: 27, hour: 18))!
        let bucket = StatisticsBucket(
            start: start,
            end: calendar.date(byAdding: .hour, value: 1, to: start)!,
            sessionCount: 3,
            duration: 75 * 60,
            tagSegments: []
        )

        XCTAssertEqual(statisticsBucketTooltipText(bucket), "3")
    }

    func testStatisticsNavigationStopsAtTheCurrentPeriod() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        let now = calendar.date(from: DateComponents(year: 2026, month: 8, day: 30, hour: 12))!

        for period in StatisticsPeriod.allCases {
            XCTAssertFalse(statisticsCanMoveForward(period: period, anchor: now, now: now, calendar: calendar))
        }
        XCTAssertTrue(
            statisticsCanMoveForward(
                period: .week,
                anchor: calendar.date(byAdding: .weekOfYear, value: -1, to: now)!,
                now: now,
                calendar: calendar
            )
        )
        XCTAssertFalse(
            statisticsCanMoveForward(
                period: .month,
                anchor: calendar.date(byAdding: .month, value: 1, to: now)!,
                now: now,
                calendar: calendar
            )
        )
    }

    func testStatisticsAxisKeepsTheLastHourlyAndMonthlyLabelsVisible() {
        XCTAssertEqual(
            (0 ..< 24).filter { statisticsShowsLabel(at: $0, bucketCount: 24, period: .day) },
            [0, 6, 12, 18, 23]
        )
        XCTAssertEqual(
            (0 ..< 31).filter { statisticsShowsLabel(at: $0, bucketCount: 31, period: .month) },
            [0, 4, 9, 14, 19, 24, 29, 30]
        )
    }

    func testStatisticsPeriodTitlesCoverEveryRange() {
        XCTAssertEqual(StatisticsPeriod.allCases.map(\.shortTitle), ["天", "周", "月", "年"])
    }

    func testStatisticsPeriodTitleMatchesFlowDateRanges() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        let anchor = calendar.date(from: DateComponents(year: 2026, month: 8, day: 28))!

        let chinese = Locale(identifier: "zh_Hans_CN")
        XCTAssertEqual(statisticsPeriodTitle(.day, anchor: anchor, calendar: calendar, locale: chinese), "2026/8/28")
        XCTAssertEqual(statisticsPeriodTitle(.week, anchor: anchor, calendar: calendar, locale: chinese), "2026/8/24 – 2026/8/30")
        XCTAssertEqual(statisticsPeriodTitle(.month, anchor: anchor, calendar: calendar, locale: chinese), "2026年8月")
        XCTAssertEqual(statisticsPeriodTitle(.year, anchor: anchor, calendar: calendar, locale: chinese), "2026年")

        let english = Locale(identifier: "en_US")
        XCTAssertEqual(statisticsPeriodTitle(.day, anchor: anchor, calendar: calendar, locale: english), "8/28/2026")
        XCTAssertEqual(statisticsPeriodTitle(.week, anchor: anchor, calendar: calendar, locale: english), "8/24/2026 – 8/30/2026")
        XCTAssertEqual(statisticsPeriodTitle(.month, anchor: anchor, calendar: calendar, locale: english), "August 2026")
        XCTAssertEqual(statisticsPeriodTitle(.year, anchor: anchor, calendar: calendar, locale: english), "2026")
        XCTAssertEqual(flowStatisticsCalendar.firstWeekday, 2)
    }

    func testStatisticsChangePercentageComparesWithPreviousPeriod() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        let currentMonday = calendar.date(from: DateComponents(year: 2026, month: 8, day: 24))!
        let previousMonday = calendar.date(byAdding: .weekOfYear, value: -1, to: currentMonday)!
        let sessions = [
            session(on: currentMonday, minutes: 25),
            session(on: currentMonday.addingTimeInterval(86_400), minutes: 25),
            session(on: previousMonday, minutes: 25),
            session(on: previousMonday.addingTimeInterval(86_400), minutes: 25),
            session(on: previousMonday.addingTimeInterval(2 * 86_400), minutes: 25),
            session(on: previousMonday.addingTimeInterval(3 * 86_400), minutes: 25)
        ]

        XCTAssertEqual(
            statisticsChangePercentage(
                sessions: sessions,
                period: .week,
                anchor: currentMonday,
                metric: .count,
                calendar: calendar
            ),
            -50
        )
    }

    func testSessionRowDateMatchesFlowNumericFormat() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!
        let date = calendar.date(from: DateComponents(
            year: 2026,
            month: 8,
            day: 27,
            hour: 22,
            minute: 32
        ))!

        XCTAssertEqual(sessionRowDateText(date, calendar: calendar), "2026/8/27 22:32")
    }

    func testSessionDetailOnlyShowsInterruptionDurationWhenItAddsInformation() {
        let ordinary = session(on: start, minutes: 25)
        let interrupted = FocusSession(
            id: UUID(),
            startedAt: start,
            endedAt: start.addingTimeInterval(30 * 60),
            duration: 25 * 60,
            completed: true,
            title: "NanaFlow",
            interruptions: [SessionInterruption(
                stoppedAt: start.addingTimeInterval(5 * 60),
                resumedAt: start.addingTimeInterval(10 * 60)
            )]
        )

        XCTAssertFalse(shouldShowSessionInterruptionDuration(ordinary))
        XCTAssertTrue(shouldShowSessionInterruptionDuration(interrupted))
        XCTAssertEqual(sessionDurationText(3_661), "1小时1分钟1秒")
    }

    func testStatisticsBuildsTagBreakdownForCompletedSessions() {
        var work = session(on: start, minutes: 25)
        work.tag = "工作"
        var learning = session(on: start.addingTimeInterval(60), minutes: 10)
        learning.tag = "学习"
        let statistics = SessionStatistics(
            sessions: [work, learning],
            period: .day,
            anchor: start
        )

        XCTAssertEqual(statistics.tagSummaries.map(\.name), ["工作", "学习"])
        XCTAssertEqual(statistics.tagSummaries.map(\.duration), [25.0 * 60, 10.0 * 60])
        XCTAssertEqual(statistics.tagSummaries.map(\.sessionCount), [1, 1])
        let populatedBucket = statistics.buckets.first { $0.sessionCount > 0 }
        XCTAssertEqual(populatedBucket?.tagSegments.map(\.tag), ["学习", "工作"])
        XCTAssertEqual(populatedBucket?.tagSegments.map(\.sessionCount), [1, 1])
    }

    func testStatisticsExcludeBreaksAndIncompleteFocusSessions() {
        let completedFocus = session(on: start, minutes: 25)
        let completedBreak = FocusSession(
            id: UUID(),
            startedAt: start,
            endedAt: start.addingTimeInterval(5 * 60),
            duration: 5 * 60,
            completed: true,
            title: "休息",
            type: .shortBreak
        )
        let incompleteFocus = FocusSession(
            id: UUID(),
            startedAt: start,
            endedAt: start.addingTimeInterval(10 * 60),
            duration: 10 * 60,
            completed: false,
            title: "NanaFlow"
        )

        let statistics = SessionStatistics(
            sessions: [completedFocus, completedBreak, incompleteFocus],
            period: .day,
            anchor: start
        )

        XCTAssertEqual(statistics.totalCount, 1)
        XCTAssertEqual(statistics.totalDuration, 25 * 60)
    }

    func testSessionListFilterHidesIncompleteByDefaultAndFiltersTags() {
        var completed = session(on: start, minutes: 25)
        completed.tag = "工作"
        let incomplete = FocusSession(
            id: UUID(),
            startedAt: start,
            endedAt: start.addingTimeInterval(90),
            duration: 90,
            completed: false,
            title: "NanaFlow",
            tag: "工作"
        )
        let otherTag = FocusSession(
            id: UUID(),
            startedAt: start,
            endedAt: start.addingTimeInterval(5 * 60),
            duration: 5 * 60,
            completed: true,
            title: "休息",
            tag: nil,
            type: .shortBreak
        )

        XCTAssertEqual(
            filteredSessionHistory([incomplete, otherTag, completed], showIncomplete: false, tag: nil).map(\.id),
            [otherTag.id, completed.id]
        )
        XCTAssertEqual(
            filteredSessionHistory([incomplete, otherTag, completed], showIncomplete: true, tag: "工作").map(\.id),
            [incomplete.id, completed.id]
        )
    }

    func testSessionListPaginationMatchesFlowsHundredItemBatch() {
        XCTAssertEqual(SessionListPagination.batchSize, 100)
        XCTAssertEqual(SessionListPagination.nextLimit(current: 100, total: 10_716), 200)
        XCTAssertEqual(SessionListPagination.nextLimit(current: 10_700, total: 10_716), 10_716)
    }

    func testControllerStoresACompletedFocusSession() {
        let history = HistorySpy()
        let configuration = TimerConfiguration(
            focusDuration: 60,
            shortBreakDuration: 30,
            longBreakDuration: 60,
            sessionsPerCycle: 4
        )
        let controller = TimerController(
            configuration: configuration,
            persistence: HistoryTimerPersistence(),
            preferencesPersistence: HistoryPreferencesPersistence(),
            historyPersistence: history,
            notifications: HistoryNotifications(),
            now: start
        )

        controller.toggle(at: start)
        controller.tick(at: start.addingTimeInterval(61))

        XCTAssertEqual(controller.sessions.count, 1)
        XCTAssertEqual(controller.sessions.first?.duration, 60)
        XCTAssertEqual(controller.sessions.first?.completed, true)
        XCTAssertEqual(history.saved.last, controller.sessions)
    }

    func testSkippingRunningFocusStoresAnIncompleteSession() {
        let history = HistorySpy()
        let controller = TimerController(
            persistence: HistoryTimerPersistence(),
            preferencesPersistence: HistoryPreferencesPersistence(),
            historyPersistence: history,
            notifications: HistoryNotifications(),
            now: start
        )
        controller.toggle(at: start)

        controller.skip(at: start.addingTimeInterval(90))

        XCTAssertEqual(controller.sessions.first?.completed, false)
        XCTAssertEqual(controller.sessions.first?.duration, 90)
    }

    func testShortInterruptedPhaseIsNotStored() {
        let controller = TimerController(
            persistence: HistoryTimerPersistence(),
            preferencesPersistence: HistoryPreferencesPersistence(),
            historyPersistence: HistorySpy(),
            notifications: HistoryNotifications(),
            now: start
        )
        controller.start(at: start)

        controller.skip(at: start.addingTimeInterval(59))

        XCTAssertTrue(controller.sessions.isEmpty)
    }

    func testPauseResumeRecordsInterruptionAndBothDurations() {
        let configuration = TimerConfiguration(
            focusDuration: 120,
            shortBreakDuration: 30,
            longBreakDuration: 60,
            sessionsPerCycle: 4
        )
        let controller = TimerController(
            configuration: configuration,
            persistence: HistoryTimerPersistence(),
            preferencesPersistence: HistoryPreferencesPersistence(),
            historyPersistence: HistorySpy(),
            notifications: HistoryNotifications(),
            now: start
        )
        controller.start(at: start)
        controller.pause(at: start.addingTimeInterval(30))
        controller.start(at: start.addingTimeInterval(60))

        controller.tick(at: start.addingTimeInterval(151))

        let session = controller.sessions.first
        XCTAssertEqual(session?.duration, 120)
        XCTAssertEqual(session?.durationWithInterruptions, 150)
        XCTAssertEqual(
            session?.interruptions,
            [SessionInterruption(
                stoppedAt: start.addingTimeInterval(30),
                resumedAt: start.addingTimeInterval(60)
            )]
        )
    }

    func testCompletedSessionsDoNotWriteToLegacyCalendarIntegration() {
        let calendar = HistoryCalendarSpy()
        let preferences = TimerPreferences(
            autoStartFocus: false,
            autoStartBreaks: false,
            notificationSoundEnabled: false,
            calendarSyncEnabled: true,
            notificationsEnabled: false
        )
        let controller = TimerController(
            configuration: TimerConfiguration(
                focusDuration: 60,
                shortBreakDuration: 30,
                longBreakDuration: 60,
                sessionsPerCycle: 4
            ),
            persistence: HistoryTimerPersistence(),
            preferencesPersistence: HistoryPreferencesPersistence(loaded: preferences),
            historyPersistence: HistorySpy(),
            notifications: HistoryNotifications(),
            calendarRecorder: calendar,
            now: start
        )
        controller.start(at: start)
        controller.tick(at: start.addingTimeInterval(61))
        controller.start(at: start.addingTimeInterval(70))

        controller.tick(at: start.addingTimeInterval(101))

        XCTAssertEqual(controller.sessions.map(\.type), [.shortBreak, .focus])
        XCTAssertTrue(controller.sessions.allSatisfy(\.completed))
        XCTAssertTrue(calendar.sessions.isEmpty)
    }

    func testSkippedBreakAfterOneMinuteIsStoredIncomplete() {
        let controller = TimerController(
            configuration: TimerConfiguration(
                focusDuration: 60,
                shortBreakDuration: 120,
                longBreakDuration: 60,
                sessionsPerCycle: 4
            ),
            persistence: HistoryTimerPersistence(),
            preferencesPersistence: HistoryPreferencesPersistence(),
            historyPersistence: HistorySpy(),
            notifications: HistoryNotifications(),
            now: start
        )
        controller.start(at: start)
        controller.tick(at: start.addingTimeInterval(61))
        controller.start(at: start.addingTimeInterval(70))

        controller.skip(at: start.addingTimeInterval(131))

        XCTAssertEqual(controller.sessions.first?.type, .shortBreak)
        XCTAssertEqual(controller.sessions.first?.completed, false)
        XCTAssertEqual(controller.sessions.first?.duration, 61)
    }

    func testHistoryPersistenceFailureIsVisible() {
        let controller = TimerController(
            persistence: HistoryTimerPersistence(),
            preferencesPersistence: HistoryPreferencesPersistence(),
            historyPersistence: HistorySpy(saveError: HistoryTestError.failed),
            notifications: HistoryNotifications(),
            now: start
        )
        controller.toggle(at: start)

        controller.tick(at: start.addingTimeInterval(25 * 60 + 1))

        XCTAssertNotNil(controller.errorMessage)
    }

    func testLegacyCalendarPreferenceDoesNotWriteInVersionOne() {
        let calendar = HistoryCalendarSpy()
        let preferences = TimerPreferences(
            autoStartFocus: false,
            autoStartBreaks: false,
            notificationSoundEnabled: false,
            calendarSyncEnabled: true,
            calendarIdentifier: "calendar.work",
            notificationsEnabled: false
        )
        let controller = TimerController(
            configuration: TimerConfiguration(
                focusDuration: 60,
                shortBreakDuration: 30,
                longBreakDuration: 60,
                sessionsPerCycle: 4
            ),
            persistence: HistoryTimerPersistence(),
            preferencesPersistence: HistoryPreferencesPersistence(loaded: preferences),
            historyPersistence: HistorySpy(),
            notifications: HistoryNotifications(),
            calendarRecorder: calendar,
            now: start
        )

        controller.toggle(at: start)
        controller.tick(at: start.addingTimeInterval(61))

        XCTAssertTrue(calendar.sessions.isEmpty)
    }

    func testControllerCanEditAndDeleteStoredSessions() {
        let original = session(on: start, minutes: 25)
        let history = HistorySpy(loaded: [original])
        let calendar = HistoryCalendarSpy()
        let controller = TimerController(
            persistence: HistoryTimerPersistence(),
            preferencesPersistence: HistoryPreferencesPersistence(),
            historyPersistence: history,
            notifications: HistoryNotifications(),
            calendarRecorder: calendar,
            now: start
        )

        controller.updateSession(id: original.id, title: "深度工作", tag: "工作")

        XCTAssertEqual(controller.sessions.first?.title, "深度工作")
        XCTAssertEqual(controller.sessions.first?.tag, "工作")
        XCTAssertEqual(history.saved.last, controller.sessions)

        controller.deleteSession(id: original.id)

        XCTAssertTrue(controller.sessions.isEmpty)
        XCTAssertEqual(history.saved.last, [])
    }

    func testControllerImportsBackupByMergingWithoutDroppingLocalHistory() throws {
        let local = session(on: start, minutes: 25)
        let incoming = session(on: start.addingTimeInterval(3_600), minutes: 50)
        let history = HistorySpy(loaded: [local])
        let controller = TimerController(
            persistence: HistoryTimerPersistence(),
            preferencesPersistence: HistoryPreferencesPersistence(),
            historyPersistence: history,
            notifications: HistoryNotifications(),
            now: start
        )

        try controller.importSessions([incoming])

        XCTAssertEqual(Set(controller.sessions.map(\.id)), [local.id, incoming.id])
        XCTAssertEqual(history.saved.last, controller.sessions)
    }

    func testControllerKeepsCurrentHistoryWhenImportCannotBeSaved() {
        let local = session(on: start, minutes: 25)
        let incoming = session(on: start.addingTimeInterval(3_600), minutes: 50)
        let controller = TimerController(
            persistence: HistoryTimerPersistence(),
            preferencesPersistence: HistoryPreferencesPersistence(),
            historyPersistence: HistorySpy(saveError: HistoryTestError.failed, loaded: [local]),
            notifications: HistoryNotifications(),
            now: start
        )

        XCTAssertThrowsError(try controller.importSessions([incoming]))
        XCTAssertEqual(controller.sessions, [local])
    }

    func testControllerCanAddAndFullyEditManualSession() {
        let history = HistorySpy()
        let controller = TimerController(
            persistence: HistoryTimerPersistence(),
            preferencesPersistence: HistoryPreferencesPersistence(),
            historyPersistence: history,
            notifications: HistoryNotifications(),
            now: start
        )

        controller.addSession(
            type: .focus,
            title: "手动会话",
            tag: "工作",
            startedAt: start,
            endedAt: start.addingTimeInterval(25 * 60)
        )
        let id = try! XCTUnwrap(controller.sessions.first?.id)
        controller.updateSession(
            id: id,
            type: .shortBreak,
            title: "手动休息",
            tag: nil,
            startedAt: start.addingTimeInterval(60),
            endedAt: start.addingTimeInterval(11 * 60)
        )

        let updated = controller.sessions.first
        XCTAssertEqual(updated?.type, .shortBreak)
        XCTAssertEqual(updated?.title, "手动休息")
        XCTAssertEqual(updated?.startedAt, start.addingTimeInterval(60))
        XCTAssertEqual(updated?.endedAt, start.addingTimeInterval(11 * 60))
        XCTAssertEqual(updated?.duration, 10 * 60)
        XCTAssertEqual(history.saved.last, controller.sessions)
    }

    func testControllerCanClearStoredSessions() {
        let history = HistorySpy(loaded: [session(on: start, minutes: 25)])
        let controller = TimerController(
            persistence: HistoryTimerPersistence(),
            preferencesPersistence: HistoryPreferencesPersistence(),
            historyPersistence: history,
            notifications: HistoryNotifications(),
            now: start
        )

        controller.deleteAllSessions()

        XCTAssertTrue(controller.sessions.isEmpty)
        XCTAssertEqual(history.saved.last, [])
    }

    private func session(on date: Date, minutes: Int, id: UUID = UUID()) -> FocusSession {
        FocusSession(
            id: id,
            startedAt: date,
            endedAt: date.addingTimeInterval(Double(minutes * 60)),
            duration: Double(minutes * 60),
            completed: true,
            title: "NanaFlow"
        )
    }
}

/// Two throwaway suites so history tests never touch the user's real preferences.
@MainActor
private struct HistoryStores {
    let primaryName = "SessionHistoryPrimary-\(UUID().uuidString)"
    let sharedName = "SessionHistoryShared-\(UUID().uuidString)"
    let primary: UserDefaults
    let shared: UserDefaults
    let persistence: SessionHistoryPersistence

    init() throws {
        primary = try XCTUnwrap(UserDefaults(suiteName: primaryName))
        shared = try XCTUnwrap(UserDefaults(suiteName: sharedName))
        persistence = SessionHistoryPersistence(defaults: primary, sharedDefaults: shared)
    }

    func write(_ sessions: [FocusSession], to defaults: UserDefaults) throws {
        defaults.set(try JSONEncoder().encode(sessions), forKey: SessionHistoryPersistence.storageKey)
    }

    func read(_ defaults: UserDefaults) throws -> [FocusSession] {
        let data = try XCTUnwrap(defaults.data(forKey: SessionHistoryPersistence.storageKey))
        return try JSONDecoder().decode([FocusSession].self, from: data)
    }

    func clear() {
        primary.removePersistentDomain(forName: primaryName)
        shared.removePersistentDomain(forName: sharedName)
    }
}

@MainActor
private final class HistorySpy: SessionHistoryPersisting {
    private let saveError: Error?
    private let loaded: [FocusSession]
    private(set) var saved: [[FocusSession]] = []

    init(saveError: Error? = nil, loaded: [FocusSession] = []) {
        self.saveError = saveError
        self.loaded = loaded
    }

    func load() -> [FocusSession] { loaded }
    func save(_ sessions: [FocusSession]) throws {
        if let saveError { throw saveError }
        saved.append(sessions)
    }
}

private enum HistoryTestError: Error {
    case failed
}

@MainActor
private struct HistoryTimerPersistence: TimerPersisting {
    func load() -> TimerEngine? { nil }
    func save(_: TimerEngine) throws {}
}

@MainActor
private struct HistoryPreferencesPersistence: TimerPreferencesPersisting {
    let loaded: TimerPreferences?

    init(loaded: TimerPreferences? = nil) {
        self.loaded = loaded
    }

    func load() -> TimerPreferences? { loaded }
    func save(_: TimerPreferences) throws {}
}

@MainActor
private struct HistoryNotifications: SessionNotificationScheduling {
    func scheduleCompletion(at _: Date, nextPhase _: SessionPhase, sound _: CompletionSound, volume _: Double, quote _: String?) {}
    func cancelCompletion() {}
}

@MainActor
private final class HistoryCalendarSpy: FocusSessionCalendarRecording {
    private(set) var sessions: [FocusSession] = []
    private(set) var identifiers: [String?] = []

    func record(_ session: FocusSession, calendarIdentifier: String?) {
        sessions.append(session)
        identifiers.append(calendarIdentifier)
    }
}
