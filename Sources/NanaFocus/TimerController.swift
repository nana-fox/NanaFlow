import AppKit
import Foundation
import Observation

enum TimerAutomationCommand: String, Equatable, Sendable {
    case start
    case pause
    case toggle
    case skip
    case previous
    case reset
    case resetCycle = "reset-cycle"
    case show
    case hide

    init?(url: URL) {
        guard url.scheme?.lowercased() == "nanaflow" else { return nil }
        let command = url.host?.isEmpty == false
            ? url.host!
            : url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.init(rawValue: command.lowercased())
    }
}

@MainActor
@Observable
final class TimerController {
    static let shared = TimerController()

    private(set) var engine: TimerEngine
    private(set) var preferences: TimerPreferences
    private(set) var sessions: [FocusSession]
    private(set) var now: Date
    private(set) var errorMessage: String?
    private(set) var didStartTimerAtLaunch = false
    private(set) var celebrationSequence = 0

    @ObservationIgnored private let persistence: any TimerPersisting
    @ObservationIgnored private let preferencesPersistence: any TimerPreferencesPersisting
    @ObservationIgnored private let historyPersistence: any SessionHistoryPersisting
    @ObservationIgnored private let notifications: any SessionNotificationScheduling
    @ObservationIgnored private let tickSound: any TimerTickSoundPlaying
    @ObservationIgnored private var lastTickSecond: Int?

    init(
        configuration: TimerConfiguration = .standard,
        persistence: any TimerPersisting = TimerPersistence(),
        preferencesPersistence: any TimerPreferencesPersisting = TimerPreferencesPersistence(),
        historyPersistence: any SessionHistoryPersisting = SessionHistoryPersistence(sharedDefaults: NanaFlowShared.defaults),
        notifications: any SessionNotificationScheduling = SessionNotificationScheduler(),
        tickSound: any TimerTickSoundPlaying = TimerTickSoundPlayer(),
        now: Date = Date()
    ) {
        self.persistence = persistence
        self.preferencesPersistence = preferencesPersistence
        self.historyPersistence = historyPersistence
        self.notifications = notifications
        self.tickSound = tickSound
        self.now = now
        self.engine = persistence.load() ?? TimerEngine(configuration: configuration)
        self.preferences = preferencesPersistence.load() ?? .standard
        self.sessions = historyPersistence.load().sorted { $0.endedAt > $1.endedAt }

        let expiredEngine = engine
        if engine.reconcile(at: now) {
            notifications.cancelCompletion()
            autoStartIfEnabled(at: now)
            persist()
            recordSession(from: expiredEngine, endedAt: expiredEngine.state.endDate ?? now, completed: true)
        }

        let shouldPersistLaunchState = preferences.resetCycleOnLaunch || preferences.startTimerOnLaunch
        if preferences.resetCycleOnLaunch {
            engine.resetCycle(at: now)
        }
        if preferences.startTimerOnLaunch, !engine.state.isRunning {
            engine.start(at: now)
            didStartTimerAtLaunch = true
            scheduleCompletionIfNeeded()
        }
        if shouldPersistLaunchState {
            persist()
        }
    }

    var remainingSeconds: Int {
        Int(ceil(engine.remaining(at: now)))
    }

