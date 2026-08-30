import Foundation
import WidgetKit

struct NanaFlowWidgetEntry: TimelineEntry {
    let date: Date
    let completedCount: Int
    let minutes: Int
    let colorStyle: WidgetColorStyle
    let statisticsUnit: WidgetStatisticsUnit

    init(
        date: Date,
        completedCount: Int,
        minutes: Int,
        colorStyle: WidgetColorStyle = .style1,
        statisticsUnit: WidgetStatisticsUnit = .count
    ) {
        self.date = date
        self.completedCount = completedCount
        self.minutes = minutes
        self.colorStyle = colorStyle
        self.statisticsUnit = statisticsUnit
    }
}

struct NanaFlowWidgetProvider: TimelineProvider {
    func placeholder(in _: Context) -> NanaFlowWidgetEntry {
        NanaFlowWidgetEntry(date: Date(), completedCount: 4, minutes: 100)
    }

    func getSnapshot(in _: Context, completion: @escaping (NanaFlowWidgetEntry) -> Void) {
        completion(Self.entry(at: Date()))
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<NanaFlowWidgetEntry>) -> Void) {
        let now = Date()
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: now) ?? now.addingTimeInterval(900)
        completion(Timeline(entries: [Self.entry(at: now)], policy: .after(next)))
    }

    static func entry(
        at date: Date,
        colorStyle: WidgetColorStyle = .style1,
        statisticsUnit: WidgetStatisticsUnit = .count
    ) -> NanaFlowWidgetEntry {
        let sessions: [FocusSession]
        if let data = NanaFlowShared.defaults?.data(forKey: "focusSessions.v1") {
            sessions = (try? JSONDecoder().decode([FocusSession].self, from: data)) ?? []
        } else {
            sessions = []
        }
        let today = sessions.filter {
            $0.type == .focus
                && $0.completed
                && Calendar.current.isDate($0.endedAt, inSameDayAs: date)
        }
        return NanaFlowWidgetEntry(
            date: date,
            completedCount: today.count,
            minutes: Int(today.reduce(0) { $0 + $1.duration } / 60),
            colorStyle: colorStyle,
            statisticsUnit: statisticsUnit
        )
    }
}
