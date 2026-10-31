import XCTest
import UserNotifications
@testable import NanaFlow

@MainActor
final class TimerControllerTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 50_000)

    func testCompletionReplacementsKeepLatestIntentAndAbsoluteDeadline() async throws {
        try await CompletionRegressionChecks.orderedSubmission()
    }

    func testNaturalCompletionRetainsAcceptedQueuedAndInFlightRequests() async throws {
        try await CompletionRegressionChecks.naturalCompletionHandoff()
    }

    func testRestoredCompletionOwnsCurrentLegacyRequestWithoutReplayingHistory() async throws {
        try await CompletionRegressionChecks.restoredCompletionHandoff()
    }

    func testLateCallbackDoesNotReplayAnAmbiguouslyAbsentRequest() async throws {
        try await CompletionRegressionChecks.triggerBeforeLateCallback()
    }

    func testRunningSoundChangesRefreshOnlyEffectiveCurrentPhaseRequestWithoutChangingTimerOrHistory() {
        for steps in [0, 1, 7] {
            var engine = TimerEngine(configuration: .standard)
            for _ in 0..<steps { engine.skip(at: start) }
            let persistence = PersistenceSpy(loaded: engine)
            let notifications = NotificationSpy()
            var preferences = TimerPreferences.standard
            preferences.notificationsEnabled = true
            preferences.hideWindowWhenTimerStarts = false
            let controller = TimerController(
                persistence: persistence,
                preferencesPersistence: PreferencesSpy(loaded: preferences),
                historyPersistence: HistoryNoop(), notifications: notifications, now: start
            )
            controller.start(at: start)
            let running = controller.engine
            let phase = running.state.phase
            preferences.setCompletionSound(.harp, for: phase)
            controller.updatePreferences(preferences)
            XCTAssertEqual(notifications.pending?.sound, .harp)
            XCTAssertEqual(notifications.pending?.date, running.state.endDate)
            let scheduled = notifications.scheduled.count
            preferences.setCompletionSound(.none, for: phase == .focus ? .shortBreak : .focus)
            controller.updatePreferences(preferences)
            XCTAssertEqual(notifications.scheduled.count, scheduled, "Inactive sound does not replace current request")
            preferences.notificationVolume = 1.04
            controller.updatePreferences(preferences)
            XCTAssertEqual(notifications.scheduled.count, scheduled, "Same effective volume does not resubmit")
            preferences.notificationVolume = 0
            controller.updatePreferences(preferences)
            XCTAssertEqual(notifications.pending?.volume, 0)
            preferences.notificationsEnabled = false
            controller.updatePreferences(preferences)
            XCTAssertNil(notifications.pending)
            preferences.notificationsEnabled = true
            controller.updatePreferences(preferences)
            XCTAssertEqual(notifications.pending?.date, running.state.endDate)
            XCTAssertEqual(controller.engine, running)
            XCTAssertTrue(controller.sessions.isEmpty)
            XCTAssertEqual(persistence.saved.count, 1)
        }
    }

    func testAutomationCommandsAreIdempotentAndPersistSessionTitle() {
        let persistence = PersistenceSpy()
        let preferences = PreferencesSpy()
        let controller = TimerController(
            persistence: persistence,
            preferencesPersistence: preferences,
            historyPersistence: HistoryNoop(),
            notifications: NotificationSpy(),
            now: start
        )

        controller.start(at: start)
        let deadline = controller.engine.state.endDate
        controller.start(at: start.addingTimeInterval(5))
        XCTAssertEqual(controller.engine.state.endDate, deadline)

        controller.pause(at: start.addingTimeInterval(10))
        controller.pause(at: start.addingTimeInterval(20))
        XCTAssertFalse(controller.engine.state.isRunning)

        controller.updateSessionTitle("  写作  ")
        XCTAssertEqual(controller.phaseTitle, "写作")
        XCTAssertEqual(preferences.saved.last?.sessionTitle, "写作")

        XCTAssertEqual(TimerAutomationCommand(url: URL(string: "nanaflow://skip")!), .skip)
        XCTAssertEqual(TimerAutomationCommand(url: URL(string: "nanaflow://previous")!), .previous)
        XCTAssertNil(TimerAutomationCommand(url: URL(string: "https://example.com")!))
    }

    func testStartingPersistsStateAndSchedulesCompletion() {
        let persistence = PersistenceSpy()
        let notifications = NotificationSpy()
        let controller = TimerController(
            persistence: persistence,
            preferencesPersistence: PreferencesSpy(loaded: TimerPreferences(
                autoStartFocus: false, autoStartBreaks: false,
                notificationSoundEnabled: true, notificationsEnabled: true
            )),
            historyPersistence: HistoryNoop(),
            notifications: notifications,
            now: start
        )

        controller.toggle(at: start)

        XCTAssertTrue(controller.engine.state.isRunning)
        XCTAssertEqual(persistence.saved.count, 1)
        XCTAssertEqual(notifications.scheduledDates, [start.addingTimeInterval(25 * 60)])
        XCTAssertNotNil(notifications.scheduled.first?.quote)
    }

    func testScheduledCompletionCarriesTheNextPhaseAutoStartPolicy() {
        let notifications = NotificationSpy()
        let preferences = TimerPreferences(
            autoStartFocus: false,
            autoStartBreaks: true,
            notificationSoundEnabled: true,
            notificationsEnabled: true
        )
        let controller = TimerController(
            persistence: PersistenceSpy(),
            preferencesPersistence: PreferencesSpy(loaded: preferences),
            historyPersistence: HistoryNoop(),
            notifications: notifications,
            now: start
        )

        controller.start(at: start)

        XCTAssertEqual(notifications.scheduled.last?.nextPhase, .shortBreak)
        XCTAssertEqual(notifications.scheduled.last?.autoStartsNext, true)
    }

    func testMotivationalQuotesCanBeDisabledForCompletionNotification() throws {
        let notifications = NotificationSpy()
        let preferences = TimerPreferences(
            autoStartFocus: false,
            autoStartBreaks: false,
            notificationSoundEnabled: true,
            notificationsEnabled: true,
            motivationalQuotesEnabled: false
        )
        let controller = TimerController(
            persistence: PersistenceSpy(),
            preferencesPersistence: PreferencesSpy(loaded: preferences),
            historyPersistence: HistoryNoop(),
            notifications: notifications,
            now: start
        )

        controller.toggle(at: start)

        XCTAssertNil(try XCTUnwrap(notifications.scheduled.last).quote)
    }

    func testFocusPhaseUsesProductName() {
        let controller = TimerController(
            persistence: PersistenceSpy(),
            preferencesPersistence: PreferencesSpy(),
            historyPersistence: HistoryNoop(),
            notifications: NotificationSpy(),
            now: start
        )

        XCTAssertEqual(controller.phaseTitle, "NanaFlow")
    }

    func testPausingPersistsRemainingTimeAndCancelsCompletion() {
        let persistence = PersistenceSpy()
        let notifications = NotificationSpy()
        let controller = TimerController(
            persistence: persistence,
            preferencesPersistence: PreferencesSpy(),
            historyPersistence: HistoryNoop(),
            notifications: notifications,
            now: start
        )
        controller.toggle(at: start)

        controller.toggle(at: start.addingTimeInterval(60))

        XCTAssertFalse(controller.engine.state.isRunning)
        XCTAssertEqual(controller.remainingSeconds, 24 * 60)
        XCTAssertEqual(persistence.saved.count, 2)
        XCTAssertEqual(notifications.cancelCount, 1)
    }

    func testTickTransitionsExpiredSessionAndPersistsIt() {
        let persistence = PersistenceSpy()
        let notifications = NotificationSpy()
        let controller = TimerController(
            persistence: persistence,
            preferencesPersistence: PreferencesSpy(loaded: TimerPreferences(
                autoStartFocus: false, autoStartBreaks: false,
                notificationSoundEnabled: true, notificationsEnabled: true
            )),
            historyPersistence: HistoryNoop(),
            notifications: notifications,
            now: start
        )
        controller.toggle(at: start)

        controller.tick(at: start.addingTimeInterval(25 * 60 + 1))

        XCTAssertEqual(controller.engine.state.phase, .shortBreak)
        XCTAssertFalse(controller.engine.state.isRunning)
        XCTAssertEqual(persistence.saved.count, 2)
        XCTAssertEqual(notifications.completedDates, [start.addingTimeInterval(25 * 60)])
        XCTAssertEqual(notifications.completedPhases, [.focus])
        XCTAssertEqual(notifications.retired.count, 1)
        XCTAssertNil(notifications.pending)
        XCTAssertEqual(notifications.cancelCount, 0)
        controller.tick(at: start.addingTimeInterval(25 * 60 + 2))
        XCTAssertEqual(notifications.completedDates.count, 1)
        XCTAssertEqual(notifications.scheduled.count, 1)
        XCTAssertEqual(controller.sessions.count, 1)
    }

    func testCelebrationTriggersOnlyWhenTheFinalFocusCompletesIntoLongBreak() {
        let configuration = TimerConfiguration(
            focusDuration: 60,
            shortBreakDuration: 10,
            longBreakDuration: 20,
            sessionsPerCycle: 2
        )
        let finalFocus = TimerEngine(
            configuration: configuration,
            state: TimerState(
                phase: .focus,
                cycleIndex: 1,
                remainingWhenPaused: 60,
                endDate: nil,
                startedAt: nil
            )
        )
        let completed = TimerController(
            configuration: configuration,
            persistence: PersistenceSpy(loaded: finalFocus),
            preferencesPersistence: PreferencesSpy(),
            historyPersistence: HistoryNoop(),
            notifications: NotificationSpy(),
            now: start
        )
        completed.start(at: start)
        completed.tick(at: start.addingTimeInterval(61))

        XCTAssertEqual(completed.engine.state.phase, .longBreak)
        XCTAssertEqual(completed.celebrationSequence, 1)

        let skipped = TimerController(
            configuration: configuration,
            persistence: PersistenceSpy(loaded: finalFocus),
            preferencesPersistence: PreferencesSpy(),
            historyPersistence: HistoryNoop(),
            notifications: NotificationSpy(),
            now: start
        )
        skipped.skip(at: start)

        XCTAssertEqual(skipped.engine.state.phase, .longBreak)
        XCTAssertEqual(skipped.celebrationSequence, 0)
    }

    func testRestoringExpiredStateReconcilesImmediately() {
        var running = TimerEngine(configuration: .standard)
        running.start(at: start)
        let persistence = PersistenceSpy(loaded: running)
        let notifications = NotificationSpy()

        let controller = TimerController(
            persistence: persistence,
            preferencesPersistence: PreferencesSpy(),
            historyPersistence: HistoryNoop(),
            notifications: notifications,
            now: start.addingTimeInterval(25 * 60 + 1)
        )

        XCTAssertEqual(controller.engine.state.phase, .shortBreak)
        XCTAssertEqual(persistence.saved.count, 1)
        XCTAssertEqual(notifications.restoredDates, [start.addingTimeInterval(25 * 60)])
        XCTAssertEqual(notifications.completedDates, notifications.restoredDates)
        XCTAssertEqual(notifications.completedPhases, [.focus])
        XCTAssertTrue(notifications.scheduled.isEmpty)
        XCTAssertEqual(notifications.cancelCount, 0)
    }

    func testRestoringExpiredStateHonorsAutoStartBreakPreference() {
        var running = TimerEngine(configuration: .standard)
        running.start(at: start)
        let preferences = TimerPreferences(
            autoStartFocus: false,
            autoStartBreaks: true,
            notificationSoundEnabled: true,
            notificationsEnabled: true
        )
        let notifications = NotificationSpy()

        let controller = TimerController(
            persistence: PersistenceSpy(loaded: running),
            preferencesPersistence: PreferencesSpy(loaded: preferences),
            historyPersistence: HistoryNoop(),
            notifications: notifications,
            now: start.addingTimeInterval(25 * 60 + 1)
        )

        XCTAssertEqual(controller.engine.state.phase, .shortBreak)
        XCTAssertTrue(controller.engine.state.isRunning)
        XCTAssertEqual(notifications.scheduledDates, [start.addingTimeInterval(30 * 60 + 1)])
        XCTAssertEqual(notifications.completedDates, [start.addingTimeInterval(25 * 60)])
        XCTAssertEqual(notifications.cancelCount, 0)
    }

    func testPersistenceFailureIsVisible() {
        let persistence = PersistenceSpy(saveError: TestError.failed)
        let controller = TimerController(
            persistence: persistence,
            preferencesPersistence: PreferencesSpy(),
            historyPersistence: HistoryNoop(),
            notifications: NotificationSpy(),
            now: start
        )

        controller.toggle(at: start)

        XCTAssertNotNil(controller.errorMessage)
    }

    func testSkipProgressResetAndErrorDismissal() {
        let persistence = PersistenceSpy(saveError: TestError.failed)
        let controller = TimerController(
            persistence: persistence,
            preferencesPersistence: PreferencesSpy(),
            historyPersistence: HistoryNoop(),
            notifications: NotificationSpy(),
            now: start
        )

        controller.skip(at: start)
        XCTAssertEqual(controller.engine.state.phase, .shortBreak)
        XCTAssertEqual(controller.formattedTime, "05:00")
        XCTAssertEqual(controller.progress, 0)

        controller.toggle(at: start)
        controller.tick(at: start.addingTimeInterval(60))
        XCTAssertEqual(controller.progress, 0.2, accuracy: 0.001)

        controller.reset(at: start.addingTimeInterval(60))
        XCTAssertEqual(controller.formattedTime, "05:00")
        XCTAssertFalse(controller.engine.state.isRunning)

        controller.dismissError()
        XCTAssertNil(controller.errorMessage)
    }

    func testPreviousDoesNotAutoStartAndRecordsAStartedSession() {
        let persistence = PersistenceSpy()
        let notifications = NotificationSpy()
        let controller = TimerController(
            persistence: persistence,
            preferencesPersistence: PreferencesSpy(loaded: TimerPreferences(
                autoStartFocus: true,
                autoStartBreaks: true,
                notificationSoundEnabled: true
            )),
            historyPersistence: HistoryNoop(),
            notifications: notifications,
            now: start
        )
        controller.start(at: start)

        controller.previous(at: start.addingTimeInterval(61))

        XCTAssertEqual(controller.engine.state.phase, .focus)
        XCTAssertEqual(controller.formattedTime, "25:00")
        XCTAssertFalse(controller.engine.state.isRunning)
        XCTAssertEqual(notifications.cancelCount, 1)
        XCTAssertEqual(controller.sessions.first?.duration, 61)
    }

    func testCompletedFocusAutoStartsBreakWithSoundPreference() {
        let persistence = PersistenceSpy()
        let notifications = NotificationSpy()
        let preferences = TimerPreferences(
            autoStartFocus: false,
            autoStartBreaks: true,
            notificationSoundEnabled: false,
            notificationsEnabled: true
        )
        let controller = TimerController(
            persistence: persistence,
            preferencesPersistence: PreferencesSpy(loaded: preferences),
            historyPersistence: HistoryNoop(),
            notifications: notifications,
            now: start
        )
        controller.toggle(at: start)

        controller.tick(at: start.addingTimeInterval(25 * 60 + 1))

        XCTAssertEqual(controller.engine.state.phase, .shortBreak)
        XCTAssertTrue(controller.engine.state.isRunning)
        XCTAssertEqual(notifications.scheduled.count, 2)
        XCTAssertEqual(notifications.scheduled.last?.sound, CompletionSound.none)
        XCTAssertEqual(notifications.retired.count, 1)
        XCTAssertEqual(notifications.pending?.date, controller.engine.state.endDate)
        XCTAssertEqual(notifications.cancelCount, 0)
    }

    func testConfigurationChangePersistsAndUpdatesPausedTimer() {
        let persistence = PersistenceSpy()
        let controller = TimerController(
            persistence: persistence,
            preferencesPersistence: PreferencesSpy(),
            historyPersistence: HistoryNoop(),
            notifications: NotificationSpy(),
            now: start
        )
        let updated = TimerConfiguration(
            focusDuration: 45 * 60,
            shortBreakDuration: 8 * 60,
            longBreakDuration: 20 * 60,
            sessionsPerCycle: 3
        )

        controller.updateConfiguration(updated, at: start)

        XCTAssertEqual(controller.engine.configuration, updated)
        XCTAssertEqual(controller.remainingSeconds, 45 * 60)
        XCTAssertEqual(persistence.saved.last?.configuration, updated)
    }

    func testPreferencesFailureIsVisible() {
        let controller = TimerController(
            persistence: PersistenceSpy(),
            preferencesPersistence: PreferencesSpy(saveError: TestError.failed),
            historyPersistence: HistoryNoop(),
            notifications: NotificationSpy(),
            now: start
        )

        controller.updatePreferences(
            TimerPreferences(autoStartFocus: true, autoStartBreaks: true, notificationSoundEnabled: false)
        )

        XCTAssertNotNil(controller.errorMessage)
    }

    func testPreferencesChangePersists() {
        let preferencesPersistence = PreferencesSpy()
        let controller = TimerController(
            persistence: PersistenceSpy(),
            preferencesPersistence: preferencesPersistence,
            historyPersistence: HistoryNoop(),
            notifications: NotificationSpy(),
            now: start
        )
        let preferences = TimerPreferences(
            autoStartFocus: true,
            autoStartBreaks: false,
            notificationSoundEnabled: false
        )

        controller.updatePreferences(preferences)

        XCTAssertEqual(controller.preferences, preferences)
        XCTAssertEqual(preferencesPersistence.saved, [preferences])
        XCTAssertNil(controller.errorMessage)
    }

    func testDurationPresetUpdatesOnlyProvidedValues() {
        let controller = TimerController(
            persistence: PersistenceSpy(),
            preferencesPersistence: PreferencesSpy(),
            historyPersistence: HistoryNoop(),
            notifications: NotificationSpy(),
            now: start
        )

        controller.updateDurations(focusMinutes: 45, longBreakMinutes: 20, cycle: 6, at: start)

        XCTAssertEqual(controller.engine.configuration.focusDuration, 45 * 60)
        XCTAssertEqual(controller.engine.configuration.shortBreakDuration, 5 * 60)
        XCTAssertEqual(controller.engine.configuration.longBreakDuration, 20 * 60)
        XCTAssertEqual(controller.engine.configuration.sessionsPerCycle, 6)
    }

    func testCommitmentModePreventsPausingSkippingAndResettingFocus() {
        let preferencesPersistence = PreferencesSpy(
            loaded: TimerPreferences(
                autoStartFocus: false,
                autoStartBreaks: false,
                notificationSoundEnabled: true,
                commitmentModeEnabled: true
            )
        )
        let controller = TimerController(
            persistence: PersistenceSpy(),
            preferencesPersistence: preferencesPersistence,
            historyPersistence: HistoryNoop(),
            notifications: NotificationSpy(),
            now: start
        )
        controller.toggle(at: start)
        let deadline = controller.engine.state.endDate

        controller.toggle(at: start.addingTimeInterval(10))
        controller.skip(at: start.addingTimeInterval(10))
        controller.reset(at: start.addingTimeInterval(10))
        controller.previous(at: start.addingTimeInterval(10))

        XCTAssertTrue(controller.engine.state.isRunning)
        XCTAssertEqual(controller.engine.state.phase, .focus)
        XCTAssertEqual(controller.engine.state.endDate, deadline)

        var updated = controller.preferences
        updated.commitmentModeEnabled = false
        controller.updatePreferences(updated)

        XCTAssertTrue(controller.isCommittedFocus)
        XCTAssertEqual(preferencesPersistence.saved.last?.commitmentModeEnabled, true)
    }

    func testNotificationCancellationIsSafeWithoutPendingRequest() {
        SessionNotificationScheduler().cancelCompletion()
    }

    func testLaunchPreferencesResetCycleAndStartFocus() {
        var loaded = TimerEngine(configuration: .standard)
        loaded.skip(at: start)
        loaded.skip(at: start)
        loaded.skip(at: start)
        let preferences = TimerPreferences(
            autoStartFocus: false,
            autoStartBreaks: false,
            notificationSoundEnabled: true,
            resetCycleOnLaunch: true,
            startTimerOnLaunch: true,
            notificationsEnabled: false
        )
        let notifications = NotificationSpy()

        let controller = TimerController(
            persistence: PersistenceSpy(loaded: loaded),
            preferencesPersistence: PreferencesSpy(loaded: preferences),
            historyPersistence: HistoryNoop(),
            notifications: notifications,
            now: start
        )

        XCTAssertEqual(controller.engine.state.phase, .focus)
        XCTAssertEqual(controller.engine.state.cycleIndex, 0)
        XCTAssertTrue(controller.engine.state.isRunning)
        XCTAssertTrue(controller.didStartTimerAtLaunch)
        XCTAssertTrue(notifications.scheduled.isEmpty)
    }

    func testDisabledNotificationsDoNotScheduleCompletion() {
        let preferences = TimerPreferences(
            autoStartFocus: false,
            autoStartBreaks: false,
            notificationSoundEnabled: true,
            notificationsEnabled: false
        )
        let notifications = NotificationSpy()
        let controller = TimerController(
            persistence: PersistenceSpy(),
            preferencesPersistence: PreferencesSpy(loaded: preferences),
            historyPersistence: HistoryNoop(),
            notifications: notifications,
            now: start
        )

        controller.toggle(at: start)

        XCTAssertTrue(notifications.scheduled.isEmpty)
    }

    func testTickingSoundPlaysOncePerElapsedSecondWhileFocusRuns() {
        let sound = TickSoundSpy()
        let preferences = TimerPreferences(
            autoStartFocus: false,
            autoStartBreaks: false,
            notificationSoundEnabled: false,
            tickingSoundEnabled: true,
            tickingVolume: 1.4,
            notificationsEnabled: false
        )
        let controller = TimerController(
            persistence: PersistenceSpy(),
            preferencesPersistence: PreferencesSpy(loaded: preferences),
            historyPersistence: HistoryNoop(),
            notifications: NotificationSpy(),
            tickSound: sound,
            now: start
        )
        controller.toggle(at: start)

        controller.tick(at: start.addingTimeInterval(1.1))
        controller.tick(at: start.addingTimeInterval(1.2))
        controller.tick(at: start.addingTimeInterval(2.1))

        XCTAssertEqual(sound.playCount, 2)
        XCTAssertEqual(sound.volumes, [1.4, 1.4])
    }
}