    var formattedTime: String {
        let seconds = max(0, remainingSeconds)
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    var phaseTitle: String {
        switch engine.state.phase {
        case .focus: preferences.sessionTitle
        case .shortBreak: String(localized: "休息")
        case .longBreak: String(localized: "长时间停顿")
        }
    }

    var cycleAccessibilityLabel: String {
        String(
            format: String(localized: "第 %1$lld 轮，共 %2$lld 轮"),
            engine.state.cycleIndex + 1,
            engine.configuration.sessionsPerCycle
        )
    }

    var progress: Double {
        let duration = engine.configuration.duration(for: engine.state.phase)
        return min(1, max(0, 1 - Double(remainingSeconds) / duration))
    }

    func toggle(at date: Date = Date()) {
        now = date
        if engine.state.isRunning {
            guard !isCommittedFocus else { return }
            engine.pause(at: date)
            notifications.cancelCompletion()
        } else {
            startEngine(at: date)
        }
        persist()
    }

    func start(at date: Date = Date()) {
        guard !engine.state.isRunning else { return }
        toggle(at: date)
    }

    func pause(at date: Date = Date()) {
        guard engine.state.isRunning else { return }
        toggle(at: date)
    }

    func resetCycle(at date: Date = Date()) {
        now = date
        guard !isCommittedFocus else { return }
        engine.resetCycle(at: date)
        notifications.cancelCompletion()
        persist()
    }

    func updateSessionTitle(_ title: String) {
        var updated = preferences
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.sessionTitle = trimmed.isEmpty ? "NanaFlow" : trimmed
        updatePreferences(updated)
    }

    func perform(_ command: TimerAutomationCommand, at date: Date = Date()) {
        switch command {
        case .start: start(at: date)
        case .pause: pause(at: date)
        case .toggle: toggle(at: date)
        case .skip: skip(at: date)
        case .previous: previous(at: date)
        case .reset: reset(at: date)
        case .resetCycle: resetCycle(at: date)
        case .show:
            NSApplication.shared.activate()
            AppWindowActivation.bringToFront(title: "NanaFlow")
        case .hide:
            AppWindowActivation.hideTimerWindow()
        }
    }

    /// A deliberate user jump starts immediately; automation retains its existing policy.
    func skipAndStart(at date: Date = Date()) {
        skip(at: date, startsImmediately: true)
    }

    func skip(at date: Date = Date()) {
        skip(at: date, startsImmediately: false)
    }

    private func skip(at date: Date, startsImmediately: Bool) {
        now = date
        guard !isCommittedFocus else { return }
        let interruptedEngine = engine
        engine.skip(at: date)
        notifications.cancelCompletion()
        if startsImmediately {
            startEngine(at: date)
        } else {
            autoStartIfEnabled(at: date)
        }
        persist()
        recordSession(from: interruptedEngine, endedAt: date, completed: false)
    }

    func reset(at date: Date = Date()) {
        now = date
        guard !isCommittedFocus else { return }
        let interruptedEngine = engine
        engine.reset(at: date)
        notifications.cancelCompletion()
        persist()
        recordSession(from: interruptedEngine, endedAt: date, completed: false)
    }

    func previous(at date: Date = Date()) {
        now = date
        guard !isCommittedFocus else { return }
        let interruptedEngine = engine
        engine.previous(at: date)
        notifications.cancelCompletion()
        persist()
        recordSession(from: interruptedEngine, endedAt: date, completed: false)
    }

    func tick(at date: Date = Date()) {
        now = date
        playTickIfNeeded()
        let completedEngine = engine
        let completesCycle = completedEngine.state.phase == .focus
            && completedEngine.state.cycleIndex == completedEngine.configuration.sessionsPerCycle - 1
        guard engine.reconcile(at: date) else { return }
        if completesCycle, engine.state.phase == .longBreak {
            celebrationSequence += 1
        }
        notifications.cancelCompletion()
        autoStartIfEnabled(at: date)
        persist()
        recordSession(
            from: completedEngine,
            endedAt: completedEngine.state.endDate ?? date,
            completed: true
        )
    }

    func updateConfiguration(_ configuration: TimerConfiguration, at date: Date = Date()) {
        now = date
        engine.updateConfiguration(configuration, at: date)
        if engine.state.isRunning {
            notifications.cancelCompletion()
            scheduleCompletionIfNeeded()
        }
        persist()
    }

    func updateDurations(
        focusMinutes: Int? = nil,
        shortBreakMinutes: Int? = nil,
        longBreakMinutes: Int? = nil,
        cycle: Int? = nil,
        at date: Date = Date()
    ) {
        let current = engine.configuration
        updateConfiguration(
            TimerConfiguration(
                focusDuration: Double(focusMinutes ?? Int(current.focusDuration / 60)) * 60,
                shortBreakDuration: Double(shortBreakMinutes ?? Int(current.shortBreakDuration / 60)) * 60,
                longBreakDuration: Double(longBreakMinutes ?? Int(current.longBreakDuration / 60)) * 60,
                sessionsPerCycle: cycle ?? current.sessionsPerCycle
            ),
            at: date
        )
    }

    func updatePreferences(_ preferences: TimerPreferences) {
        var preferences = preferences
        if isCommittedFocus {
            preferences.commitmentModeEnabled = true
        }
        self.preferences = preferences
        do {
            try preferencesPersistence.save(preferences)
            errorMessage = nil
        } catch {
            errorMessage = String(
                format: String(localized: "无法保存设置：%@"),
                locale: .autoupdatingCurrent,
                error.localizedDescription
            )
        }
    }

    func addSession(
        type: RecordedSessionType,
        title: String,
        tag: String?,
        startedAt: Date,
        endedAt: Date
    ) {
        guard endedAt >= startedAt else { return }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTag = tag?.trimmingCharacters(in: .whitespacesAndNewlines)
        sessions.append(FocusSession(
            id: UUID(),
            startedAt: startedAt,
            endedAt: endedAt,
            duration: endedAt.timeIntervalSince(startedAt),
            completed: true,
            title: trimmedTitle.isEmpty ? type.defaultTitle : trimmedTitle,
            tag: type == .focus && trimmedTag?.isEmpty == false ? trimmedTag : nil,
            type: type
        ))
        sessions.sort { $0.endedAt > $1.endedAt }
        persistSessions()
    }

    func updateSession(
        id: UUID,
        type: RecordedSessionType,
        title: String,
        tag: String?,
        startedAt: Date,
        endedAt: Date
    ) {
        guard endedAt >= startedAt,
              let index = sessions.firstIndex(where: { $0.id == id }) else { return }
        let original = sessions[index]
        let interruptionDuration = original.interruptions.reduce(0) { total, interruption in
            guard let resumedAt = interruption.resumedAt else { return total }
            return total + max(0, resumedAt.timeIntervalSince(interruption.stoppedAt))
        }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTag = tag?.trimmingCharacters(in: .whitespacesAndNewlines)
        sessions[index] = FocusSession(
            id: original.id,
            startedAt: startedAt,
            endedAt: endedAt,
            duration: max(0, endedAt.timeIntervalSince(startedAt) - interruptionDuration),
            completed: original.completed,
            title: trimmedTitle.isEmpty ? type.defaultTitle : trimmedTitle,
            tag: type == .focus && trimmedTag?.isEmpty == false ? trimmedTag : nil,
            type: type,
            interruptions: original.interruptions
        )
        sessions.sort { $0.endedAt > $1.endedAt }
        persistSessions()
    }

    func deleteSession(id: UUID) {
        guard sessions.contains(where: { $0.id == id }) else { return }
        sessions.removeAll { $0.id == id }
        persistSessions()
    }

    func deleteAllSessions() {
        guard !sessions.isEmpty else { return }
        sessions.removeAll()
        persistSessions()
    }

    func importSessions(_ incoming: [FocusSession]) throws {
        let merged = SessionHistoryPersistence.merge(local: sessions, incoming: incoming)
        guard merged != sessions else { return }
        try historyPersistence.save(merged)
        sessions = merged
    }

    func dismissError() {
        errorMessage = nil
    }

    private func scheduleCompletionIfNeeded() {
        guard preferences.notificationsEnabled else { return }
        guard let endDate = engine.state.endDate else { return }
        var preview = engine
        preview.skip(at: now)
        let nextPhase = preview.state.phase
        notifications.scheduleCompletion(
            at: endDate,
            nextPhase: nextPhase,
            autoStartsNext: nextPhase == .focus
                ? preferences.autoStartFocus
                : preferences.autoStartBreaks,
            sound: engine.state.phase == .focus
                ? preferences.focusCompletionSound
                : preferences.breakCompletionSound,
            volume: preferences.notificationVolume,
            quote: preferences.motivationalQuotesEnabled && engine.state.phase == .focus
                ? MotivationalQuotes.quote(for: endDate)
                : nil
        )
    }

    private func playTickIfNeeded() {
        guard preferences.tickingSoundEnabled,
              engine.state.isRunning,
              engine.state.phase == .focus else {
            lastTickSecond = nil
            return
        }
        let second = remainingSeconds
        guard lastTickSecond != second else { return }
        lastTickSecond = second
        tickSound.playTick(volume: preferences.tickingVolume)
    }

    var isCommittedFocus: Bool {
        preferences.commitmentModeEnabled
            && engine.state.isRunning
            && engine.state.phase == .focus
    }

    private func autoStartIfEnabled(at date: Date) {
        let shouldStart = engine.state.phase == .focus
            ? preferences.autoStartFocus
            : preferences.autoStartBreaks
        guard shouldStart else { return }
        startEngine(at: date)
    }

    private func startEngine(at date: Date) {
        engine.start(at: date)
        scheduleCompletionIfNeeded()
        if preferences.hideWindowWhenTimerStarts {
            AppWindowActivation.hideTimerWindow()
        }
    }

    private func recordSession(from source: TimerEngine, endedAt: Date, completed: Bool) {
        guard let startedAt = source.state.startedAt else { return }
        let plannedDuration = source.configuration.duration(for: source.state.phase)
        let duration = completed
            ? plannedDuration
            : max(0, plannedDuration - source.remaining(at: endedAt))
        guard completed || duration >= 60 else { return }

        let type: RecordedSessionType
        let title: String
        let tag: String?
        switch source.state.phase {
        case .focus:
            type = .focus
            title = preferences.sessionTitle
            tag = nil
        case .shortBreak:
            type = .shortBreak
            title = String(localized: "休息")
            tag = nil
        case .longBreak:
            type = .longBreak
            title = String(localized: "长时间停顿")
            tag = nil
        }

        let session = FocusSession(
            id: UUID(),
            startedAt: startedAt,
            endedAt: endedAt,
            duration: duration,
            completed: completed,
            title: title,
            tag: tag,
            type: type,
            interruptions: source.state.interruptions
        )
        sessions.insert(session, at: 0)
        persistSessions()
    }

    private func persistSessions() {
        do {
            try historyPersistence.save(sessions)
            errorMessage = nil
        } catch {
            errorMessage = String(
                format: String(localized: "无法保存会话记录：%@"),
                locale: .autoupdatingCurrent,
                error.localizedDescription
            )
        }
    }

    private func persist() {
        do {
            try persistence.save(engine)
            errorMessage = nil
        } catch {
            errorMessage = String(
                format: String(localized: "无法保存计时状态：%@"),
                locale: .autoupdatingCurrent,
                error.localizedDescription
            )
        }
    }
}

private extension RecordedSessionType {
    var defaultTitle: String {
        switch self {
        case .focus: "NanaFlow"
        case .shortBreak: String(localized: "休息")
        case .longBreak: String(localized: "长时间停顿")
        }
    }
}
