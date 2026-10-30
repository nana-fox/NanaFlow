import XCTest
@testable import NanaFlow

/// Synthetic data only: stores are in memory or throwaway suites, so no test
/// touches `UserDefaults.standard`, a production domain, the App Group or iCloud.
@MainActor
final class LegacyCoreDataImportTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 50_000)
    private let engineKey = TimerPersistence.storageKey
    private let preferencesKey = TimerPreferencesPersistence.storageKey
    private let historyKey = SessionHistoryPersistence.storageKey
    private let tagsKey = SessionTagPersistence.storageKey

    func testImportStoresOriginalBytesAndRefreshesControllerWithoutSideEffects() throws {
        let source = try makeSource(sessionCount: 236)
        let harness = Harness(start: start)

        let result = harness.controller.importLegacyCoreData(source: source.dictionary)

        XCTAssertEqual(result, .success(.imported(writtenKeys: [engineKey, preferencesKey, historyKey])))
        XCTAssertEqual(harness.store.values[engineKey] as? Data, source.engineData)
        XCTAssertEqual(harness.store.values[preferencesKey] as? Data, source.preferencesData)
        XCTAssertEqual(harness.store.values[historyKey] as? Data, source.historyData)
        XCTAssertNil(harness.store.values[tagsKey])
        XCTAssertEqual(harness.controller.engine, source.engine)
        XCTAssertEqual(harness.controller.formattedTime, "05:00")
        XCTAssertFalse(harness.controller.engine.state.isRunning)
        XCTAssertEqual(harness.controller.preferences, source.preferences)
        XCTAssertEqual(harness.controller.sessions, source.sessions.sorted { $0.endedAt > $1.endedAt })
        XCTAssertEqual(harness.controller.sessions.count, 236)
        XCTAssertEqual(harness.controller.tagSettings, .standard)
        harness.assertNoSideEffects()
    }

    func testImportIncludesValidTagsOnlyWhenTheSourceHasThem() throws {
        let tags = SessionTagSettings(tags: ["Synthetic"], selectedTag: nil)
        let tagsData = try JSONEncoder().encode(tags)
        var source = try makeSource(sessionCount: 2)
        source.dictionary[tagsKey] = tagsData
        let harness = Harness(start: start)

        let result = harness.controller.importLegacyCoreData(source: source.dictionary)

        XCTAssertEqual(result, .success(.imported(writtenKeys: [engineKey, preferencesKey, historyKey, tagsKey])))
        XCTAssertEqual(harness.store.values[tagsKey] as? Data, tagsData)
        XCTAssertEqual(harness.controller.tagSettings, tags)
        harness.assertNoSideEffects()
    }

    func testUnrelatedSourceKeysAreNeverImported() throws {
        var source = try makeSource(sessionCount: 1)
        source.dictionary["showWindowOnLaunch"] = true
        source.dictionary["NSWindow Frame Main"] = "0 0 380 272"
        let harness = Harness(start: start)

        _ = harness.controller.importLegacyCoreData(source: source.dictionary)

        XCTAssertEqual(Set(harness.store.values.keys), [engineKey, preferencesKey, historyKey])
    }

    func testMissingInvalidOrNonDataSourceValuesWriteNothing() throws {
        let valid = try makeSource(sessionCount: 1)
        var cases: [(String, [String: Any], LegacyCoreDataImportError)] = []
        for key in [engineKey, preferencesKey, historyKey] {
            var missing = valid.dictionary
            missing.removeValue(forKey: key)
            cases.append(("missing \(key)", missing, .incompleteData))
            var nonData = valid.dictionary
            nonData[key] = "not data"
            cases.append(("non-Data \(key)", nonData, .incompleteData))
            var invalid = valid.dictionary
            invalid[key] = Data("not json".utf8)
            cases.append(("invalid \(key)", invalid, .undecodableData))
        }
        var invalidTags = valid.dictionary
        invalidTags[tagsKey] = Data("[]".utf8)
        cases.append(("invalid tags", invalidTags, .undecodableData))
        var nonDataTags = valid.dictionary
        nonDataTags[tagsKey] = ["Synthetic"]
        cases.append(("non-Data tags", nonDataTags, .incompleteData))
        cases.append(("empty", [:], .incompleteData))

        for (name, source, expected) in cases {
            let harness = Harness(start: start)
            XCTAssertEqual(harness.controller.importLegacyCoreData(source: source), .failure(expected), name)
            XCTAssertTrue(harness.store.values.isEmpty, name)
            XCTAssertEqual(harness.store.writeCount, 0, name)
            XCTAssertEqual(harness.controller.formattedTime, "25:00", name)
        }
    }

    func testAnyTargetConflictRejectsTheWholeImport() throws {
        let source = try makeSource(sessionCount: 1)
        for key in [engineKey, preferencesKey, historyKey] {
            for existing in [Data("different".utf8) as Any, "not data" as Any] {
                let harness = Harness(start: start)
                harness.store.values[key] = existing

                XCTAssertEqual(harness.controller.importLegacyCoreData(source: source.dictionary), .failure(.conflictingData))
                XCTAssertEqual(harness.store.values.count, 1, key)
                XCTAssertEqual(harness.store.writeCount, 0, key)
                XCTAssertEqual(harness.controller.formattedTime, "25:00", key)
            }
        }

        var withTags = source.dictionary
        withTags[tagsKey] = try JSONEncoder().encode(SessionTagSettings(tags: ["Synthetic"], selectedTag: nil))
        let harness = Harness(start: start)
        harness.store.values[tagsKey] = Data("different".utf8)
        XCTAssertEqual(harness.controller.importLegacyCoreData(source: withTags), .failure(.conflictingData))
        XCTAssertEqual(harness.store.writeCount, 0)
    }

    func testIdenticalTargetWritesOnlyMissingKeysAndFullMatchIsANoOp() throws {
        let source = try makeSource(sessionCount: 3)
        let partial = Harness(start: start)
        partial.store.values[preferencesKey] = source.preferencesData

        XCTAssertEqual(
            partial.controller.importLegacyCoreData(source: source.dictionary),
            .success(.imported(writtenKeys: [engineKey, historyKey]))
        )
        XCTAssertEqual(partial.store.writeCount, 2)

        let complete = Harness(start: start, history: source.sessions)
        complete.store.values = [
            engineKey: source.engineData,
            preferencesKey: source.preferencesData,
            historyKey: source.historyData,
        ]
        XCTAssertEqual(complete.controller.importLegacyCoreData(source: source.dictionary), .success(.alreadyPresent))
        XCTAssertEqual(complete.store.writeCount, 0)
        complete.assertNoSideEffects()
    }

    func testAlreadyPresentBytesStillRefreshStaleMemoryWithoutWriting() throws {
        let source = try makeSource(sessionCount: 5)
        let harness = Harness(start: start)
        harness.store.values = [
            engineKey: source.engineData,
            preferencesKey: source.preferencesData,
            historyKey: source.historyData,
        ]
        XCTAssertEqual(harness.controller.formattedTime, "25:00")

        XCTAssertEqual(harness.controller.importLegacyCoreData(source: source.dictionary), .success(.alreadyPresent))

        XCTAssertEqual(harness.store.writeCount, 0)
        XCTAssertEqual(harness.controller.engine, source.engine)
        XCTAssertEqual(harness.controller.formattedTime, "05:00")
        XCTAssertEqual(harness.controller.preferences, source.preferences)
        XCTAssertEqual(harness.controller.sessions, source.sessions.sorted { $0.endedAt > $1.endedAt })
        harness.assertNoSideEffects()
    }

    func testExistingHistoryIsNeverMergedOrOverwritten() throws {
        let source = try makeSource(sessionCount: 3)
        let existing = try makeSource(sessionCount: 1).sessions
        let harness = Harness(start: start, history: existing)

        XCTAssertEqual(harness.controller.importLegacyCoreData(source: source.dictionary), .failure(.conflictingData))
        XCTAssertTrue(harness.store.values.isEmpty)
        XCTAssertEqual(harness.controller.sessions, existing)
        XCTAssertEqual(harness.history.saveCount, 0)
    }

    func testHistoryRecoveredFromTheSharedMirrorIsNeverOverwritten() throws {
        let suffix = UUID().uuidString
        let primary = try XCTUnwrap(UserDefaults(suiteName: "LegacyImportPrimary-\(suffix)"))
        let shared = try XCTUnwrap(UserDefaults(suiteName: "LegacyImportShared-\(suffix)"))
        defer {
            primary.removePersistentDomain(forName: "LegacyImportPrimary-\(suffix)")
            shared.removePersistentDomain(forName: "LegacyImportShared-\(suffix)")
        }
        let source = try makeSource(sessionCount: 3)
        let existing = try makeSource(sessionCount: 1).sessions
        shared.set(try JSONEncoder().encode(existing), forKey: historyKey)
        let harness = Harness(
            start: start,
            historyPersistence: SessionHistoryPersistence(
                defaults: primary,
                sharedDefaults: shared,
                reloadWidgetTimelines: {}
            )
        )

        XCTAssertEqual(harness.controller.importLegacyCoreData(source: source.dictionary), .failure(.conflictingData))
        XCTAssertTrue(harness.store.values.isEmpty)
        XCTAssertEqual(harness.controller.sessions, existing)
        let mirrored = try XCTUnwrap(shared.data(forKey: historyKey))
        XCTAssertEqual(try JSONDecoder().decode([FocusSession].self, from: mirrored), existing)
    }

    func testRunningTimersAndLaunchOrSyncFlagsAreRejected() throws {
        let running = try makeSource(sessionCount: 1, engine: TimerEngine(
            configuration: .standard,
            state: TimerState(
                phase: .focus,
                cycleIndex: 0,
                remainingWhenPaused: 1_500,
                endDate: start.addingTimeInterval(1_500),
                startedAt: start
            )
        ))
        let sourceHarness = Harness(start: start)
        XCTAssertEqual(sourceHarness.controller.importLegacyCoreData(source: running.dictionary), .failure(.sourceTimerRunning))
        XCTAssertEqual(sourceHarness.store.writeCount, 0)

        let flags: [WritableKeyPath<TimerPreferences, Bool>] = [
            \.startTimerOnLaunch, \.resetCycleOnLaunch, \.timerSyncEnabled,
        ]
        for flag in flags {
            var preferences = TimerPreferences.standard
            preferences[keyPath: flag] = true
            let source = try makeSource(sessionCount: 1, preferences: preferences)
            let harness = Harness(start: start)
            XCTAssertEqual(harness.controller.importLegacyCoreData(source: source.dictionary), .failure(.unsafeLaunchSettings))
            XCTAssertEqual(harness.store.writeCount, 0)
            XCTAssertEqual(harness.controller.preferences, .standard)
        }

        let targetHarness = Harness(start: start)
        targetHarness.controller.start(at: start)
        let persistedBeforeImport = targetHarness.persistence.saveCount
        let source = try makeSource(sessionCount: 1)
        XCTAssertEqual(targetHarness.controller.importLegacyCoreData(source: source.dictionary), .failure(.targetTimerRunning))
        XCTAssertEqual(targetHarness.store.writeCount, 0)
        XCTAssertTrue(targetHarness.controller.engine.state.isRunning)
        XCTAssertEqual(targetHarness.persistence.saveCount, persistedBeforeImport)
    }

    func testFileReaderAcceptsOnlyBoundedPropertyLists() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LegacyCoreDataImportTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let source = try makeSource(sessionCount: 2)
        let plistURL = directory.appendingPathComponent("synthetic.plist")
        try PropertyListSerialization.data(fromPropertyList: source.dictionary, format: .binary, options: 0)
            .write(to: plistURL)
        let harness = Harness(start: start)
        XCTAssertEqual(
            harness.controller.importLegacyCoreData(from: plistURL),
            .success(.imported(writtenKeys: [engineKey, preferencesKey, historyKey]))
        )
        XCTAssertEqual(harness.store.values[historyKey] as? Data, source.historyData)

        let emptyURL = directory.appendingPathComponent("empty.plist")
        try Data().write(to: emptyURL)
        let textURL = directory.appendingPathComponent("text.plist")
        try Data("not a property list".utf8).write(to: textURL)
        let arrayURL = directory.appendingPathComponent("array.plist")
        try PropertyListSerialization.data(fromPropertyList: ["x"], format: .xml, options: 0).write(to: arrayURL)
        for url in [emptyURL, textURL, arrayURL, directory.appendingPathComponent("absent.plist")] {
            let rejected = Harness(start: start)
            XCTAssertEqual(rejected.controller.importLegacyCoreData(from: url), .failure(.unreadableFile), url.lastPathComponent)
            XCTAssertEqual(rejected.store.writeCount, 0)
        }
        XCTAssertThrowsError(try LegacyCoreDataImportPlan.propertyList(
            from: Data(count: LegacyCoreDataImportPlan.maximumFileSize + 1)
        ))
    }

    // MARK: - Synthetic fixtures

    private struct Source {
        var dictionary: [String: Any]
        let engine: TimerEngine
        let preferences: TimerPreferences
        let sessions: [FocusSession]
        let engineData: Data
        let preferencesData: Data
        let historyData: Data
    }

    private func makeSource(
        sessionCount: Int,
        engine: TimerEngine? = nil,
        preferences: TimerPreferences = .standard
    ) throws -> Source {
        let engine = engine ?? TimerEngine(
            configuration: .standard,
            state: TimerState(phase: .shortBreak, cycleIndex: 0, remainingWhenPaused: 300, endDate: nil, startedAt: nil)
        )
        // Oldest first: the stored order differs from the controller's sorted
        // order, so the byte check proves nothing was re-encoded or reordered.
        let sessions = (0..<sessionCount).map { index in
            let endedAt = start.addingTimeInterval(TimeInterval(index - sessionCount) * 1_800)
            return FocusSession(
                id: UUID(),
                startedAt: endedAt.addingTimeInterval(-1_500),
                endedAt: endedAt,
                duration: 1_500,
                completed: true,
                title: UUID().uuidString,
                tag: nil,
                type: .focus,
                interruptions: []
            )
        }
        // Pretty, sorted output differs from the app's default encoder bytes.
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let engineData = try encoder.encode(engine)
        let preferencesData = try encoder.encode(preferences)
        let historyData = try encoder.encode(sessions)
        return Source(
            dictionary: [
                engineKey: engineData,
                preferencesKey: preferencesData,
                historyKey: historyData,
            ],
            engine: engine,
            preferences: preferences,
            sessions: sessions,
            engineData: engineData,
            preferencesData: preferencesData,
            historyData: historyData
        )
    }

    @MainActor
    private final class Harness {
        let store = ImportMemoryStore()
        let persistence = ImportEngineSpy()
        let preferences = ImportPreferencesSpy()
        let history: ImportHistorySpy
        let tags = ImportTagSpy()
        let notifications = ImportNotificationSpy()
        let calendar = ImportCalendarSpy()
        let tick = ImportTickSpy()
        let cloud = ImportCloudSpy()
        let controller: TimerController

        init(
            start: Date,
            history sessions: [FocusSession] = [],
            historyPersistence: (any SessionHistoryPersisting)? = nil
        ) {
            history = ImportHistorySpy(loaded: sessions)
            controller = TimerController(
                persistence: persistence,
                preferencesPersistence: preferences,
                historyPersistence: historyPersistence ?? history,
                tagPersistence: tags,
                notifications: notifications,
                calendarRecorder: calendar,
                tickSound: tick,
                legacyCoreDataStore: store,
                now: start
            )
            controller.configureCloudSync(store: cloud, syncKey: "SYNTHETIC", deviceKey: "SYNTHETIC")
            cloud.writeCount = 0
            history.saveCount = 0
        }

        func assertNoSideEffects(file: StaticString = #filePath, line: UInt = #line) {
            XCTAssertEqual(persistence.saveCount, 0, "engine persist", file: file, line: line)
            XCTAssertEqual(preferences.saveCount, 0, "preferences persist", file: file, line: line)
            XCTAssertEqual(history.saveCount, 0, "history persist", file: file, line: line)
            XCTAssertEqual(tags.saveCount, 0, "tags persist", file: file, line: line)
            XCTAssertEqual(notifications.callCount, 0, "notifications", file: file, line: line)
            XCTAssertEqual(calendar.recordCount, 0, "calendar", file: file, line: line)
            XCTAssertEqual(tick.playCount, 0, "tick sound", file: file, line: line)
            XCTAssertEqual(cloud.writeCount, 0, "cloud push", file: file, line: line)
        }
    }
}