@MainActor
private final class PersistenceSpy: TimerPersisting {
    private let loaded: TimerEngine?
    private let saveError: Error?
    private(set) var saved: [TimerEngine] = []

    init(loaded: TimerEngine? = nil, saveError: Error? = nil) {
        self.loaded = loaded
        self.saveError = saveError
    }

    func load() -> TimerEngine? { loaded }

    func save(_ engine: TimerEngine) throws {
        if let saveError { throw saveError }
        saved.append(engine)
    }
}

@MainActor
private final class NotificationSpy: SessionNotificationScheduling {
    struct Scheduled {
        let date: Date
        let nextPhase: SessionPhase
        let autoStartsNext: Bool
        let sound: CompletionSound
        let volume: Double
        let quote: String?
    }

    private(set) var scheduled: [Scheduled] = []
    var scheduledDates: [Date] { scheduled.map(\.date) }
    private(set) var cancelCount = 0
    private(set) var pending: Scheduled?
    private(set) var retired: [Scheduled] = []
    private(set) var restoredDates: [Date] = []
    private(set) var completedDates: [Date] = []
    private(set) var completedPhases: [SessionPhase] = []

    func scheduleCompletion(at date: Date, nextPhase: SessionPhase, sound: CompletionSound, volume: Double, quote: String?) {
        scheduled.append(Scheduled(
            date: date,
            nextPhase: nextPhase,
            autoStartsNext: false,
            sound: sound,
            volume: volume,
            quote: quote
        ))
        pending = scheduled.last
    }

