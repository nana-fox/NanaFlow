import Foundation
#if !NANAFLOW_LOCAL_CHECKS
import XCTest
@testable import NanaFlow

@MainActor
final class MenuBarAndJumpTests: XCTestCase {
    func testMenuBarAndJumpContracts() throws { try MenuBarAndJumpChecks.run() }
}
#endif

@MainActor
enum MenuBarAndJumpChecks {
    enum Failure: Error { case assertion(String) }
    static func check(_ condition: Bool, _ description: String) throws {
        if !condition { throw Failure.assertion(description) }
    }

    static func run() throws {
        var preferences = TimerPreferences.standard
        preferences.showTodayCompletedCount = true
        preferences.hideWindowWhenTimerStarts = false
        let encoded = try JSONEncoder().encode(preferences)
        try check(try JSONDecoder().decode(TimerPreferences.self, from: encoded).showTodayCompletedCount, "count setting round trip")
        var legacy = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
        legacy.removeValue(forKey: "showTodayCompletedCount")
        let decoded = try JSONDecoder().decode(TimerPreferences.self, from: JSONSerialization.data(withJSONObject: legacy))
        try check(!decoded.showTodayCompletedCount, "legacy preferences default off")
        try check(!decoded.hideWindowWhenTimerStarts, "legacy preferences retain other choices")

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = Date(timeIntervalSince1970: 1_790_035_200)
        let midnight = calendar.startOfDay(for: day)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: midnight)!
        func session(_ end: Date, completed: Bool = true, type: RecordedSessionType = .focus) -> FocusSession {
            FocusSession(id: UUID(), startedAt: end.addingTimeInterval(-1500), endedAt: end, duration: 1500, completed: completed, title: "Test", type: type)
        }
        let records = [session(midnight), session(midnight.addingTimeInterval(3600)), session(tomorrow), session(midnight.addingTimeInterval(-1)), session(day, completed: false), session(day, type: .shortBreak)]
        try check(completedFocusCount(on: day, sessions: records, calendar: calendar) == 2, "completed focus only, half-open day boundaries")
        try check(SessionStatistics(sessions: records, period: .day, anchor: day, calendar: calendar).totalCount == 2, "daily statistics matches menu count")
        try check(completedFocusCount(on: tomorrow, sessions: records, calendar: calendar) == 1, "rollover includes next midnight once")
        try check(completedFocusCount(on: day, sessions: [], calendar: calendar) == 0, "empty/deleted history")
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!
        try check(completedFocusCount(on: day, sessions: records, calendar: calendar) == 3, "local timezone change")

        for autoFocus in [false, true] {
            for autoBreak in [false, true] {
                for phaseSteps in [0, 1, 7] { // focus, short break, long break
                    for state in ["ready", "running", "paused"] {
                        let suite = "NanaFlow.Regression.\(UUID().uuidString)"
                        let defaults = UserDefaults(suiteName: suite)!
                        defer { defaults.removePersistentDomain(forName: suite) }
                        var prefs = preferences
                        prefs.autoStartFocus = autoFocus
                        prefs.autoStartBreaks = autoBreak
                        let pp = TimerPreferencesPersistence(defaults: defaults)
                        try pp.save(prefs)
                        var engine = TimerEngine(configuration: .standard)
                        for _ in 0..<phaseSteps { engine.skip(at: day) }
                        if state != "ready" { engine.start(at: day) }
                        if state == "paused" { engine.pause(at: day.addingTimeInterval(2)) }
                        let storage = TimerPersistence(defaults: defaults)
                        try storage.save(engine)
                        let notification = Notifications()
                        let controller = TimerController(persistence: storage, preferencesPersistence: pp, historyPersistence: SessionHistoryPersistence(defaults: defaults), notifications: notification, now: day)
                        controller.skipAndStart(at: day.addingTimeInterval(5))
                        let expected: SessionPhase = phaseSteps == 0 ? .shortBreak : .focus
                        try check(controller.engine.state.phase == expected && controller.engine.state.isRunning, "manual jump \(state) \(phaseSteps) \(autoFocus)/\(autoBreak)")
                        try check(controller.engine.remaining(at: day.addingTimeInterval(5)) == controller.engine.configuration.duration(for: expected), "full next duration")
                        try check(notification.scheduled == 1 && notification.cancelled == 1, "single replacement notification")
                        try check(controller.sessions.allSatisfy { !$0.completed }, "jump never counts as completed")
                        try check(storage.load()?.state.isRunning == true, "running state persists")
                    }
                }
            }
        }

        let suite = "NanaFlow.Regression.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let pp = TimerPreferencesPersistence(defaults: defaults)
        try pp.save(preferences)
        let c = TimerController(persistence: TimerPersistence(defaults: defaults), preferencesPersistence: pp, historyPersistence: SessionHistoryPersistence(defaults: defaults), notifications: Notifications(), now: day)
        c.skip(at: day)
        try check(!c.engine.state.isRunning, "automation keeps auto-start policy")
        c.skipAndStart(at: day)
        c.tick(at: day.addingTimeInterval(1500))
        try check(!c.engine.state.isRunning && c.engine.state.phase == .shortBreak, "natural completion keeps auto-start policy")
        try check(completedFocusCount(on: day, sessions: c.sessions) == 1, "natural focus completion counts")
        c.skipAndStart(at: day.addingTimeInterval(1501))
        var locked = c.preferences
        locked.commitmentModeEnabled = true
        c.updatePreferences(locked)
        let before = c.engine
        c.skipAndStart(at: day.addingTimeInterval(1502))
        try check(c.engine == before, "commitment mode prevents jump")
    }

    private final class Notifications: SessionNotificationScheduling {
        var scheduled = 0
        var cancelled = 0
        func scheduleCompletion(at date: Date, nextPhase: SessionPhase, sound: CompletionSound, volume: Double, quote: String?) { scheduled += 1 }
        func cancelCompletion() { cancelled += 1 }
    }
}