private final class ImportMemoryStore: LegacyCoreDataStoring {
    var values: [String: Any] = [:]
    private(set) var writeCount = 0

    func object(forKey key: String) -> Any? { values[key] }

    func set(_ value: Any?, forKey key: String) {
        writeCount += 1
        values[key] = value
    }
}

@MainActor
private final class ImportEngineSpy: TimerPersisting {
    private(set) var saveCount = 0
    func load() -> TimerEngine? { nil }
    func save(_: TimerEngine) throws { saveCount += 1 }
}

@MainActor
private final class ImportPreferencesSpy: TimerPreferencesPersisting {
    private(set) var saveCount = 0
    func load() -> TimerPreferences? { nil }
    func save(_: TimerPreferences) throws { saveCount += 1 }
}

@MainActor
private final class ImportHistorySpy: SessionHistoryPersisting {
    private let loaded: [FocusSession]
    var saveCount = 0
    init(loaded: [FocusSession]) { self.loaded = loaded }
    func load() -> [FocusSession] { loaded }
    func save(_: [FocusSession]) throws { saveCount += 1 }
    func prepareSharedSnapshot() {}
}

@MainActor
private final class ImportTagSpy: SessionTagPersisting {
    private(set) var saveCount = 0
    func load() -> SessionTagSettings? { nil }
    func save(_: SessionTagSettings) throws { saveCount += 1 }
}

