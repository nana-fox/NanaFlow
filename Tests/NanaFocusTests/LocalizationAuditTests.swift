import Foundation
import XCTest
@testable import NanaFlow

final class LocalizationAuditTests: XCTestCase {
    func testDurationControlUsesEnglishPluralRulesAndAbbreviatedMinutes() throws {
        let app = Bundle(for: TimerController.self)
        let url = try XCTUnwrap(app.url(forResource: "en", withExtension: "lproj"))
        let english = try XCTUnwrap(Bundle(url: url))
        XCTAssertEqual(customDurationValue(1, unit: "轮", bundle: english), "1 round")
        XCTAssertEqual(customDurationValue(4, unit: "轮", bundle: english), "4 rounds")
        XCTAssertEqual(customDurationValue(25, unit: "duration_minutes_unit", bundle: english), "25 min")
    }

    func testEverySourceLocalizationKeyHasEnglishTranslation() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["python3", root.appendingPathComponent("script/check_localization.py").path]
        process.currentDirectoryURL = root
        let output = Pipe()
        process.standardOutput = output
        process.standardError = output
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0, String(decoding: data, as: UTF8.self))
    }
}
