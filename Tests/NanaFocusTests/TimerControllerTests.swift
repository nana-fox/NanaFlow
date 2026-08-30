import XCTest
@testable import NanaFlow

@MainActor
final class TimerControllerTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 50_000)

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
            historyPersistence: HistoryNoop(),
            notifications: notifications,
            now: start
        )
        controller.toggle(at: start)

        controller.tick(at: start.addingTimeInterval(25 * 60 + 1))

        XCTAssertEqual(controller.engine.state.phase, .shortBreak)
        XCTAssertFalse(controller.engine.state.isRunning)
        XCTAssertEqual(persistence.saved.count, 2)
        XCTAssertEqual(notifications.cancelCount, 1)
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
            historyPersistence: HistoryNoop(),
            notifications: notifications,
            now: start.addingTimeInterval(25 * 60 + 1)
        )

        XCTAssertEqual(controller.engine.state.phase, .shortBreak)
        XCTAssertEqual(persistence.saved.count, 1)
    }

    func testRestoringExpiredStateHonorsAutoStartBreakPreference() {
        var running = TimerEngine(configuration: .standard)
        running.start(at: start)
        let preferences = TimerPreferences(
            autoStartFocus: false,
            autoStartBreaks: true,
            notificationSoundEnabled: true
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
    }

    func testPersistenceFailureIsVisible() {
        let persistence = PersistenceSpy(saveError: TestError.failed)
        let controller = TimerController(
            persistence: persistence,
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
            notificationSoundEnabled: false
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

    func scheduleCompletion(at date: Date, nextPhase: SessionPhase, sound: CompletionSound, volume: Double, quote: String?) {
        scheduled.append(Scheduled(
            date: date,
            nextPhase: nextPhase,
            autoStartsNext: false,
            sound: sound,
            volume: volume,
            quote: quote
        ))
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
    }

    func cancelCompletion() {
        cancelCount += 1
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
