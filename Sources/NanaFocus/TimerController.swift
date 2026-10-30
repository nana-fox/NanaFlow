import AppKit
import Foundation
import Observation
import Security

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

/// The same read/write operations as KVS, with an in-memory implementation for
/// checks that must never access a person's iCloud account.
@MainActor
protocol TimerCloudStoring: AnyObject {
    func string(forKey key: String) -> String?
    func data(forKey key: String) -> Data?
    func set(_ value: Any?, forKey key: String)
    func synchronize() -> Bool
}

extension NSUbiquitousKeyValueStore: TimerCloudStoring {}

@MainActor
@Observable
final class TimerController {
    static let shared = TimerController()

    private(set) var engine: TimerEngine
    private(set) var preferences: TimerPreferences
    private(set) var tagSettings: SessionTagSettings
    private(set) var sessions: [FocusSession]
    private(set) var now: Date
    private(set) var errorMessage: String?
    private(set) var timerSyncDiagnostics = TimerSyncDiagnostics.unavailable
    private(set) var didStartTimerAtLaunch = false
    private(set) var celebrationSequence = 0

    @ObservationIgnored private let persistence: any TimerPersisting
    @ObservationIgnored private let preferencesPersistence: any TimerPreferencesPersisting
    @ObservationIgnored private let historyPersistence: any SessionHistoryPersisting
    @ObservationIgnored private let tagPersistence: any SessionTagPersisting
    @ObservationIgnored private let notifications: any SessionNotificationScheduling
    @ObservationIgnored private let calendarRecorder: any FocusSessionCalendarRecording
    @ObservationIgnored private let tickSound: any TimerTickSoundPlaying
    @ObservationIgnored private let legacyCoreDataStore: any LegacyCoreDataStoring
    @ObservationIgnored private var lastTickSecond: Int?
    @ObservationIgnored private var cloudStore: (any TimerCloudStoring)?
    @ObservationIgnored private var cloudObserver: NSObjectProtocol?
    @ObservationIgnored private var isApplyingCloudState = false

    private static let cloudEngineKey = "NanaFlow.timerEngine.v1"
    private static let cloudPreferencesKey = "NanaFlow.timerPreferences.v1"
    private static let cloudSettingsKey = "NanaFlow.timerSyncSettings.v1"
    private static let cloudSessionsKey = "NanaFlow.focusSessions.v1"
    private static let cloudSyncKey = "NanaFlow.syncKey.v1"
    private static let localDeviceKey = "NanaFlow.deviceKey.v1"