    func scheduleCompletion(
        at date: Date,
        nextPhase: SessionPhase,
        autoStartsNext: Bool,
        sound: CompletionSound,
        volume: Double,
        quote: String?
    ) {
        scheduled.append(Scheduled(
            date: date,
            nextPhase: nextPhase,
            autoStartsNext: autoStartsNext,
            sound: sound,
            volume: volume,
            quote: quote
        ))
        pending = scheduled.last
    }

    func restoreCompletion(at date: Date, phase: SessionPhase) {
        restoredDates.append(date)
    }

    func completeCompletion(at date: Date, phase: SessionPhase) {
        completedDates.append(date)
        completedPhases.append(phase)
        if let pending, pending.date == date { retired.append(pending) }
        pending = nil
    }

    func cancelCompletion() {
        cancelCount += 1
        pending = nil
    }
}

@MainActor
private final class TickSoundSpy: TimerTickSoundPlaying {
    private(set) var playCount = 0
    private(set) var volumes: [Double] = []

    func playTick(volume: Double) {
        playCount += 1
        volumes.append(volume)
    }
}

@MainActor
private final class PreferencesSpy: TimerPreferencesPersisting {
    private let loaded: TimerPreferences?
    private let saveError: Error?
    private(set) var saved: [TimerPreferences] = []

