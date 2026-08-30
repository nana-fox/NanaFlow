import Foundation
import WidgetKit

@MainActor
protocol SessionHistoryPersisting {
    func load() -> [FocusSession]
    func save(_ sessions: [FocusSession]) throws
}

struct SessionHistoryPersistence: SessionHistoryPersisting {
    static let storageKey = "focusSessions.v1"

    private let defaults: UserDefaults
    private let sharedDefaults: UserDefaults?

    init(defaults: UserDefaults = .standard, sharedDefaults: UserDefaults? = nil) {
        self.defaults = defaults
        self.sharedDefaults = sharedDefaults
    }

    func load() -> [FocusSession] {
        guard let data = defaults.data(forKey: Self.storageKey) else { return [] }
        return (try? JSONDecoder().decode([FocusSession].self, from: data)) ?? []
    }

    func save(_ sessions: [FocusSession]) throws {
        let data = try JSONEncoder().encode(sessions)
        defaults.set(data, forKey: Self.storageKey)
        sharedDefaults?.set(data, forKey: Self.storageKey)
        if sharedDefaults != nil {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    static func merge(local: [FocusSession], incoming: [FocusSession]) -> [FocusSession] {
        var sessionsByID = Dictionary(uniqueKeysWithValues: local.map { ($0.id, $0) })
        incoming.forEach { sessionsByID[$0.id] = $0 }
        return sessionsByID.values.sorted { $0.endedAt > $1.endedAt }
    }
}

enum StatisticsPeriod: String, CaseIterable, Identifiable, Sendable {
    case day
    case week
    case month
    case year

    var id: Self { self }
}

enum StatisticsMetric: CaseIterable, Identifiable, Sendable {
    case count
    case duration

    var id: Self { self }
    var title: String {
        self == .count
            ? String(localized: "总计次数")
            : String(localized: "总用时")
    }
}

var flowStatisticsCalendar: Calendar {
    var calendar = Calendar.autoupdatingCurrent
    calendar.firstWeekday = 2
    calendar.minimumDaysInFirstWeek = 4
    return calendar
}

func statisticsPeriodTitle(
    _ period: StatisticsPeriod,
    anchor: Date,
    calendar: Calendar = flowStatisticsCalendar,
    locale: Locale = .autoupdatingCurrent
) -> String {
    let formatter = DateFormatter()
    formatter.locale = locale
    formatter.calendar = calendar

    switch period {
    case .day:
        formatter.setLocalizedDateFormatFromTemplate("yMd")
        return formatter.string(from: anchor)
    case .week:
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: anchor),
              let lastDay = calendar.date(byAdding: .day, value: -1, to: interval.end) else {
            return formatter.string(from: anchor)
        }
        formatter.setLocalizedDateFormatFromTemplate("yMd")
        return "\(formatter.string(from: interval.start)) – \(formatter.string(from: lastDay))"
    case .month:
        formatter.setLocalizedDateFormatFromTemplate("yMMMM")
        return formatter.string(from: anchor)
    case .year:
        formatter.setLocalizedDateFormatFromTemplate("y")
        return formatter.string(from: anchor)
    }
}

func statisticsChangePercentage(
    sessions: [FocusSession],
    period: StatisticsPeriod,
    anchor: Date,
    metric: StatisticsMetric,
    calendar: Calendar = flowStatisticsCalendar
) -> Int? {
    let component: Calendar.Component = switch period {
    case .day: .day
    case .week: .weekOfYear
    case .month: .month
    case .year: .year
    }
    guard let previousAnchor = calendar.date(byAdding: component, value: -1, to: anchor) else { return nil }
    let current = SessionStatistics(sessions: sessions, period: period, anchor: anchor, calendar: calendar)
    let previous = SessionStatistics(sessions: sessions, period: period, anchor: previousAnchor, calendar: calendar)
    let currentValue = metric == .count ? Double(current.totalCount) : current.totalDuration
    let previousValue = metric == .count ? Double(previous.totalCount) : previous.totalDuration

    guard previousValue > 0 else { return currentValue > 0 ? 100 : nil }
    return Int((((currentValue - previousValue) / previousValue) * 100).rounded())
}

struct StatisticsBucket: Identifiable, Equatable, Sendable {
    let start: Date
    let end: Date
    let sessionCount: Int
    let duration: TimeInterval
    let tagSegments: [StatisticsTagSegment]