    init(
        configuration: TimerConfiguration = .standard,
        persistence: any TimerPersisting = TimerPersistence(),
        preferencesPersistence: any TimerPreferencesPersisting = TimerPreferencesPersistence(),
        historyPersistence: any SessionHistoryPersisting = SessionHistoryPersistence(sharedDefaults: NanaFlowShared.defaults),
        tagPersistence: any SessionTagPersisting = SessionTagPersistence(),
        notifications: any SessionNotificationScheduling = SessionNotificationScheduler(),
        calendarRecorder: any FocusSessionCalendarRecording = FocusSessionCalendarRecorder(),
        tickSound: any TimerTickSoundPlaying = TimerTickSoundPlayer(),
        legacyCoreDataStore: any LegacyCoreDataStoring = UserDefaults.standard,
        now: Date = Date()
    ) {
        self.persistence = persistence
        self.preferencesPersistence = preferencesPersistence
        self.historyPersistence = historyPersistence
        self.tagPersistence = tagPersistence
        self.notifications = notifications
        self.calendarRecorder = calendarRecorder
        self.tickSound = tickSound
        self.legacyCoreDataStore = legacyCoreDataStore
        self.now = now
        self.engine = persistence.load() ?? TimerEngine(configuration: configuration)
        self.preferences = preferencesPersistence.load() ?? .standard
        self.tagSettings = tagPersistence.load() ?? .standard
        self.sessions = historyPersistence.load().sorted { $0.endedAt > $1.endedAt }
        historyPersistence.prepareSharedSnapshot()

        if let endDate = engine.state.endDate {
            notifications.restoreCompletion(at: endDate, phase: engine.state.phase)
        }
        let expiredEngine = engine
        if engine.reconcile(at: now) {
            if let endDate = expiredEngine.state.endDate {
                notifications.completeCompletion(at: endDate, phase: expiredEngine.state.phase)
            }
            autoStartIfEnabled(at: now)
            persist()
            recordSession(from: expiredEngine, endedAt: expiredEngine.state.endDate ?? now, completed: true)
        }

        let shouldPersistLaunchState = preferences.resetCycleOnLaunch || preferences.startTimerOnLaunch
        if preferences.resetCycleOnLaunch {
            engine.resetCycle(at: now)
            notifications.cancelCompletion()
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
        if let endDate = completedEngine.state.endDate {
            notifications.completeCompletion(at: endDate, phase: completedEngine.state.phase)
        }
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
        let previous = self.preferences
        let phase = engine.state.phase
        let previousSound = phase == .focus ? previous.focusCompletionSound : previous.breakCompletionSound
        let currentSound = phase == .focus ? preferences.focusCompletionSound : preferences.breakCompletionSound
        let completionChanged = previous.notificationsEnabled != preferences.notificationsEnabled
            || previousSound.fileName(volume: previous.notificationVolume) != currentSound.fileName(volume: preferences.notificationVolume)
        let wasSyncing = previous.timerSyncEnabled
        self.preferences = preferences
        if completionChanged, engine.state.isRunning, engine.state.endDate != nil {
            if preferences.notificationsEnabled { scheduleCompletionIfNeeded() }
            else { notifications.cancelCompletion() }
        }
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
        if let cloudStore {
            if !wasSyncing, preferences.timerSyncEnabled {
                timerSyncDiagnostics.recordLocalProcessing(succeeded: pullTimerState(from: cloudStore))
            } else if preferences.timerSyncEnabled {
                timerSyncDiagnostics.recordLocalProcessing(succeeded: pushTimerState(to: cloudStore))
            }
        }
    }

    func startCloudSync() {
        guard cloudStore == nil else { return }
        guard let task = SecTaskCreateFromSelf(nil),
              let identifier = SecTaskCopyValueForEntitlement(
                task,
                "com.apple.developer.ubiquity-kvstore-identifier" as CFString,
                nil
              ) as? String,
              !identifier.isEmpty else {
            timerSyncDiagnostics = .unavailable
            return
        }
        let store = NSUbiquitousKeyValueStore.default
        let defaults = UserDefaults.standard
        let deviceKey = defaults.string(forKey: Self.localDeviceKey) ?? Self.makeDiagnosticKey()
        defaults.set(deviceKey, forKey: Self.localDeviceKey)
        let syncKey = store.string(forKey: Self.cloudSyncKey) ?? Self.makeDiagnosticKey()
        store.set(syncKey, forKey: Self.cloudSyncKey)
        cloudObserver = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store,
            queue: .main
        ) { [weak self] notification in
            let reason = (notification.userInfo?[NSUbiquitousKeyValueStoreChangeReasonKey] as? NSNumber)?.intValue
            Task { @MainActor [weak self] in self?.handleCloudChange(reason: reason) }
        }
        configureCloudSync(store: store, syncKey: syncKey, deviceKey: deviceKey)
    }

    func configureCloudSync(store: any TimerCloudStoring, syncKey: String, deviceKey: String) {
        cloudStore = store
        timerSyncDiagnostics = TimerSyncDiagnostics(
            status: .available,
            syncKey: syncKey,
            deviceKey: deviceKey,
            lastSyncDate: nil
        )
        guard store.synchronize() else {
            timerSyncDiagnostics.recordLocalProcessing(succeeded: false)
            return
        }
        pullCloudState()
    }

    func handleCloudChange(reason: Int?) {
        guard timerSyncDiagnostics.shouldProcessExternalChange(reason: reason) else { return }
        pullCloudState()
    }

