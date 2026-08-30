import XCTest
@testable import NanaFlow

@MainActor
final class TimerPersistenceTests: XCTestCase {
    func testRoundTripsTimerState() throws {
        let suiteName = "TimerPersistenceTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let persistence = TimerPersistence(defaults: defaults)
        var engine = TimerEngine(configuration: .standard)
        let now = Date(timeIntervalSince1970: 10_000)
        engine.start(at: now)

        try persistence.save(engine)
        let restored = try XCTUnwrap(persistence.load())

        XCTAssertEqual(restored, engine)
        XCTAssertEqual(restored.remaining(at: now.addingTimeInterval(60)), 24 * 60)
    }

    func testRoundTripsPausedInterruptionState() throws {
        let suiteName = "TimerInterruptionPersistenceTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let persistence = TimerPersistence(defaults: defaults)
        var engine = TimerEngine(configuration: .standard)
        let now = Date(timeIntervalSince1970: 10_000)
        engine.start(at: now)
        engine.pause(at: now.addingTimeInterval(30))

        try persistence.save(engine)
        let restored = try XCTUnwrap(persistence.load())

        XCTAssertEqual(restored.state.interruptions, [
            SessionInterruption(stoppedAt: now.addingTimeInterval(30), resumedAt: nil)
        ])
    }

    func testLegacyTimerStateWithoutInterruptionsStillDecodes() throws {
        var engine = TimerEngine(configuration: .standard)
        let now = Date(timeIntervalSince1970: 10_000)
        engine.start(at: now)
        let encoded = try JSONEncoder().encode(engine)
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        var state = try XCTUnwrap(object["state"] as? [String: Any])
        state.removeValue(forKey: "interruptions")
        object["state"] = state

        let legacyData = try JSONSerialization.data(withJSONObject: object)
        let restored = try JSONDecoder().decode(TimerEngine.self, from: legacyData)

        XCTAssertEqual(restored.state.interruptions, [])
        XCTAssertEqual(restored.state.startedAt, now)
    }

    func testCorruptStateIsIgnoredWithoutDeletingOtherDefaults() throws {
        let suiteName = "TimerPersistenceTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(Data("not-json".utf8), forKey: TimerPersistence.storageKey)
        defaults.set("keep", forKey: "unrelated")
        let persistence = TimerPersistence(defaults: defaults)

        XCTAssertNil(persistence.load())
        XCTAssertEqual(defaults.string(forKey: "unrelated"), "keep")
    }
}
