import Foundation

@MainActor
protocol TimerPersisting {
    func load() -> TimerEngine?
    func save(_ engine: TimerEngine) throws
}

struct TimerPersistence: TimerPersisting {
    static let storageKey = "timerEngine.v1"

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> TimerEngine? {
        guard let data = defaults.data(forKey: Self.storageKey) else { return nil }
        return try? decoder.decode(TimerEngine.self, from: data)
    }

    func save(_ engine: TimerEngine) throws {
        defaults.set(try encoder.encode(engine), forKey: Self.storageKey)
    }
}
