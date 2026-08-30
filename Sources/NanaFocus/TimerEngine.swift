import Foundation

enum SessionPhase: String, Codable, Equatable, Sendable {
    case focus
    case shortBreak
    case longBreak
}

struct TimerConfiguration: Codable, Equatable, Sendable {
    static let standard = TimerConfiguration(
        focusDuration: 25 * 60,
        shortBreakDuration: 5 * 60,
        longBreakDuration: 30 * 60,
        sessionsPerCycle: 4
    )

    let focusDuration: TimeInterval
    let shortBreakDuration: TimeInterval
    let longBreakDuration: TimeInterval
    let sessionsPerCycle: Int

    init(
        focusDuration: TimeInterval,
        shortBreakDuration: TimeInterval,
        longBreakDuration: TimeInterval,
        sessionsPerCycle: Int
    ) {
        self.focusDuration = max(1, focusDuration)
        self.shortBreakDuration = max(1, shortBreakDuration)
        self.longBreakDuration = max(1, longBreakDuration)
        self.sessionsPerCycle = max(1, sessionsPerCycle)
    }

    func duration(for phase: SessionPhase) -> TimeInterval {
        switch phase {
        case .focus: focusDuration
        case .shortBreak: shortBreakDuration
        case .longBreak: longBreakDuration
        }
    }
}

struct TimerState: Codable, Equatable, Sendable {
    var phase: SessionPhase
    var cycleIndex: Int
    var remainingWhenPaused: TimeInterval
    var endDate: Date?
    var startedAt: Date?
    var interruptions: [SessionInterruption]

    var isRunning: Bool { endDate != nil }

    init(
        phase: SessionPhase,
        cycleIndex: Int,
        remainingWhenPaused: TimeInterval,
        endDate: Date?,
        startedAt: Date?,
        interruptions: [SessionInterruption] = []
    ) {
        self.phase = phase
        self.cycleIndex = cycleIndex
        self.remainingWhenPaused = remainingWhenPaused
        self.endDate = endDate
        self.startedAt = startedAt
        self.interruptions = interruptions
    }

    private enum CodingKeys: String, CodingKey {
        case phase
        case cycleIndex
        case remainingWhenPaused
        case endDate
        case startedAt
        case interruptions
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        phase = try values.decode(SessionPhase.self, forKey: .phase)
        cycleIndex = try values.decode(Int.self, forKey: .cycleIndex)
        remainingWhenPaused = try values.decode(TimeInterval.self, forKey: .remainingWhenPaused)
        endDate = try values.decodeIfPresent(Date.self, forKey: .endDate)
        startedAt = try values.decodeIfPresent(Date.self, forKey: .startedAt)
        interruptions = try values.decodeIfPresent([SessionInterruption].self, forKey: .interruptions) ?? []
    }
}

struct TimerEngine: Codable, Equatable, Sendable {
    private(set) var configuration: TimerConfiguration
    private(set) var state: TimerState

    init(configuration: TimerConfiguration, state: TimerState? = nil) {
        self.configuration = configuration
        self.state = state ?? TimerState(
            phase: .focus,
            cycleIndex: 0,
            remainingWhenPaused: configuration.focusDuration,
            endDate: nil,
            startedAt: nil
        )
    }

    func remaining(at date: Date) -> TimeInterval {
        guard let endDate = state.endDate else {
            return max(0, state.remainingWhenPaused)
        }
        return max(0, endDate.timeIntervalSince(date))
    }

    mutating func start(at date: Date) {
        guard !state.isRunning else { return }
        if state.remainingWhenPaused <= 0 {
            advance()
        }
        if state.startedAt == nil {
            state.startedAt = date
        } else if let index = state.interruptions.indices.last,
                  state.interruptions[index].resumedAt == nil {
            state.interruptions[index].resumedAt = date
        }
        state.endDate = date.addingTimeInterval(state.remainingWhenPaused)
    }

    mutating func pause(at date: Date) {
        guard state.isRunning else { return }
        state.remainingWhenPaused = remaining(at: date)
        state.endDate = nil
        state.interruptions.append(SessionInterruption(stoppedAt: date, resumedAt: nil))
    }

    mutating func skip(at _: Date) {
        advance()
    }

    mutating func reset(at _: Date) {
        state.remainingWhenPaused = configuration.duration(for: state.phase)
        state.endDate = nil
        state.startedAt = nil
        state.interruptions = []
    }

    mutating func previous(at date: Date) {
        if state.startedAt == nil {
            switch state.phase {
            case .focus where state.cycleIndex > 0:
                state.phase = .shortBreak
                state.cycleIndex -= 1
            case .shortBreak, .longBreak:
                state.phase = .focus
            case .focus:
                break
            }
        }
        reset(at: date)
    }

    mutating func resetCycle(at _: Date) {
        state = TimerState(
            phase: .focus,
            cycleIndex: 0,
            remainingWhenPaused: configuration.focusDuration,
            endDate: nil,
            startedAt: nil
        )
    }

    mutating func updateConfiguration(_ configuration: TimerConfiguration, at _: Date) {
        self.configuration = configuration
        state.cycleIndex = min(state.cycleIndex, configuration.sessionsPerCycle - 1)
        guard !state.isRunning else { return }
        state.remainingWhenPaused = configuration.duration(for: state.phase)
    }

    @discardableResult
    mutating func reconcile(at date: Date) -> Bool {
        guard let endDate = state.endDate, endDate <= date else { return false }
        advance()
        return true
    }

    private mutating func advance() {
        switch state.phase {
        case .focus where state.cycleIndex == configuration.sessionsPerCycle - 1:
            state.phase = .longBreak
        case .focus:
            state.phase = .shortBreak
        case .shortBreak:
            state.phase = .focus
            state.cycleIndex += 1
        case .longBreak:
            state.phase = .focus
            state.cycleIndex = 0
        }

        state.remainingWhenPaused = configuration.duration(for: state.phase)
        state.endDate = nil
        state.startedAt = nil
        state.interruptions = []
    }
}
