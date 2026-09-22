import XCTest
@testable import NanaFlow

@MainActor
final class ProductScopeTests: XCTestCase {
    func testVersionOneStatisticsAndSessionEditingDoNotExposeTags() throws {
        let source = try sourceFile("StatisticsView.swift")
        let sessions = try XCTUnwrap(
            source.split(separator: "struct AllSessionsView", maxSplits: 1).last?
                .split(separator: "private extension View", maxSplits: 1).first
        )

        XCTAssertFalse(sessions.contains("SessionListMenuVisualMetrics.filterTitle"))
        XCTAssertFalse(sessions.contains("filterSelectionBinding"))
        XCTAssertFalse(sessions.contains("Picker(\"标签\""))
        XCTAssertFalse(sessions.contains("if let tag = session.tag"))
        XCTAssertTrue(sessions.contains("tag: session.tag"), "Editing legacy sessions must preserve stored tags")
    }

    func testVersionOneHasNoCalendarOrCloudEntryPoints() throws {
        let app = try sourceFile("NanaFocusApp.swift")
        let commands = try sourceFile("NanaFlowCommands.swift")
        let settings = try sourceFile("TimerSettingsView.swift")
        let controller = try sourceFile("TimerController.swift")

        XCTAssertFalse(app.contains("Calendar Alert"))
        XCTAssertFalse(app.contains("Calendar Chooser"))
        XCTAssertFalse(app.contains("controller.startCloudSync()"))
        XCTAssertFalse(commands.contains("Calendar Alert"))
        XCTAssertFalse(commands.contains("Calendar Chooser"))
        XCTAssertFalse(settings.contains("calendarPermissionBinding"))
        XCTAssertFalse(settings.contains("handleCalendarRoute"))
        XCTAssertFalse(controller.contains("calendarRecorder.record("))
        XCTAssertFalse(controller.contains("func addSessionToCalendar"))
    }

    func testDormantExcludedFeatureSourceFilesDoNotExist() {
        let repositoryURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourcesRoot = repositoryURL.appendingPathComponent("Sources/NanaFocus")
        let removedFiles = [
            "FocusSessionCalendarRecorder.swift",
            "BlockerConfiguration.swift",
            "BlockerView.swift",
            "BrowserURLController.swift",
            "ProUnlockedView.swift",
            "TagManagementView.swift",
            "SessionTags.swift",
            "TimerSyncView.swift",
            "Blocked.html",
            "NanaFlowBlockedIcon.png",
            "NanaFlowCalendarAccess.png",
        ]
        for name in removedFiles {
            XCTAssertFalse(
                FileManager.default.fileExists(atPath: sourcesRoot.appendingPathComponent(name).path),
                "\(name) belongs to an excluded feature and must not be reintroduced into version 1.0"
            )
        }
    }

    func testRemovedFeatureResourcesDoNotShipInTheAppBundle() {
        XCTAssertNil(
            Bundle.main.url(forResource: "Blocked", withExtension: "html"),
            "Blocked.html was only used by the removed Blocker feature"
        )
        XCTAssertNil(
            Bundle.main.url(forResource: "NanaFlowBlockedIcon", withExtension: "png"),
            "NanaFlowBlockedIcon.png was only used by the removed Blocker feature"
        )
        XCTAssertNil(
            Bundle.main.url(forResource: "NanaFlowCalendarAccess", withExtension: "png"),
            "NanaFlowCalendarAccess.png was only used by the removed Calendar feature"
        )
    }

    func testTimerControllerHasNoTagCatalogOrCloudSyncSurface() throws {
        let controller = try sourceFile("TimerController.swift")

        XCTAssertFalse(controller.contains("func addTag("))
        XCTAssertFalse(controller.contains("func updateTag("))
        XCTAssertFalse(controller.contains("func removeTag("))
        XCTAssertFalse(controller.contains("func selectTag("))
        XCTAssertFalse(controller.contains("tagSettings"))
        XCTAssertFalse(controller.contains("SessionTagSettings"))
        XCTAssertFalse(controller.contains("cloudStore"))
        XCTAssertFalse(controller.contains("NSUbiquitousKeyValueStore"))
        XCTAssertFalse(controller.contains("pushHistoryToCloud"))
        XCTAssertFalse(controller.contains("import Security"))
        XCTAssertTrue(controller.contains("func updateSession(\n        id: UUID,\n        type: RecordedSessionType,"))
    }

    func testTimerPreferencesHasNoTimerSyncSurface() throws {
        let preferences = try sourceFile("TimerPreferences.swift")

        XCTAssertFalse(preferences.contains("timerSyncEnabled"))
        XCTAssertFalse(preferences.contains("calendarSyncEnabled"))
        XCTAssertFalse(preferences.contains("calendarIdentifier"))
    }

    private func sourceFile(_ name: String) throws -> String {
        let repositoryURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(
            contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFocus/\(name)"),
            encoding: .utf8
        )
    }
}
