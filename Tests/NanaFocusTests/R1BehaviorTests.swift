import Foundation
import AppKit
import UserNotifications
#if !NANAFLOW_LOCAL_CHECKS
import XCTest
@testable import NanaFlow

@MainActor
final class R1BehaviorTests: XCTestCase {
    func testR1BehaviorContracts() async throws { try await R1BehaviorChecks.run() }
}
#endif

/// This exact body runs under XCTest and the CLT runner; no duplicate test truth.
@MainActor
enum R1BehaviorChecks {
    enum Failure: Error { case assertion(String) }
    static func check(_ condition: Bool, _ label: String) throws {
        if !condition { throw Failure.assertion(label) }
    }
    static func run() async throws {
        try preferencesAndAudio()
        try controllerRefresh()
        try statistics()
        try statisticsExtremes()
        try windowDraggingMath()
        try await orderedSubmission()
        try await naturalCompletionHandoff()
        try await restoredCompletionHandoff()
        try await triggerBeforeLateCallback()
        try notificationDefaultActions()
        try sharedHistoryBootstrap()
        try syncDiagnostics()
        try syncDiagnosticsLocalizations()
    }
    static func preferencesAndAudio() throws {
        try check(CompletionSound.menuOrder.first == CompletionSound.none, "both public menus include None")
        var p = TimerPreferences.standard
        p.setCompletionSound(.harp, for: .focus)
        p.setCompletionSound(.none, for: .longBreak)
        try check(p.focusCompletionSound == .harp && p.breakCompletionSound == .none && p.notificationSoundEnabled, "independent focus/break fields and legacy OR")
        p.setCompletionSound(.none, for: .focus)
        try check(!p.notificationSoundEnabled && p.breakCompletionSound == .none, "both None updates legacy OR")
        p.notificationVolume = 0.2
        let decoded = try JSONDecoder().decode(TimerPreferences.self, from: JSONEncoder().encode(p))
        try check(decoded.notificationVolume == 0.2 && SettingsVolumeContract.percentage(for: decoded.notificationVolume) == 0, "legacy fractional volume retained while showing effective step")
        for enabled in [false, true] {
            let data = Data("{\"autoStartFocus\":false,\"autoStartBreaks\":true,\"notificationSoundEnabled\":\(enabled)}".utf8)
            let legacy = try JSONDecoder().decode(TimerPreferences.self, from: data)
            try check(legacy.focusCompletionSound == (enabled ? .bell : .none) && legacy.breakCompletionSound == (enabled ? .bell : .none), "legacy bool fallback")
        }
        let explicit = try JSONDecoder().decode(TimerPreferences.self, from: Data("{\"autoStartFocus\":false,\"autoStartBreaks\":false,\"notificationSoundEnabled\":false,\"focusCompletionSound\":\"bell\",\"breakCompletionSound\":\"none\"}".utf8))
        try check(explicit.focusCompletionSound == .bell && explicit.breakCompletionSound == .none, "explicit phase field wins legacy false")
        for (value, level) in [(-1.0,0),(0,0),(0.2,0),(0.2499,0),(0.25,1),(0.5,1),(0.7499,1),(0.75,2),(1,2),(1.2499,2),(1.25,3),(1.5,3),(1.7499,3),(1.75,4),(2,4),(3,4)] {
            try check(CompletionSound.volumeLevel(value) == level, "volume boundary \(value)")
            try check(SettingsVolumeContract.percentage(for:value) == level*25, "effective percent \(value)")
            for sound in CompletionSound.menuOrder {
                let expected = sound == .none || level == 0 ? nil : (level == 4 ? sound.fileName : "NanaFlow-\(sound.rawValue)-v\(level).aiff")
                try check(sound.fileName(volume:value) == expected, "same variant for preview and request \(sound) \(value)")
            }
        }
        let suite = "NanaFlow.R1Check.\(UUID().uuidString)"; let defaults = UserDefaults(suiteName:suite)!
        defer { defaults.removePersistentDomain(forName:suite) }
        let store = TimerPreferencesPersistence(defaults:defaults)
        defaults.set(Data("damaged".utf8),forKey:TimerPreferencesPersistence.storageKey)
        try check(store.load() == nil, "damaged preferences keep fallback")
        defaults.set(Data("{\"autoStartFocus\":false,\"autoStartBreaks\":false,\"notificationSoundEnabled\":true,\"focusCompletionSound\":\"unknown\"}".utf8),forKey:TimerPreferencesPersistence.storageKey)
        try check(store.load() == nil, "unknown enum keeps original fallback")
        try store.save(decoded)
        try check(store.load() == decoded, "independent settings restart round trip")
    }
    static func controllerRefresh() throws {
        for phaseSteps in [0,1,7] {
            let suite="NanaFlow.R1Check.\(UUID().uuidString)";let d=UserDefaults(suiteName:suite)!
            defer { d.removePersistentDomain(forName:suite) }
            var p=TimerPreferences.standard;p.hideWindowWhenTimerStarts=false;p.motivationalQuotesEnabled=false
            let pp=TimerPreferencesPersistence(defaults:d);try pp.save(p)
            let ep=TimerPersistence(defaults:d);var e=TimerEngine(configuration:.standard);let start=Date().addingTimeInterval(3600)
            for _ in 0..<phaseSteps { e.skip(at:start) };try ep.save(e)
            let n=Notifications()
            let c=TimerController(persistence:ep,preferencesPersistence:pp,historyPersistence:SessionHistoryPersistence(defaults:d),tagPersistence:SessionTagPersistence(defaults:d),notifications:n,now:start)
            c.start(at:start);let before=c.engine;let history=c.sessions
            var prefs=c.preferences
            prefs.setCompletionSound(.harp,for:c.engine.state.phase);c.updatePreferences(prefs)
            try check(n.pending?.sound == .harp && n.pending?.date == before.state.endDate, "running phase sound/deadline \(phaseSteps)")
            let count=n.scheduled;prefs.showTodayCompletedCount.toggle();c.updatePreferences(prefs);c.updatePreferences(prefs)
            try check(n.scheduled == count, "unrelated and equal preferences do not reschedule")
            prefs.setCompletionSound(.none,for:phaseSteps == 0 ? .shortBreak : .focus);c.updatePreferences(prefs)
            try check(n.scheduled == count, "other phase sound does not reschedule")
            prefs.notificationVolume=0;c.updatePreferences(prefs)
            try check(n.pending?.volume == 0, "running mute updates notification")
            prefs.notificationsEnabled=false;c.updatePreferences(prefs);try check(n.pending == nil, "notification disable cancels")
            prefs.notificationsEnabled=true;c.updatePreferences(prefs);try check(n.pending?.date == before.state.endDate, "reenable restores current deadline")
            try check(c.engine == before && c.sessions == history, "settings preserve engine and history")
            c.pause(at:start.addingTimeInterval(3));let pausedCount=n.scheduled
            prefs.notificationVolume=2;c.updatePreferences(prefs)
            try check(n.scheduled == pausedCount && n.pending == nil, "paused settings schedule nothing")
        }
    }
    static func statistics() throws {
        var cal=Calendar(identifier:.gregorian);cal.timeZone=TimeZone(identifier:"Asia/Singapore")!;cal.firstWeekday=2;cal.minimumDaysInFirstWeek=4
        let anchor=cal.date(from:DateComponents(year:2026,month:10,day:26,hour:14))!
        let root=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let fixture=root.appendingPathComponent("References/acceptance-2026-10-26-r1/sessions-fixture.json")
        let sessions=try JSONDecoder().decode([FocusSession].self,from:Data(contentsOf:fixture))
        for period in StatisticsPeriod.allCases {
            let s=SessionStatistics(sessions:sessions,period:period,anchor:anchor,calendar:cal)
            let expectedCount=period == .day || period == .week ? 5:6
            let expectedDuration:Double=period == .day || period == .week ? 14430:15930
            try check(s.totalCount == expectedCount && s.totalDuration == expectedDuration, "fixed fixture \(period)")
            try check(s.buckets.reduce(0){$0+$1.duration} == s.totalDuration, "bucket sum equals net total")
            for bucket in s.buckets {
                try check(StatisticsMetric.count.value(for:bucket) == Double(bucket.sessionCount), "count column source")
                try check(StatisticsMetric.duration.value(for:bucket) == bucket.duration, "duration column source")
            }
            try check(!statisticsCanMoveForward(period:period,anchor:anchor,now:anchor,calendar:cal), "no future navigation")
        }
        for lang in ["en","zh-Hans","zh-Hant"] {
            let bundle=Bundle(path:root.appendingPathComponent("Sources/NanaFocus/\(lang).lproj").path)!
            let locale=Locale(identifier:lang)
            let expected=lang == "en" ? ["0 min","<1 min","1 min","59 min","1 hr","1 hr 1 min","25 hr 1 min"] : (lang == "zh-Hant" ? ["0 分鐘","<1 分鐘","1 分鐘","59 分鐘","1 小時","1 小時 1 分鐘","25 小時 1 分鐘"] : ["0 分钟","<1 分钟","1 分钟","59 分钟","1 小时","1 小时 1 分钟","25 小时 1 分钟"])
            for (seconds,text) in zip([0.0,30,60,3599,3600,3660,90060],expected) {
                try check(statisticsDurationText(seconds,locale:locale,bundle:bundle) == text, "duration \(lang) \(seconds)")
            }
            try check(statisticsDurationText(Double.greatestFiniteMagnitude,locale:locale,bundle:bundle).count < 80, "huge duration avoids integer overflow and unreadable digits")
        }
        func record(_ duration:Double)->FocusSession { FocusSession(id:UUID(),startedAt:anchor.addingTimeInterval(-1000),endedAt:anchor,duration:duration,completed:true,title:"fixture") }
        let seconds=SessionStatistics(sessions:[record(30),record(30),record(0)],period:.day,anchor:anchor,calendar:cal)
        try check(seconds.totalCount == 3 && seconds.totalDuration == 60, "sum seconds before format; zero duration still counts")
        for (month,day,count) in [(3,8,23),(11,1,25)] {
            cal.timeZone=TimeZone(identifier:"America/New_York")!
            let dst=cal.date(from:DateComponents(year:2026,month:month,day:day,hour:12))!
            let s=SessionStatistics(sessions:[],period:.day,anchor:dst,calendar:cal)
            try check(s.buckets.count == count && s.totalCount == 0 && s.totalDuration == 0, "DST \(count) real hours with no fake data")
        }
        cal.timeZone=TimeZone(secondsFromGMT:0)!
        let leap=cal.date(from:DateComponents(year:2028,month:2,day:10))!
        try check(SessionStatistics(sessions:[],period:.month,anchor:leap,calendar:cal).buckets.count == 29, "leap month")
    }
    static func statisticsExtremes() throws {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let anchor = cal.date(from: DateComponents(year: 2026, month: 10, day: 26, hour: 14))!
        let huge = Double.greatestFiniteMagnitude
        let track = StatisticsVisualMetrics.chartTrackHeight
        func record(_ duration: Double, hoursAgo: Int = 0) -> FocusSession {
            FocusSession(id: UUID(), startedAt: anchor.addingTimeInterval(-1000),
                         endedAt: anchor.addingTimeInterval(-Double(hoursAgo) * 3600),
                         duration: duration, completed: true, title: "extreme fixture", tag: "extreme")
        }
        // Exercise real model decoding too; do not change the persistence format.
        let single = try JSONDecoder().decode([FocusSession].self, from: JSONEncoder().encode([record(huge)]))
        let cases = [single, [record(huge), record(huge)],
                     [record(huge), record(huge, hoursAgo: 1)],
                     [record(huge / 2), record(huge / 2), record(huge / 2)]]
        for (index, sessions) in cases.enumerated() {
            let statistics = SessionStatistics(sessions: sessions, period: .day, anchor: anchor, calendar: cal)
            try check(statistics.totalCount == sessions.count && statistics.totalDuration == huge,
                      "extreme case \(index) has finite saturated total, never false zero")
            try check(statistics.buckets.reduce(0) { statisticsAddingDuration($0, $1.duration) } == statistics.totalDuration,
                      "same saturation policy for total and bucket sum")
            try check(statistics.tagSummaries.first?.duration == huge, "tag summary saturates consistently")
            let positive = statistics.buckets.filter { $0.sessionCount > 0 }
            try check(positive.count == (index == 2 ? 2 : 1), "same/cross bucket extreme placement")
            let maximum = statistics.buckets.map { StatisticsMetric.duration.value(for: $0) }.max()!
            for bucket in statistics.buckets {
                let height = statisticsBarHeight(value: bucket.duration, maximum: maximum, trackHeight: track)
                try check(height.isFinite && height >= 0 && height <= track, "extreme bar has legal finite height")
                if bucket.sessionCount > 0 {
                    try check(height > 0 && bucket.duration.isFinite && bucket.duration > 0,
                              "positive extreme bucket remains visible and nonzero")
                    try check(bucket.tagSegments.first?.duration == bucket.duration, "tag segment agrees with bucket")
                    let text = statisticsDurationText(bucket.duration)
                    try check(text != statisticsDurationText(0) && !text.isEmpty, "extreme duration never formats as zero")
                    try check(statisticsBucketTooltipText(bucket, metric: .duration) == text &&
                              StatisticsMetric.duration.accessibilityValue(bucket) == text,
                              "tooltip and AX use identical finite duration policy")
                }
            }
            try check(StatisticsMetric.duration.totalText(statistics) == statisticsDurationText(huge),
                      "total uses same formatter as bucket/tooltip/AX")
        }
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        for language in ["en", "zh-Hans", "zh-Hant"] {
            let bundle = Bundle(path: root.appendingPathComponent("Sources/NanaFocus/\(language).lproj").path)!
            let locale = Locale(identifier: language)
            let text = statisticsDurationText(huge, locale: locale, bundle: bundle)
            try check(text != statisticsDurationText(0, locale: locale, bundle: bundle) && text.count < 80,
                      "localized extreme is readable and nonzero \(language)")
            try check(statisticsDurationText(.infinity, locale: locale, bundle: bundle) == text,
                      "positive overflow uses same finite display limit \(language)")
        }
        for (value, maximum, expected) in [(0.0, 100.0, 0.0), (25, 100, 0.25), (50, 100, 0.5),
                                            (100, 100, 1), (huge / 2, huge, 0.5), (huge, huge, 1)] {
            try check(abs(statisticsBarHeight(value: value, maximum: maximum, trackHeight: track) - track * expected) < 0.0001,
                      "normal and extreme height ratio \(value)/\(maximum)")
        }
        try check(statisticsBarHeight(value: 1, maximum: huge, trackHeight: track) == min(8, track),
                  "tiny positive value retains minimum visible bar")
        for value in [0.0, -1, .nan, .infinity, huge] {
            for maximum in [0.0, -1, .nan, .infinity, huge] {
                for height in [CGFloat(0), 4, track, .infinity, .nan, -1] {
                    let result = statisticsBarHeight(value: value, maximum: maximum, trackHeight: height)
                    try check(result.isFinite && result >= 0 && (!height.isFinite || result <= max(0, height)),
                              "layout rejects invalid numeric boundaries")
                }
            }
        }
        print("PASS R1 statistics extremes: single/same-bucket/cross-bucket saturation, finite heights, nonzero total/tooltip/AX")
    }
    static func windowDraggingMath() throws {
        let bounds = CGRect(x: 0, y: 0, width: 380, height: 272)
        let button = CGRect(x: 8, y: 8, width: 32, height: 32)
        let slider = CGRect(x: 60, y: 120, width: 240, height: 24)
        let regions = WindowDragSurface.regions(in: bounds, excluding: [button, slider])
        for region in regions {
            try check(bounds.contains(region) && !region.isEmpty, "drag regions stay in content bounds")
            try check(region.intersection(button).isEmpty && region.intersection(slider).isEmpty,
                      "button and slider receive their own input")
        }
        for point in [CGPoint(x: 1, y: 100), CGPoint(x: 370, y: 260), CGPoint(x: 190, y: 60)] {
            try check(regions.contains { $0.contains(point) }, "background remains draggable")
        }
        for point in [CGPoint(x: 24, y: 24), CGPoint(x: 180, y: 132)] {
            try check(!regions.contains { $0.contains(point) }, "interactive center excluded from drag")
        }
        let start = NSPoint(x: 500, y: 300), anchor = NSPoint(x: 600, y: 400)
        for (point, expected) in [(NSPoint(x: 650, y: 430), NSPoint(x: 550, y: 330)),
                                  (NSPoint(x: 550, y: 370), NSPoint(x: 450, y: 270)),
                                  (anchor, start)] {
            try check(WindowDragSurface.DragView.origin(start: start, anchor: anchor, point: point) == expected,
                      "native drag origin positive/negative/zero displacement")
        }
        let quartz = CGPoint(x: 120, y: 340)
        let pointer = NSPoint(x: 120, y: 740)
        try check(WindowDragSurface.DragView.screenPoint(quartz: quartz, pointer: pointer, source: .event) == NSPoint(x: 120, y: -340), "event coordinates keep a fixed screen basis")
        try check(WindowDragSurface.DragView.screenPoint(quartz: nil, pointer: pointer, source: .event) == nil, "missing queued CGEvent never switches to a different y origin")
        try check(WindowDragSurface.DragView.screenPoint(quartz: quartz, pointer: pointer, source: .pointer) == pointer, "pointer fallback stays locked even if later CGEvent exists")
        print("PASS R1 window drag math: controls excluded; signed/zero displacement; gesture coordinate source locked across nil CGEvents")
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
                    let suite = "NanaFlow.R1Completion.\(UUID().uuidString)"
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
                    let suite = "NanaFlow.R1CompletionRestore.\(UUID().uuidString)"
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
        TimerController(persistence: TimerPersistence(defaults: defaults), preferencesPersistence: TimerPreferencesPersistence(defaults: defaults), historyPersistence: SessionHistoryPersistence(defaults: defaults), tagPersistence: SessionTagPersistence(defaults: defaults), notifications: scheduler, now: now)
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
    static func notificationDefaultActions() throws {
        try check(SessionNotificationContract.command(for: UNNotificationDefaultActionIdentifier) == .show,
                  "notification body only shows the timer; never starts it")
        try check(SessionNotificationContract.command(for: UNNotificationDismissActionIdentifier) == nil,
                  "notification dismiss leaves timer unchanged")
        try check(SessionNotificationContract.command(for: "unknown") == nil, "unknown action is ignored")
        for (identifier, expected) in [("start", TimerAutomationCommand.start), ("skip", .skip), ("open", .show)] {
            try check(SessionNotificationContract.command(for: identifier) == expected, "existing notification action preserved")
        }
        print("PASS system notification actions: body shows; dismiss/unknown do nothing; custom actions preserved")
    }

    static func sharedHistoryBootstrap() throws {
        let localName = "NanaFlow.SystemChecks.Local.\(UUID().uuidString)"
        let sharedName = "NanaFlow.SystemChecks.Shared.\(UUID().uuidString)"
        let local = UserDefaults(suiteName: localName)!, shared = UserDefaults(suiteName: sharedName)!
        defer {
            local.removePersistentDomain(forName: localName)
            shared.removePersistentDomain(forName: sharedName)
        }
        let key = SessionHistoryPersistence.storageKey
        let anchor = Date(timeIntervalSince1970: 1_700_000_000)
        let session = FocusSession(id: UUID(), startedAt: anchor, endedAt: anchor.addingTimeInterval(60),
                                   duration: 60, completed: true, title: "Synthetic system check")
        var legacy = try JSONSerialization.jsonObject(with: JSONEncoder().encode([session])) as! [[String: Any]]
        legacy[0]["futureField"] = "preserve raw bytes"
        let original = try JSONSerialization.data(withJSONObject: legacy, options: [.prettyPrinted, .sortedKeys])
        var reloads = 0
        let store = SessionHistoryPersistence(defaults: local, sharedDefaults: shared, reloadWidgetTimelines: { reloads += 1 })
        local.set(original, forKey: key)
        let before = local.persistentDomain(forName: localName)!
        store.prepareSharedSnapshot()
        try check(shared.data(forKey: key) == original && reloads == 1, "first snapshot copies exact raw data and reloads once")
        try check(NSDictionary(dictionary: before).isEqual(to: local.persistentDomain(forName: localName)!), "bootstrap never rewrites local domain")
        store.prepareSharedSnapshot()
        try check(reloads == 1, "second preparation preserves existing snapshot")

        for existing: Any in [Data("[]".utf8), Data("damaged".utf8), "wrong type", 42, false] {
            shared.set(existing, forKey: key)
            let beforeShared = shared.persistentDomain(forName: sharedName)!
            store.prepareSharedSnapshot()
            try check(NSDictionary(dictionary: beforeShared).isEqual(to: shared.persistentDomain(forName: sharedName)!), "existing shared value of any type is preserved")
            try check(reloads == 1 && local.data(forKey: key) == original, "existing shared value causes no reload or local write")
        }
        for invalid: Any? in [nil, "wrong type", Data("damaged".utf8), Data("{}".utf8)] {
            shared.removeObject(forKey: key)
            if let invalid { local.set(invalid, forKey: key) } else { local.removeObject(forKey: key) }
            let beforeLocal = local.persistentDomain(forName: localName) ?? [:]
            store.prepareSharedSnapshot()
            try check(shared.object(forKey: key) == nil && reloads == 1, "missing/invalid local data never publishes an empty replacement")
            try check(NSDictionary(dictionary: beforeLocal).isEqual(to: local.persistentDomain(forName: localName) ?? [:]), "invalid local value is preserved")
        }
        local.set(Data("[]".utf8), forKey: key)
        store.prepareSharedSnapshot()
        try check(shared.data(forKey: key) == Data("[]".utf8) && reloads == 2, "valid empty array is a publishable snapshot")

        shared.removeObject(forKey: key)
        local.set(original, forKey: key)
        var preferences = TimerPreferences.standard
        preferences.hideWindowWhenTimerStarts = false
        try TimerPreferencesPersistence(defaults: local).save(preferences)
        var savedEngine = TimerEngine(configuration: .standard)
        savedEngine.start(at: anchor)
        try TimerPersistence(defaults: local).save(savedEngine)
        let localBeforeController = local.persistentDomain(forName: localName)!
        func controller(history: any SessionHistoryPersisting) -> TimerController {
            TimerController(persistence: TimerPersistence(defaults: local), preferencesPersistence: TimerPreferencesPersistence(defaults: local),
                            historyPersistence: history, tagPersistence: SessionTagPersistence(defaults: local), notifications: Notifications(), now: anchor)
        }
        let first = controller(history: store)
        try check(first.sessions == [session] && shared.data(forKey: key) == original && reloads == 3, "controller launch explicitly prepares shared history after loading")
        let second = controller(history: store)
        try check(second.sessions == first.sessions && reloads == 3, "restart does not republish or drop history")
        try check(first.engine == savedEngine && second.engine == savedEngine, "bootstrap and restart preserve running timer and original deadline")
        try check(NSDictionary(dictionary: localBeforeController).isEqual(to: local.persistentDomain(forName: localName)!), "two launches do not rewrite local timer/history/preferences")
        let fake = HistoryDefaultPreparation()
        _ = controller(history: fake)
        try check(fake.loads == 1 && fake.saves == 0, "protocol default preparation keeps existing fakes side effect free")
        print("PASS system shared snapshot: raw bootstrap; existing/bad/missing values preserved; controller/restart; fake no-op")
    }

    static func syncDiagnostics() throws {
        let anchor = Date(timeIntervalSince1970: 1_700_000_000)
        var diagnostics = TimerSyncDiagnostics.unavailable
        diagnostics.recordLocalProcessing(succeeded: false, at: anchor)
        try check(diagnostics.status == .unavailable && diagnostics.lastSyncDate == nil, "failed first local processing never invents a delivery time")
        diagnostics.recordLocalProcessing(succeeded: true, at: anchor)
        for reason in [NSUbiquitousKeyValueStoreAccountChange, NSUbiquitousKeyValueStoreQuotaViolationChange] {
            try check(!diagnostics.shouldProcessExternalChange(reason: reason), "account/quota event forbids a success pull")
            try check(diagnostics.status == .unavailable && diagnostics.lastSyncDate == anchor, "failure event preserves previous local time")
        }
        diagnostics.recordLocalProcessing(succeeded: false, at: anchor.addingTimeInterval(1))
        try check(diagnostics.lastSyncDate == anchor, "synchronize false never advances local success time")
        try check(!diagnostics.shouldProcessExternalChange(reason: nil) && !diagnostics.shouldProcessExternalChange(reason: -99), "missing/unknown reason ignored")

        let suite = "NanaFlow.SystemChecks.Cloud.\(UUID().uuidString)", defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var preferences = TimerPreferences.standard
        preferences.timerSyncEnabled = true
        preferences.hideWindowWhenTimerStarts = false
        let persistence = TimerPreferencesPersistence(defaults: defaults)
        try persistence.save(preferences)
        let controller = TimerController(persistence: TimerPersistence(defaults: defaults), preferencesPersistence: persistence,
                                         historyPersistence: SessionHistoryPersistence(defaults: defaults), tagPersistence: SessionTagPersistence(defaults: defaults),
                                         notifications: Notifications(), now: anchor)
        let store = CloudMemoryStore()
        store.synchronizeResult = false
        controller.configureCloudSync(store: store, syncKey: "synthetic", deviceKey: "synthetic")
        try check(controller.timerSyncDiagnostics.status == .unavailable && controller.timerSyncDiagnostics.lastSyncDate == nil,
                  "controller initial synchronize false is unavailable without success time")
        try check(store.reads == 0 && store.writes == 0, "initial failure never reads or publishes cached cloud state")
        store.synchronizeResult = true
        store.values["NanaFlow.focusSessions.v1"] = try JSONEncoder().encode([FocusSession]())
        store.values["NanaFlow.timerEngine.v1"] = try JSONEncoder().encode(controller.engine)
        controller.handleCloudChange(reason: NSUbiquitousKeyValueStoreInitialSyncChange)
        try check(controller.timerSyncDiagnostics.status == .available && controller.timerSyncDiagnostics.lastSyncDate != nil,
                  "normal external processing recovers configured locally")
        let savedEngine = controller.engine, savedSessions = controller.sessions
        let lastLocalDate = controller.timerSyncDiagnostics.lastSyncDate
        let remote = FocusSession(id: UUID(), startedAt: anchor, endedAt: anchor.addingTimeInterval(60), duration: 60,
                                  completed: true, title: "Synthetic remote session")
        let remoteEngine = TimerEngine(configuration: TimerConfiguration(focusDuration: 3000, shortBreakDuration: 600, longBreakDuration: 1200, sessionsPerCycle: 8))
        store.values["NanaFlow.focusSessions.v1"] = try JSONEncoder().encode([remote])
        store.values["NanaFlow.timerEngine.v1"] = try JSONEncoder().encode(remoteEngine)
        let accesses = (store.reads, store.writes, store.synchronizations)
        for reason: Int? in [NSUbiquitousKeyValueStoreAccountChange, NSUbiquitousKeyValueStoreQuotaViolationChange, nil, -99] {
            controller.handleCloudChange(reason: reason)
            try check(controller.engine == savedEngine && controller.sessions == savedSessions, "error/unknown event never applies cached records or timer")
            try check(controller.timerSyncDiagnostics.status == .unavailable && controller.timerSyncDiagnostics.lastSyncDate == lastLocalDate,
                      "error event cannot become configured or advance time")
            try check(store.reads == accesses.0 && store.writes == accesses.1 && store.synchronizations == accesses.2, "error event never touches cloud store or retries quota writes")
        }
        controller.handleCloudChange(reason: NSUbiquitousKeyValueStoreServerChange)
        try check(controller.sessions == [remote] && controller.engine == remoteEngine && controller.timerSyncDiagnostics.status == .available,
                  "normal server event applies incoming state and recovers configured")
        let beforeFailedWrite = controller.timerSyncDiagnostics.lastSyncDate
        store.synchronizeResult = false
        controller.updatePreferences(controller.preferences)
        try check(controller.timerSyncDiagnostics.status == .unavailable && controller.timerSyncDiagnostics.lastSyncDate == beforeFailedWrite,
                  "controller write synchronize false cannot advance success time")
        store.synchronizeResult = true
        controller.updatePreferences(controller.preferences)
        try check(controller.timerSyncDiagnostics.status == .available, "successful local processing recovers configured without remote receipt")
        let beforeFailedMerge = controller.timerSyncDiagnostics.lastSyncDate
        let additional = FocusSession(id: UUID(), startedAt: anchor, endedAt: anchor.addingTimeInterval(120), duration: 120,
                                      completed: true, title: "Synthetic second remote session")
        store.values["NanaFlow.focusSessions.v1"] = try JSONEncoder().encode([remote, additional])
        store.values["NanaFlow.timerEngine.v1"] = try JSONEncoder().encode(savedEngine)
        store.synchronizeResult = false
        controller.handleCloudChange(reason: NSUbiquitousKeyValueStoreServerChange)
        try check(controller.timerSyncDiagnostics.status == .unavailable && controller.timerSyncDiagnostics.lastSyncDate == beforeFailedMerge,
                  "failed history writeback cannot be masked by a subsequent successful timer read")
        try check(controller.engine == remoteEngine && controller.sessions.count == 2, "failed batch retains local merge but does not apply the next timer")
        print("PASS system cloud diagnostics: failed synchronize; account/quota no read/write; server/initial/local recovery; no remote receipt")
    }

    static func syncDiagnosticsLocalizations() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let expected = [
            ("en", "Configured", "Last Local Processing", "Configured status and local processing time do not confirm delivery to iCloud or other devices."),
            ("zh-Hans", "已配置", "上次本地处理", "已配置和本地处理时间不代表数据已送达 iCloud 或其他设备。"),
            ("zh-Hant", "已設定", "上次本機處理", "已設定和本機處理時間不代表資料已送達 iCloud 或其他裝置。")
        ]
        for (language, status, label, explanation) in expected {
            let url = root.appendingPathComponent("Sources/NanaFocus/\(language).lproj/Localizable.strings")
            let strings = try PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as! [String: String]
            try check(strings["已配置"] == status && strings["上次本地处理"] == label && strings["已配置和本地处理时间不代表数据已送达 iCloud 或其他设备。"] == explanation,
                      "diagnostic labels explain local-only evidence in \(language)")
        }
        print("PASS system diagnostic strings: English, Simplified Chinese, Traditional Chinese")
    }

    final class HistoryDefaultPreparation: SessionHistoryPersisting {
        var loads = 0, saves = 0
        func load() -> [FocusSession] { loads += 1; return [] }
        func save(_: [FocusSession]) throws { saves += 1 }
    }
    final class CloudMemoryStore: TimerCloudStoring {
        var values: [String: Any] = [:]
        var synchronizeResult = true
        var reads = 0, writes = 0, synchronizations = 0
        func string(forKey key: String) -> String? { reads += 1; return values[key] as? String }
        func data(forKey key: String) -> Data? { reads += 1; return values[key] as? Data }
        func set(_ value: Any?, forKey key: String) { writes += 1; values[key] = value }
        func synchronize() -> Bool { synchronizations += 1; return synchronizeResult }
    }
    final class Notifications: SessionNotificationScheduling {
        struct Pending { let date:Date;let sound:CompletionSound;let volume:Double }
        var pending:Pending?;var scheduled=0
        func scheduleCompletion(at date:Date,nextPhase:SessionPhase,sound:CompletionSound,volume:Double,quote:String?) { scheduled+=1;pending=Pending(date:date,sound:sound,volume:volume) }
        func cancelCompletion() { pending=nil }
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