@MainActor
private final class ImportNotificationSpy: SessionNotificationScheduling {
    private(set) var callCount = 0
    func scheduleCompletion(at _: Date, nextPhase _: SessionPhase, sound _: CompletionSound, volume _: Double, quote _: String?) {
        callCount += 1
    }
    func restoreCompletion(at _: Date, phase _: SessionPhase) { callCount += 1 }
    func completeCompletion(at _: Date, phase _: SessionPhase) { callCount += 1 }
    func cancelCompletion() { callCount += 1 }
}

@MainActor
private final class ImportCalendarSpy: FocusSessionCalendarRecording {
    private(set) var recordCount = 0
    func record(
        _: FocusSession,
        calendarIdentifier _: String?,
        completion _: @escaping @MainActor (Result<Void, CalendarRecordingError>) -> Void
    ) {
        recordCount += 1
    }
}

@MainActor
private final class ImportTickSpy: TimerTickSoundPlaying {
    private(set) var playCount = 0
    func playTick(volume _: Double) { playCount += 1 }
}

@MainActor
private final class ImportCloudSpy: TimerCloudStoring {
    private var values: [String: Any] = [:]
    var writeCount = 0
    func string(forKey key: String) -> String? { values[key] as? String }
    func data(forKey key: String) -> Data? { values[key] as? Data }
    func set(_ value: Any?, forKey key: String) {
        writeCount += 1
        values[key] = value
    }
    func synchronize() -> Bool { true }
}
