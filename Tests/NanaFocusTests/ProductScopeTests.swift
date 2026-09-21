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
        XCTAssertTrue(sessions.contains("tag: session?.tag"), "Editing legacy sessions must preserve stored tags")
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