    init(loaded: TimerPreferences? = nil, saveError: Error? = nil) {
        self.loaded = loaded
        self.saveError = saveError
    }

    func load() -> TimerPreferences? { loaded }

    func save(_ preferences: TimerPreferences) throws {
        if let saveError { throw saveError }
        saved.append(preferences)
    }
}

@MainActor
private struct HistoryNoop: SessionHistoryPersisting {
    func load() -> [FocusSession] { [] }
    func save(_: [FocusSession]) throws {}
}

private enum TestError: Error {
    case failed
}

@MainActor
private enum CompletionRegressionChecks {
    struct Failure: Error { let message: String }
    static func check(_ condition: Bool, _ message: String) throws {
        if !condition { throw Failure(message: message) }
    }
    static func orderedSubmission() async throws {
        var clock = Date(timeIntervalSince1970: 50_000)
        let port=ControlledCenter(now: { clock })
        let scheduler=SessionNotificationScheduler(submission:port, now: { clock })
        let deadline=clock.addingTimeInterval(300)
        scheduler.scheduleCompletion(at:deadline,nextPhase:.shortBreak,sound:.bell,volume:2,quote:nil)
        await port.waitForAdds(1)
        try check(port.inFlight.count == 1, "first asynchronous add is deliberately held")
        scheduler.scheduleCompletion(at:deadline,nextPhase:.shortBreak,sound:.harp,volume:1,quote:nil)
        scheduler.scheduleCompletion(at:deadline,nextPhase:.shortBreak,sound:.none,volume:0,quote:nil)
        clock = clock.addingTimeInterval(20)
        port.finishOne()
        await port.waitForAdds(2)
        try check((port.inFlight.first?.request.trigger as? UNTimeIntervalNotificationTrigger)?.timeInterval == 280, "queued replacement retains absolute deadline")
        try check(port.inFlight.count == 1 && port.pending.isEmpty, "stale add removed before final add")
        port.finishOne()
        await scheduler.waitForPendingSubmissions()
        try check(port.pending.count == 1 && port.pending.values.first?.content.sound == nil, "A to B to None leaves exactly final silent request")
        scheduler.scheduleCompletion(at:deadline,nextPhase:.focus,sound:.bell,volume:2,quote:nil)
        await port.waitForAdds(3)
        let cancelledIdentifier = port.inFlight[0].request.identifier
        port.deferredRemovalIdentifiers.insert(cancelledIdentifier)
        scheduler.cancelCompletion();port.finishOne()
        scheduler.scheduleCompletion(at:deadline.addingTimeInterval(60),nextPhase:.shortBreak,sound:.harp,volume:1,quote:nil)
        await port.waitForAdds(4)
        let successorIdentifier = port.inFlight[0].request.identifier
        try check(cancelledIdentifier != successorIdentifier, "successor has its own phase/deadline identifier")
        port.finishOne()
        await scheduler.waitForPendingSubmissions()
        port.applyDeferredRemovals()
        try check(port.pending.count == 1 && port.pending[successorIdentifier] != nil, "late cancelled-add cleanup cannot remove successor")
        scheduler.cancelCompletion()
        await scheduler.waitForPendingSubmissions()
        try check(port.pending.isEmpty, "cancel while add in-flight cannot resurrect notification")
    }

