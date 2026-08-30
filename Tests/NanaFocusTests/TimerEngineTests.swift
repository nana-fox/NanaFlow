import XCTest
@testable import NanaFlow

final class TimerEngineTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_000)

    func testStartsWithStandardFocusSessionPaused() {
        let engine = TimerEngine(configuration: .standard)

        XCTAssertEqual(engine.state.phase, .focus)
        XCTAssertEqual(engine.state.cycleIndex, 0)
        XCTAssertEqual(engine.remaining(at: start), 25 * 60)
        XCTAssertFalse(engine.state.isRunning)
    }

    func testRunningTimerUsesWallClockAndPauseFreezesRemainingTime() {
        var engine = TimerEngine(configuration: .standard)

        engine.start(at: start)
        XCTAssertEqual(engine.remaining(at: start.addingTimeInterval(90)), 24 * 60 - 30)

        engine.pause(at: start.addingTimeInterval(90))
        XCTAssertEqual(engine.remaining(at: start.addingTimeInterval(900)), 24 * 60 - 30)
        XCTAssertFalse(engine.state.isRunning)
    }

    func testStartingAnAlreadyRunningTimerKeepsItsDeadline() {
        var engine = TimerEngine(configuration: .standard)
        engine.start(at: start)
        let deadline = engine.state.endDate

        engine.start(at: start.addingTimeInterval(60))

        XCTAssertEqual(engine.state.endDate, deadline)
    }

    func testStartingAnExpiredPausedSessionAdvancesBeforeRunning() {
        let state = TimerState(
            phase: .focus,
            cycleIndex: 0,
            remainingWhenPaused: 0,
            endDate: nil,
            startedAt: nil
        )
        var engine = TimerEngine(configuration: .standard, state: state)

        engine.start(at: start)

        XCTAssertEqual(engine.state.phase, .shortBreak)
        XCTAssertEqual(engine.state.endDate, start.addingTimeInterval(5 * 60))
    }

    func testFocusAndBreakAdvanceThroughFourSessionCycle() {
        var engine = TimerEngine(configuration: .standard)

        engine.skip(at: start)
        XCTAssertEqual(engine.state.phase, .shortBreak)
        XCTAssertEqual(engine.state.cycleIndex, 0)
        XCTAssertEqual(engine.remaining(at: start), 5 * 60)

        engine.skip(at: start)
        XCTAssertEqual(engine.state.phase, .focus)
        XCTAssertEqual(engine.state.cycleIndex, 1)

        for expectedCycle in 1 ... 2 {
            engine.skip(at: start)
            XCTAssertEqual(engine.state.phase, .shortBreak)
            XCTAssertEqual(engine.state.cycleIndex, expectedCycle)
            engine.skip(at: start)
            XCTAssertEqual(engine.state.phase, .focus)
            XCTAssertEqual(engine.state.cycleIndex, expectedCycle + 1)
        }

        engine.skip(at: start)
        XCTAssertEqual(engine.state.phase, .longBreak)
        XCTAssertEqual(engine.remaining(at: start), 30 * 60)

        engine.skip(at: start)
        XCTAssertEqual(engine.state.phase, .focus)
        XCTAssertEqual(engine.state.cycleIndex, 0)
    }

    func testExpiredRunningTimerReconcilesToNextPausedSession() {
        var engine = TimerEngine(configuration: .standard)
        engine.start(at: start)

        let didAdvance = engine.reconcile(at: start.addingTimeInterval(25 * 60 + 10))

        XCTAssertTrue(didAdvance)
        XCTAssertEqual(engine.state.phase, .shortBreak)
        XCTAssertEqual(engine.remaining(at: start), 5 * 60)
        XCTAssertFalse(engine.state.isRunning)
    }

    func testResetRestoresFullCurrentDurationAndPauses() {
        var engine = TimerEngine(configuration: .standard)
        engine.start(at: start)

        engine.reset(at: start.addingTimeInterval(123))

        XCTAssertEqual(engine.state.phase, .focus)
        XCTAssertEqual(engine.remaining(at: start.addingTimeInterval(999)), 25 * 60)
        XCTAssertFalse(engine.state.isRunning)
    }

    func testPreviousReloadsStartedSessionOrNavigatesBackFromPendingSession() {
        var engine = TimerEngine(configuration: .standard)

        engine.previous(at: start)
        XCTAssertEqual(engine.state.phase, .focus)
        XCTAssertEqual(engine.state.cycleIndex, 0)

        engine.skip(at: start)
        engine.previous(at: start)
        XCTAssertEqual(engine.state.phase, .focus)
        XCTAssertEqual(engine.state.cycleIndex, 0)

        engine.skip(at: start)
        engine.skip(at: start)
        engine.previous(at: start)
        XCTAssertEqual(engine.state.phase, .shortBreak)
        XCTAssertEqual(engine.state.cycleIndex, 0)

        engine.start(at: start)
        engine.previous(at: start.addingTimeInterval(60))
        XCTAssertEqual(engine.state.phase, .shortBreak)
        XCTAssertEqual(engine.remaining(at: start.addingTimeInterval(999)), 5 * 60)
        XCTAssertFalse(engine.state.isRunning)

        engine = TimerEngine(configuration: .standard, state: TimerState(
            phase: .longBreak,
            cycleIndex: 3,
            remainingWhenPaused: 30 * 60,
            endDate: nil,
            startedAt: nil
        ))
        engine.previous(at: start)
        XCTAssertEqual(engine.state.phase, .focus)
        XCTAssertEqual(engine.state.cycleIndex, 3)
    }

    func testInvalidConfigurationIsClampedToSafeValues() {
        let configuration = TimerConfiguration(
            focusDuration: -1,
            shortBreakDuration: 0,
            longBreakDuration: -100,
            sessionsPerCycle: 0
        )
        let engine = TimerEngine(configuration: configuration)

        XCTAssertEqual(engine.remaining(at: start), 1)
        XCTAssertEqual(engine.configuration.sessionsPerCycle, 1)
    }

    func testUpdatingConfigurationResetsPausedSessionToNewDuration() {
        var engine = TimerEngine(configuration: .standard)
        let updated = TimerConfiguration(
            focusDuration: 50 * 60,
            shortBreakDuration: 10 * 60,
            longBreakDuration: 20 * 60,
            sessionsPerCycle: 2
        )

        engine.updateConfiguration(updated, at: start)

        XCTAssertEqual(engine.configuration, updated)
        XCTAssertEqual(engine.remaining(at: start), 50 * 60)
        XCTAssertEqual(engine.state.cycleIndex, 0)
    }

    func testUpdatingConfigurationKeepsRunningSessionDeadline() {
        var engine = TimerEngine(configuration: .standard)
        engine.start(at: start)
        let updated = TimerConfiguration(
            focusDuration: 50 * 60,
            shortBreakDuration: 10 * 60,
            longBreakDuration: 20 * 60,
            sessionsPerCycle: 2
        )

        engine.updateConfiguration(updated, at: start.addingTimeInterval(60))

        XCTAssertEqual(engine.remaining(at: start.addingTimeInterval(60)), 24 * 60)
        XCTAssertTrue(engine.state.isRunning)
    }
}
