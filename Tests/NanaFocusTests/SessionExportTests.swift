import XCTest
@testable import NanaFlow

final class SessionExportTests: XCTestCase {
    func testEmptyCSVKeepsFlowsHeaderNewline() {
        XCTAssertEqual(
            SessionExporter.csv(
                sessions: [],
                timeZone: TimeZone(secondsFromGMT: 0)!,
                locale: Locale(identifier: "en_US_POSIX")
            ),
            "Session,Started,Completed,Tag,Interruptions,Total Time\n"
        )
    }

    func testCSVQuotesUserContentAndKeepsStableColumns() {
        let end = Date(timeIntervalSince1970: 0)
        let session = FocusSession(
            id: UUID(),
            startedAt: end.addingTimeInterval(-1_530),
            endedAt: end,
            duration: 1_500,
            completed: true,
            title: "NanaFlow, 深度工作",
            tag: "工作\"重点",
            interruptions: [
                SessionInterruption(
                    stoppedAt: end.addingTimeInterval(-1_500),
                    resumedAt: end.addingTimeInterval(-1_470)
                )
            ]
        )

        let csv = SessionExporter.csv(
            sessions: [session],
            timeZone: TimeZone(secondsFromGMT: 0)!,
            locale: Locale(identifier: "en_US_POSIX")
        )

        XCTAssertEqual(
            csv,
            "Session,Started,Completed,Tag,Interruptions,Total Time\n" +
                "\"NanaFlow, 深度工作\",1969-12-31 23:34:30,1970-01-01 00:00:00," +
                "\"工作\"\"重点\",0h 0m 30s,0h 25m 0s"
        )
    }

    func testCSVUsesFlowPlaceholdersForIncompleteAndUntaggedSessions() {
        let end = Date(timeIntervalSince1970: 600)
        let session = FocusSession(
            id: UUID(),
            startedAt: Date(timeIntervalSince1970: 0),
            endedAt: end,
            duration: 600,
            completed: false,
            title: "",
            type: .shortBreak
        )

        let csv = SessionExporter.csv(
            sessions: [session],
            timeZone: TimeZone(secondsFromGMT: 0)!,
            locale: Locale(identifier: "en_US_POSIX")
        )

        XCTAssertEqual(
            csv.components(separatedBy: "\n").last,
            "\"休息\",1970-01-01 00:00:00,---,\"\",0h 0m 0s,0h 0m 0s"
        )
    }

    func testPlainTextExportMatchesFlowsDatedSessionFormat() {
        XCTAssertEqual(SessionExporter.plainText(sessions: []), "0 NanaFlows")

        let end = Date(timeIntervalSince1970: 600)
        let completed = FocusSession(
            id: UUID(),
            startedAt: Date(timeIntervalSince1970: 0),
            endedAt: end,
            duration: 600,
            completed: true,
            title: "深度工作",
            tag: "工作"
        )
        let incomplete = FocusSession(
            id: UUID(),
            startedAt: Date(timeIntervalSince1970: 3_600),
            endedAt: Date(timeIntervalSince1970: 3_900),
            duration: 300,
            completed: false,
            title: "休息",
            type: .shortBreak
        )

        let text = SessionExporter.plainText(
            sessions: [completed, incomplete],
            timeZone: TimeZone(secondsFromGMT: 0)!,
            locale: Locale(identifier: "en_US_POSIX")
        )

        XCTAssertEqual(
            text,
            "深度工作 [工作]: Jan 1, 1970 at 12:00:00\u{202F}AM - Jan 1, 1970 at 12:10:00\u{202F}AM\n\n" +
                "休息: Jan 1, 1970 at 1:00:00\u{202F}AM - ---"
        )
    }
}
