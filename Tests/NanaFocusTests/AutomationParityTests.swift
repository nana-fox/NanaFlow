import AppIntents
import XCTest
@testable import NanaFlow

final class AutomationParityTests: XCTestCase {
    func testScriptingDefinitionMatchesFlowsPublicCommandContract() throws {
        let repositoryURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let definition = try String(
            contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFocus/NanaFlow.sdef"),
            encoding: .utf8
        )
        let requiredFragments = [
            #"<suite name="NanaFlow Suite" code="Flow" description="Suite for NanaFlow commands.">"#,
            #"<command name="start" code="StartCom" description="Start or resume the current session.">"#,
            #"<result type="text" description="The name of the started session."/>"#,
            #"<command name="stop" code="StopComm" description="Stops the current session.">"#,
            #"<result type="text" description="The name of the stopped session."/>"#,
            #"<command name="skip" code="SkipComm" description="Skips the current session.">"#,
            #"<command name="previous" code="PrevComm" description="Reloads the current or previous session.">"#,
            #"<command name="reset" code="ResetCom" description="Resets the session progress.">"#,
            #"<result type="text" description="The name of the next pending session."/>"#,
            #"<command name="show" code="ShowComm" description="Shows the NanaFlow app window.">"#,
            #"<command name="hide" code="HideComm" description="Hides the NanaFlow app window.">"#,
            #"<command name="getPhase" code="PhaseCom" description="Gets the current phase.">"#,
            #"<result type="text" description="The name of the current session."/>"#,
            #"<command name="getTime" code="TimeComm" description="Gets the remaining time.">"#,
            #"<result type="text" description="The remaining time of the current session."/>"#,
            #"<command name="setTitle" code="TitleCom" description="Sets the session title.">"#,
            #"<parameter name="to" code="TiPa" description="Session title" type="text">"#,
            #"<result type="text" description="The title of the current session."/>"#,
            #"<command name="getTitle" code="GetTiCom" description="Gets the current session title.">"#
        ]

        for fragment in requiredFragments {
            XCTAssertTrue(definition.contains(fragment), "Missing SDEF fragment: \(fragment)")
        }
    }

    func testPhaseOutputUsesFlowsTypedThreeCaseContract() {
        XCTAssertEqual(Phase(.focus), .flow)
        XCTAssertEqual(Phase(.shortBreak), .shortBreak)
        XCTAssertEqual(Phase(.longBreak), .longBreak)
        XCTAssertEqual(Phase.allCases.map(\.rawValue), ["flow", "shortBreak", "longBreak"])
    }

    func testCommandForegroundPolicyMatchesFlowMetadata() {
        XCTAssertTrue(StartSessionIntent.openAppWhenRun)
        XCTAssertTrue(PauseSessionIntent.openAppWhenRun)
        XCTAssertTrue(SkipSessionIntent.openAppWhenRun)
        XCTAssertTrue(ResetCycleIntent.openAppWhenRun)
        XCTAssertTrue(OpenAppIntent.openAppWhenRun)
        XCTAssertFalse(ToggleTimerIntent.openAppWhenRun)
    }

    func testFlowNamedReadIntentsRemainConstructible() {
        _ = GetCurrentPhaseIntent()
        _ = GetRemainingTimeIntent()
        _ = OpenAppIntent()
    }

    func testShortcutPhrasesMatchFlowsEnglishMetadata() throws {
        let repositoryURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFocus/AutomationIntents.swift"),
            encoding: .utf8
        )

        for phrase in [
            "Start or Resume \\(.applicationName)",
            "Pause \\(.applicationName)",
            "Skip Session in \\(.applicationName)",
            "Reset \\(.applicationName) Cycle",
            "Set \\(.applicationName) session title",
        ] {
            XCTAssertTrue(source.contains(phrase), phrase)
        }
        XCTAssertTrue(source.contains("shortTitle: \"Set title\""))
    }
}