    static func naturalCompletionHandoff() async throws {
        for steps in [0, 1, 7] {
            for autoStart in [false, true] {
                for stage in ["accepted", "inFlight", "queued"] {
                    let suite = "TimerControllerTests-Completion-\(UUID().uuidString)"
                    let defaults = UserDefaults(suiteName: suite)!
                    defer { defaults.removePersistentDomain(forName: suite) }
                    let start = Date(timeIntervalSince1970: 50_000)
                    var clock = start
                    let port = ControlledCenter(now: { clock })
                    let scheduler = SessionNotificationScheduler(submission: port, now: { clock })
                    let controller = try completionController(defaults: defaults, scheduler: scheduler, start: start, steps: steps, autoStart: autoStart)
                    controller.start(at: start)
                    let original = controller.engine
                    let deadline = original.state.endDate!
                    let identifier = SessionNotificationScheduler.notificationIdentifier(at: deadline, phase: original.state.phase)
                    await port.waitForAdds(1)
                    if stage != "queued" {
                        port.finishOne()
                        await scheduler.waitForPendingSubmissions()
                    }
                    clock = deadline.addingTimeInterval(-0.25)
                    var prefs = controller.preferences
                    prefs.setCompletionSound(.harp, for: original.state.phase)
                    controller.updatePreferences(prefs)
                    if stage == "queued" {
                        prefs.setCompletionSound(.none, for: original.state.phase)
                        controller.updatePreferences(prefs)
                    } else {
                        await port.waitForAdds(2)
                        port.registerOne()
                        try check(port.triggerDates[identifier] == deadline.addingTimeInterval(0.75), "near-deadline refresh deliberately has an unmet OS trigger")
                        if stage == "accepted" {
                            port.finishOne()
                            await scheduler.waitForPendingSubmissions()
                        }
                    }
                    try check(controller.engine == original, "preference refresh preserves the original engine/deadline")
                    clock = deadline
                    controller.tick(at: clock)
                    controller.tick(at: clock.addingTimeInterval(0.01))
                    try check(controller.engine.state.isRunning == autoStart && controller.sessions.count == 1, "natural transition and repeated tick retain auto-start/history semantics")
                    if stage != "accepted" {
                        clock = deadline.addingTimeInterval(0.1)
                        port.finishOne()
                        if stage == "queued" {
                            await port.waitForAdds(2)
                            port.finishOne()
                        }
                    }
                    if autoStart {
                        await port.waitForAdds(3)
                        let next = port.inFlight[0].request
                        try check(next.identifier != identifier, "next phase cannot replace the completed phase identifier")
                        port.finishOne()
                    }
                    await scheduler.waitForPendingSubmissions()
                    let completion = port.pending[identifier]
                    try check(completion != nil && (completion?.content.sound == nil) == (stage == "queued"), "latest completed-phase intent survives accepted/queued/in-flight handoff")
                    try check(port.pending.count == (autoStart ? 2 : 1), "one completed request plus exactly one effective current-phase request when running")
                    if autoStart {
                        let nextDeadline = controller.engine.state.endDate!
                        let nextID = SessionNotificationScheduler.notificationIdentifier(at: nextDeadline, phase: controller.engine.state.phase)
                        try check(port.triggerDates[nextID] == nextDeadline, "queued successor retains its original absolute deadline")
                    }
                    clock = deadline.addingTimeInterval(1.2)
                    port.fireDue()
                    // A met trigger is protected even if presentation is held.
                    port.removePending(identifiers: [identifier])
                    try check(port.triggered.contains(where: { $0.identifier == identifier }) && port.presented.isEmpty, "trigger and presentation are independently controlled")
                    port.presentTriggered()
                    port.fireDue(); port.presentTriggered()
                    try check(port.presented.count == 1, "one presentation per completed phase, without replay")
                    if autoStart {
                        controller.pause(at: clock)
                        await scheduler.waitForPendingSubmissions()
                    }
                    try check(port.pending.isEmpty && controller.sessions.count == 1, "pause removes successor future request without deleting completed delivery")
                }
            }
        }
    }