    var id: Date { start }
}

struct StatisticsTagSegment: Identifiable, Equatable, Sendable {
    let tag: String?
    let sessionCount: Int
    let duration: TimeInterval

    var id: String { tag ?? "" }
}

struct TagSummary: Identifiable, Equatable, Sendable {
    let name: String
    let sessionCount: Int
    let duration: TimeInterval

    var id: String { name }
}

struct SessionStatistics: Equatable, Sendable {
    let totalCount: Int
    let totalDuration: TimeInterval
    let buckets: [StatisticsBucket]
    let tagSummaries: [TagSummary]

    init(
        sessions: [FocusSession],
        period: StatisticsPeriod,
        anchor: Date,
        tag: String? = nil,
        calendar: Calendar = .current
    ) {
        let interval = Self.interval(for: period, anchor: anchor, calendar: calendar)
        let matching = sessions.filter {
            $0.type == .focus
                && $0.completed
                && interval.contains($0.endedAt)
                && (tag == nil || $0.tag == tag)
        }
        totalCount = matching.count
        totalDuration = matching.reduce(0) { $0 + $1.duration }
        buckets = Self.bucketIntervals(for: period, in: interval, calendar: calendar).map { bucket in
            let sessionsInBucket = matching.filter { bucket.contains($0.endedAt) }
            let segments = Dictionary(grouping: sessionsInBucket, by: \.tag).map { tag, sessions in
                StatisticsTagSegment(
                    tag: tag,
                    sessionCount: sessions.count,
                    duration: sessions.reduce(0) { $0 + $1.duration }
                )
            }
            .sorted { ($0.tag ?? "\u{10FFFF}") < ($1.tag ?? "\u{10FFFF}") }
            return StatisticsBucket(
                start: bucket.start,
                end: bucket.end,
                sessionCount: sessionsInBucket.count,
                duration: sessionsInBucket.reduce(0) { $0 + $1.duration },
                tagSegments: segments.isEmpty
                    ? [StatisticsTagSegment(tag: nil, sessionCount: 0, duration: 0)]
                    : segments
            )
        }
        tagSummaries = Dictionary(grouping: matching.compactMap { session in
            session.tag.map { ($0, session) }
        }, by: { $0.0 })
        .map { name, entries in
            TagSummary(
                name: name,
                sessionCount: entries.count,
                duration: entries.reduce(0) { $0 + $1.1.duration }
            )
        }
        .sorted { lhs, rhs in
            lhs.duration == rhs.duration ? lhs.name < rhs.name : lhs.duration > rhs.duration
        }
    }

    private static func interval(
        for period: StatisticsPeriod,
        anchor: Date,
        calendar: Calendar
    ) -> DateInterval {
        let component: Calendar.Component = switch period {
        case .day: .day
        case .week: .weekOfYear
        case .month: .month
        case .year: .year
        }
        return calendar.dateInterval(of: component, for: anchor)
            ?? DateInterval(start: anchor, duration: 1)
    }

    private static func bucketIntervals(
        for period: StatisticsPeriod,
        in interval: DateInterval,
        calendar: Calendar
    ) -> [DateInterval] {
        let component: Calendar.Component = switch period {
        case .day: .hour
        case .week, .month: .day
        case .year: .month
        }

        var result: [DateInterval] = []
        var cursor = interval.start
        while cursor < interval.end,
              let next = calendar.date(byAdding: component, value: 1, to: cursor) {
            result.append(DateInterval(start: cursor, end: min(next, interval.end)))
            cursor = next
        }
        return result
    }
}