    func addTag(_ name: String, colorHex: String? = nil) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !tagSettings.tags.contains(where: { $0.localizedCaseInsensitiveCompare(trimmed) == .orderedSame }) else { return }
        tagSettings.tags.append(trimmed)
        tagSettings.colors[trimmed] = colorHex.flatMap { color in
            SessionTagSettings.palette.contains(color) ? color : nil
        } ?? SessionTagSettings.palette[(tagSettings.tags.count - 1) % SessionTagSettings.palette.count]
        persistTags()
    }

    func updateTag(_ originalName: String, name: String, colorHex: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let index = tagSettings.tags.firstIndex(of: originalName),
              !trimmed.isEmpty,
              SessionTagSettings.palette.contains(colorHex),
              !tagSettings.tags.enumerated().contains(where: { candidateIndex, candidate in
                  candidateIndex != index
                      && candidate.localizedCaseInsensitiveCompare(trimmed) == .orderedSame
              }) else { return }

        tagSettings.tags[index] = trimmed
        tagSettings.colors.removeValue(forKey: originalName)
        tagSettings.colors[trimmed] = colorHex
        if tagSettings.selectedTag == originalName {
            tagSettings.selectedTag = trimmed
        }
        let referencedSessionIndices = sessions.indices.filter { sessions[$0].tag == originalName }
        for sessionIndex in referencedSessionIndices {
            sessions[sessionIndex].tag = trimmed
        }
        persistTags()
        if !referencedSessionIndices.isEmpty {
            persistSessions()
        }
    }

    func selectTag(_ name: String?) {
        if let name, !tagSettings.tags.contains(name) { return }
        tagSettings.selectedTag = name
        persistTags()
    }

    func tagUsageCount(_ name: String) -> Int {
        sessions.lazy.filter { $0.tag == name }.count
    }

    func removeTag(_ name: String) {
        tagSettings.tags.removeAll { $0 == name }
        tagSettings.colors.removeValue(forKey: name)
        if tagSettings.selectedTag == name {
            tagSettings.selectedTag = nil
        }
        let referencedSessionIndices = sessions.indices.filter { sessions[$0].tag == name }
        for index in referencedSessionIndices {
            sessions[index].tag = nil
        }
        persistTags()
        if !referencedSessionIndices.isEmpty {
            persistSessions()
        }
    }

    func updateSession(id: UUID, title: String, tag: String?) {
        guard let index = sessions.firstIndex(where: { $0.id == id }) else { return }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTag = tag?.trimmingCharacters(in: .whitespacesAndNewlines)
        sessions[index].title = trimmedTitle.isEmpty ? "NanaFlow" : trimmedTitle
        sessions[index].tag = trimmedTag?.isEmpty == false ? trimmedTag : nil
        persistSessions()
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

    func addSessionToCalendar(id: UUID) {
        guard let session = sessions.first(where: { $0.id == id }),
              session.type == .focus,
              session.completed else { return }
        recordSessionInCalendar(session)
    }

    @discardableResult
    func selectCalendar(_ identifier: String?, availableIdentifiers: [String]) -> Bool {
        guard let identifier,
              !identifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              availableIdentifiers.contains(identifier) else {
            errorMessage = CalendarRecordingError.targetUnavailable.message
            return false
        }
        var preferences = self.preferences
        preferences.calendarIdentifier = identifier
        preferences.calendarSyncEnabled = true
        updatePreferences(preferences)
        return true
    }

    private func recordSessionInCalendar(_ session: FocusSession) {
        calendarRecorder.record(
            session,
            calendarIdentifier: preferences.calendarIdentifier
        ) { [weak self] result in
            if case .failure(let error) = result {
                self?.errorMessage = error.message
            }
        }
    }

    func dismissError() {
        errorMessage = nil
    }

    /// Imports the four core values from a legacy NanaFlow preferences file the
    /// person selected. A rejection writes nothing. On success the validated
    /// values replace the in-memory state in the same main-actor turn, so a later
    /// save cannot overwrite the import with launch defaults. This does not start,
    /// schedule, record, sync or play anything.
    func importLegacyCoreData(from url: URL) -> Result<LegacyCoreDataImportOutcome, LegacyCoreDataImportError> {
        let isScoped = url.startAccessingSecurityScopedResource()
        defer {
            if isScoped { url.stopAccessingSecurityScopedResource() }
        }
        do {
            let source = try LegacyCoreDataImportPlan.readPropertyList(at: url)
            return importLegacyCoreData(source: source)
        } catch {
            return .failure(error as? LegacyCoreDataImportError ?? .unreadableFile)
        }
    }

    func importLegacyCoreData(source: [String: Any]) -> Result<LegacyCoreDataImportOutcome, LegacyCoreDataImportError> {
        let plan: LegacyCoreDataImportPlan
        do {
            plan = try LegacyCoreDataImportPlan.make(
                source: source,
                target: legacyCoreDataStore,
                targetTimerRunning: engine.state.isRunning,
                targetHasHistory: !sessions.isEmpty
            )
        } catch {
            return .failure(error as? LegacyCoreDataImportError ?? .unreadableFile)
        }
        // Original bytes are stored unchanged; keys were absent, so a failed
        // read-back tries to remove only what this import added. Not a
        // crash-safe transaction across processes.
        for write in plan.writes {
            legacyCoreDataStore.set(write.data, forKey: write.key)
        }
        guard plan.writes.allSatisfy({ legacyCoreDataStore.object(forKey: $0.key) as? Data == $0.data }) else {
            for write in plan.writes {
                legacyCoreDataStore.set(nil, forKey: write.key)
            }
            return .failure(.writeVerificationFailed)
        }

        // Also refresh when every value was already present: memory may still
        // hold launch defaults that a later save would otherwise write back.
        engine = plan.engine
        preferences = plan.preferences
        sessions = plan.sessions.sorted { $0.endedAt > $1.endedAt }
        if let tags = plan.tags {
            tagSettings = tags
        }
        lastTickSecond = nil
        errorMessage = nil
        return .success(plan.writes.isEmpty ? .alreadyPresent : .imported(writtenKeys: plan.writes.map(\.key)))
    }

    private func scheduleCompletionIfNeeded() {
        guard preferences.notificationsEnabled else { return }
        guard let endDate = engine.state.endDate else { return }
        var preview = engine
        preview.skip(at: now)
        let nextPhase = preview.state.phase
        notifications.scheduleCompletion(
            at: endDate,
            phase: engine.state.phase,
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
            tag = tagSettings.selectedTag
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
        if completed, type == .focus, preferences.calendarSyncEnabled {
            recordSessionInCalendar(session)
        }
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
        pushHistoryToCloud()
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
        guard !isApplyingCloudState,
              preferences.timerSyncEnabled,
              let cloudStore else { return }
        timerSyncDiagnostics.recordLocalProcessing(succeeded: pushTimerState(to: cloudStore))
    }

    private func persistTags() {
        do {
            try tagPersistence.save(tagSettings)
            errorMessage = nil
        } catch {
            errorMessage = String(
                format: String(localized: "无法保存标签：%@"),
                locale: .autoupdatingCurrent,
                error.localizedDescription
            )
        }
    }

    private func pullCloudState() {
        guard let cloudStore else { return }
        if let syncKey = cloudStore.string(forKey: Self.cloudSyncKey) {
            timerSyncDiagnostics.syncKey = syncKey
        }
        let historyProcessed = pullHistory(from: cloudStore)
        let timerProcessed = historyProcessed && (!preferences.timerSyncEnabled || pullTimerState(from: cloudStore))
        timerSyncDiagnostics.recordLocalProcessing(succeeded: timerProcessed)
    }

    private func pullHistory(from store: any TimerCloudStoring) -> Bool {
        guard let data = store.data(forKey: Self.cloudSessionsKey),
              let incoming = try? JSONDecoder().decode([FocusSession].self, from: data) else {
            return writeHistory(to: store)
        }
        let merged = SessionHistoryPersistence.merge(local: sessions, incoming: incoming)
        guard merged != sessions else { return true }
        sessions = merged
        do {
            try historyPersistence.save(merged)
            store.set(try JSONEncoder().encode(merged), forKey: Self.cloudSessionsKey)
            return store.synchronize()
        } catch {
            errorMessage = String(
                format: String(localized: "无法同步会话记录：%@"),
                locale: .autoupdatingCurrent,
                error.localizedDescription
            )
            return false
        }
    }

    private func pullTimerState(from store: any TimerCloudStoring) -> Bool {
        let decoder = JSONDecoder()
        guard let engineData = store.data(forKey: Self.cloudEngineKey),
              let remoteEngine = try? decoder.decode(TimerEngine.self, from: engineData) else {
            return pushTimerState(to: store)
        }

        isApplyingCloudState = true
        defer { isApplyingCloudState = false }
        engine = remoteEngine
        now = Date()
        _ = engine.reconcile(at: now)
        let settings = store.data(forKey: Self.cloudSettingsKey)
            .flatMap { try? decoder.decode(TimerSyncSettings.self, from: $0) }
            ?? store.data(forKey: Self.cloudPreferencesKey)
                .flatMap { try? decoder.decode(TimerPreferences.self, from: $0) }
                .map { TimerSyncSettings(configuration: remoteEngine.configuration, preferences: $0) }
        if let settings {
            engine.updateConfiguration(settings.configuration, at: now)
            preferences = settings.applying(to: preferences)
        }
        notifications.cancelCompletion()
        if engine.state.isRunning { scheduleCompletionIfNeeded() }
        do {
            try persistence.save(engine)
            try preferencesPersistence.save(preferences)
            errorMessage = nil
            return true
        } catch {
            errorMessage = String(
                format: String(localized: "无法同步计时器：%@"),
                locale: .autoupdatingCurrent,
                error.localizedDescription
            )
            return false
        }
    }

    private func pushTimerState(to store: any TimerCloudStoring) -> Bool {
        guard preferences.timerSyncEnabled,
              let engineData = try? JSONEncoder().encode(engine),
              let settingsData = try? JSONEncoder().encode(TimerSyncSettings(
                  configuration: engine.configuration,
                  preferences: preferences
              )) else { return false }
        store.set(engineData, forKey: Self.cloudEngineKey)
        store.set(settingsData, forKey: Self.cloudSettingsKey)
        return store.synchronize()
    }

    private func pushHistoryToCloud() {
        guard let cloudStore else { return }
        timerSyncDiagnostics.recordLocalProcessing(succeeded: writeHistory(to: cloudStore))
    }

    private func writeHistory(to store: any TimerCloudStoring) -> Bool {
        // ponytail: iCloud KVS is capped; migrate this payload to CloudKit if histories approach 1 MB.
        guard let data = try? JSONEncoder().encode(sessions) else { return false }
        store.set(data, forKey: Self.cloudSessionsKey)
        return store.synchronize()
    }

    private static func makeDiagnosticKey() -> String {
        String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(8)).uppercased()
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