    static func restoredCompletionHandoff() async throws {
        for steps in [0, 1, 7] {
            for autoStart in [false, true] {
                for legacy in [false, true] {
                    let suite = "TimerControllerTests-Restore-\(UUID().uuidString)"
                    let defaults = UserDefaults(suiteName: suite)!
                    defer { defaults.removePersistentDomain(forName: suite) }
                    let start = Date(timeIntervalSince1970: 50_000)
                    var clock = start
                    let port = ControlledCenter(now: { clock })
                    let initial = SessionNotificationScheduler(submission: port, now: { clock })
                    let first = try completionController(defaults: defaults, scheduler: initial, start: start, steps: steps, autoStart: autoStart)
                    first.start(at: start)
                    let expired = first.engine
                    let deadline = expired.state.endDate!
                    await port.waitForAdds(1); port.finishOne()
                    await initial.waitForPendingSubmissions()
                    let oldID = SessionNotificationScheduler.notificationIdentifier(at: deadline, phase: expired.state.phase)
                    let old = port.pending.removeValue(forKey: oldID)!
                    port.triggerDates.removeValue(forKey: oldID)
                    let identifier = legacy ? SessionNotificationScheduler.legacyNotificationIdentifier : oldID
                    port.seed(UNNotificationRequest(identifier: identifier, content: old.content, trigger: old.trigger), triggerDate: deadline.addingTimeInterval(0.75))
                    clock = deadline
                    let scheduler = SessionNotificationScheduler(submission: port, now: { clock })
                    let restored = completionController(defaults: defaults, scheduler: scheduler, now: clock)
                    if autoStart {
                        await port.waitForAdds(2); port.finishOne()
                    }
                    await scheduler.waitForPendingSubmissions()
                    try check(port.attempts.count == (autoStart ? 2 : 1) && port.pending[identifier] != nil, "expired restore never re-adds or deletes prior stable/legacy notification")
                    try check(restored.sessions.count == 1 && restored.engine.state.isRunning == autoStart, "restored natural transition preserves history and auto-start")
                    // Restart once more inside the predecessor trigger window.
                    if autoStart {
                        let restartedScheduler = SessionNotificationScheduler(submission: port, now: { clock })
                        let restarted = completionController(defaults: defaults, scheduler: restartedScheduler, now: clock)
                        restarted.pause(at: clock.addingTimeInterval(0.1))
                        await restartedScheduler.waitForPendingSubmissions()
                        try check(port.pending.count == 1 && port.pending[identifier] != nil, "restored successor cancellation preserves the predecessor legacy/stable request")
                    }
                    clock = deadline.addingTimeInterval(1)
                    port.fireDue(); port.presentTriggered()
                    let replayScheduler = SessionNotificationScheduler(submission: port, now: { clock })
                    _ = completionController(defaults: defaults, scheduler: replayScheduler, now: clock)
                    await replayScheduler.waitForPendingSubmissions()
                    try check(port.pending.isEmpty && port.presented.count == 1, "historical expiry and later restart never replay completion")
                }
            }
        }
        // A future legacy request of the restored current phase is still cancellable.
        for phase in [SessionPhase.focus, .shortBreak, .longBreak] {
            let clock = Date(timeIntervalSince1970: 50_000)
            let deadline = clock.addingTimeInterval(60)
            let port = ControlledCenter(now: { clock })
            let content = UNMutableNotificationContent()
            content.categoryIdentifier = SessionNotificationContract.categoryIdentifier(nextPhase: phase == .focus ? .shortBreak : .focus, autoStartsNext: false)
            port.seed(UNNotificationRequest(identifier: SessionNotificationScheduler.legacyNotificationIdentifier, content: content, trigger: nil), triggerDate: deadline)
            let scheduler = SessionNotificationScheduler(submission: port, now: { clock })
            scheduler.restoreCompletion(at: deadline, phase: phase)
            scheduler.cancelCompletion()
            await scheduler.waitForPendingSubmissions()
            try check(port.pending.isEmpty && port.attempts.isEmpty, "explicit cancellation removes restored current-phase legacy future request without adding")
        }
    }

    private static func completionController(defaults: UserDefaults, scheduler: SessionNotificationScheduler, start: Date, steps: Int, autoStart: Bool) throws -> TimerController {
        var preferences = TimerPreferences.standard
        preferences.notificationsEnabled = true
        preferences.hideWindowWhenTimerStarts = false
        preferences.motivationalQuotesEnabled = false
        preferences.autoStartFocus = autoStart
        preferences.autoStartBreaks = autoStart
        try TimerPreferencesPersistence(defaults: defaults).save(preferences)
        var engine = TimerEngine(configuration: TimerConfiguration(focusDuration: 300, shortBreakDuration: 60, longBreakDuration: 90, sessionsPerCycle: 4))
        for _ in 0..<steps { engine.skip(at: start) }
        try TimerPersistence(defaults: defaults).save(engine)
        return completionController(defaults: defaults, scheduler: scheduler, now: start)
    }

    private static func completionController(defaults: UserDefaults, scheduler: SessionNotificationScheduler, now: Date) -> TimerController {
        TimerController(persistence: TimerPersistence(defaults: defaults), preferencesPersistence: TimerPreferencesPersistence(defaults: defaults), historyPersistence: SessionHistoryPersistence(defaults: defaults), notifications: scheduler, now: now)
    }

    static func triggerBeforeLateCallback() async throws {
        for oldTriggerSurvivesRemoval in [false, true] {
        var clock = Date(timeIntervalSince1970: 50_000)
        let deadline = clock.addingTimeInterval(10)
        let port = ControlledCenter(now: { clock })
        let scheduler = SessionNotificationScheduler(submission: port, now: { clock })
        scheduler.scheduleCompletion(at: deadline, phase: .focus, nextPhase: .shortBreak, autoStartsNext: false, sound: .bell, volume: 1, quote: nil)
        await port.waitForAdds(1)
        port.registerOne()
        let identifier = port.inFlight[0].request.identifier
        // The asynchronous removal has not taken effect before the old trigger.
        if oldTriggerSurvivesRemoval { port.deferredRemovalIdentifiers.insert(identifier) }
        clock = deadline.addingTimeInterval(-0.25)
        scheduler.scheduleCompletion(at: deadline, phase: .focus, nextPhase: .shortBreak, autoStartsNext: false, sound: .harp, volume: 1, quote: nil)
        clock = deadline
        port.fireDue()
        scheduler.completeCompletion(at: deadline, phase: .focus)
        let expected = oldTriggerSurvivesRemoval ? 1 : 0
        try check(port.triggerOccurrences.count == expected && port.presented.isEmpty, "registration, trigger, add callback and presentation remain distinct")
        clock = deadline.addingTimeInterval(0.1)
        port.completeNewAddsImmediately = true
        port.finishOne()
        await scheduler.waitForPendingSubmissions()
        clock = deadline.addingTimeInterval(2)
        port.fireDue(); port.presentTriggered()
        try check(port.triggerOccurrences.count == expected && port.presented.count == expected && port.attempts.count == 1, "late absent request is not replayed: ambiguous removal may lose latest intent, never inferred as delivery")
        port.applyDeferredRemovals()
        }
    }
    final class ControlledCenter: CompletionNotificationSubmitting {
        struct InFlight {
            let request: UNNotificationRequest
            let continuation: CheckedContinuation<Void, Error>
            var registered = false
        }
        let now: () -> Date
        var pending: [String: UNNotificationRequest] = [:]
        var triggerDates: [String: Date] = [:]
        var triggered: [UNNotificationRequest] = []
        var triggerOccurrences: [UNNotificationRequest] = []
        var presented: [UNNotificationRequest] = []
        var attempts: [UNNotificationRequest] = []
        var inFlight: [InFlight] = []
        var deferredRemovalIdentifiers: Set<String> = []
        var completeNewAddsImmediately = false
        private var deferredRemovals: [String] = []
        private var addWaiters: [(Int, CheckedContinuation<Void, Never>)] = []
        init(now: @escaping () -> Date = { Date() }) { self.now = now }
        func add(_ request:UNNotificationRequest) async throws {
            try await withCheckedThrowingContinuation {
                inFlight.append(InFlight(request: request, continuation: $0))
                attempts.append(request)
                let ready = addWaiters.filter { $0.0 <= attempts.count }
                addWaiters.removeAll { $0.0 <= attempts.count }
                for (_, continuation) in ready { continuation.resume() }
                if completeNewAddsImmediately { finishOne() }
            }
        }
        func waitForAdds(_ count: Int) async {
            if attempts.count >= count { return }
            await withCheckedContinuation { addWaiters.append((count, $0)) }
        }
        func pendingRequests() async -> [UNNotificationRequest] {
            fireDue()
            return Array(pending.values)
        }
        func seed(_ request: UNNotificationRequest, triggerDate: Date) {
            pending[request.identifier] = request
            triggerDates[request.identifier] = triggerDate
        }
        func registerOne() {
            guard !inFlight.isEmpty, !inFlight[0].registered else { return }
            let request = inFlight[0].request
            let interval = (request.trigger as? UNTimeIntervalNotificationTrigger)?.timeInterval ?? 0
            seed(request, triggerDate: now().addingTimeInterval(interval))
            inFlight[0].registered = true
        }
        func finishOne() {
            guard !inFlight.isEmpty else { return }
            registerOne()
            inFlight.removeFirst().continuation.resume()
        }
        func removePending(identifiers: [String]) {
            fireDue()
            for identifier in identifiers {
                if deferredRemovalIdentifiers.contains(identifier) { deferredRemovals.append(identifier) }
                else { pending.removeValue(forKey: identifier); triggerDates.removeValue(forKey: identifier) }
            }
        }
        func applyDeferredRemovals() {
            let identifiers = deferredRemovals
            deferredRemovals.removeAll()
            deferredRemovalIdentifiers.removeAll()
            removePending(identifiers: identifiers)
        }
        func fireDue() {
            for identifier in triggerDates.keys.filter({ triggerDates[$0]! <= now() }) {
                if let request = pending.removeValue(forKey: identifier) {
                    triggered.append(request)
                    triggerOccurrences.append(request)
                }
                triggerDates.removeValue(forKey: identifier)
            }
        }
        func presentTriggered() {
            presented.append(contentsOf: triggered)
            triggered.removeAll()
        }
    }
}
