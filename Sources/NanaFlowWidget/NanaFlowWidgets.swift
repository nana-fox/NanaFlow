import AppIntents
import SwiftUI
import WidgetKit

enum WidgetStatisticsUnit: String, AppEnum {
    case count
    case minutes

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "统计单位")
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .count: "数量",
        .minutes: "分钟"
    ]
}

enum WidgetColorStyle: String, AppEnum {
    case style1
    case style2
    case style3
    case style4

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "组件颜色")
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .style1: "风格 1",
        .style2: "风格 2",
        .style3: "风格 3",
        .style4: "风格 4"
    ]

    var accent: Color {
        switch self {
        case .style1: Color(red: 0.149, green: 0.471, blue: 0.400)
        case .style2: Color(red: 0.361, green: 0.549, blue: 0.753)
        case .style3: Color(red: 0.655, green: 0.561, blue: 0.749)
        case .style4: Color(red: 0.851, green: 0.431, blue: 0.357)
        }
    }

    var background: Color {
        accent
    }
}

struct DailyStatisticsWidgetIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "每日统计组件"
    static let description = IntentDescription("显示今天完成的 NanaFlow 数量或专注分钟数。")

    @Parameter(title: "颜色", default: .style1)
    var color: WidgetColorStyle

    @Parameter(title: "单位", default: .count)
    var unit: WidgetStatisticsUnit
}

struct DailyQuoteWidgetIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "每日引语组件"
    static let description = IntentDescription("显示每日励志引语。")

    @Parameter(title: "颜色", default: .style1)
    var color: WidgetColorStyle
}

struct DailyStatisticsWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in _: Context) -> NanaFlowWidgetEntry {
        NanaFlowWidgetEntry(date: Date(), completedCount: 4, minutes: 100)
    }

    func snapshot(for configuration: DailyStatisticsWidgetIntent, in _: Context) async -> NanaFlowWidgetEntry {
        NanaFlowWidgetProvider.entry(at: Date(), colorStyle: configuration.color, statisticsUnit: configuration.unit)
    }

    func timeline(for configuration: DailyStatisticsWidgetIntent, in _: Context) async -> Timeline<NanaFlowWidgetEntry> {
        let now = Date()
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: now) ?? now.addingTimeInterval(900)
        return Timeline(
            entries: [NanaFlowWidgetProvider.entry(
                at: now,
                colorStyle: configuration.color,
                statisticsUnit: configuration.unit
            )],
            policy: .after(next)
        )
    }
}

struct DailyQuoteWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in _: Context) -> NanaFlowWidgetEntry {
        NanaFlowWidgetEntry(date: Date(), completedCount: 4, minutes: 100)
    }

    func snapshot(for configuration: DailyQuoteWidgetIntent, in _: Context) async -> NanaFlowWidgetEntry {
        NanaFlowWidgetProvider.entry(at: Date(), colorStyle: configuration.color)
    }

    func timeline(for configuration: DailyQuoteWidgetIntent, in _: Context) async -> Timeline<NanaFlowWidgetEntry> {
        let now = Date()
        let tomorrow = Calendar.current.startOfDay(for: now).addingTimeInterval(86_400)
        return Timeline(
            entries: [NanaFlowWidgetProvider.entry(at: now, colorStyle: configuration.color)],
            policy: .after(tomorrow)
        )
    }
}

struct DailyStatisticsWidget: Widget {
    let kind = "NanaFlowDailyStatistics"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: DailyStatisticsWidgetIntent.self, provider: DailyStatisticsWidgetProvider()) { entry in
            DailyStatisticsWidgetView(entry: entry)
        }
        .configurationDisplayName("每日统计")
        .description("显示您的每日统计数据。")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

private struct DailyStatisticsWidgetView: View {
    let entry: NanaFlowWidgetEntry

    var body: some View {
        NanaFlowStatisticsWidgetContent(
            value: entry.statisticsUnit == .count ? entry.completedCount : entry.minutes,
            unit: entry.statisticsUnit == .count ? "NanaFlows" : String(localized: "分钟"),
            background: entry.colorStyle.background
        )
        .containerBackground(entry.colorStyle.background, for: .widget)
    }
}

struct DailyQuoteWidget: Widget {
    let kind = "NanaFlowDailyQuote"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: DailyQuoteWidgetIntent.self, provider: DailyQuoteWidgetProvider()) { entry in
            DailyQuoteWidgetView(date: entry.date, colorStyle: entry.colorStyle)
        }
        .configurationDisplayName("每日励志")
        .description("以励志名言开始新的一天。")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
        .contentMarginsDisabled()
    }
}

private struct DailyQuoteWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let date: Date
    let colorStyle: WidgetColorStyle

    var body: some View {
        NanaFlowQuoteWidgetContent(
            quote: WidgetVisualMetrics.quote(for: date),
            family: nanaFamily,
            background: colorStyle.background
        )
        .containerBackground(colorStyle.background, for: .widget)
    }

    private var nanaFamily: NanaFlowWidgetFamily {
        switch family {
        case .systemSmall: .small
        case .systemMedium: .medium
        case .systemLarge: .large
        default: .extraLarge
        }
    }
}

struct IconWidget: Widget {
    let kind = "NanaFlowIcon"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NanaFlowWidgetProvider()) { _ in
            Link(destination: URL(string: "nanaflow://show")!) {
                VStack(spacing: 12) {
                    Image("NanaFlowWidgetIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    Text("打开 NanaFlow")
                        .font(.caption.weight(.semibold))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("NanaFlow 快捷方式")
        .description("快速打开 NanaFlow。")
        .supportedFamilies([.systemSmall])
    }
}

@available(macOS 26.0, *)
struct IconControlWidget: ControlWidget {
    static let kind = "NanaFlowIconControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: OpenAppIntent()) {
                Label("NanaFlow", systemImage: "timer")
            }
        }
        .displayName("NanaFlow")
        .description("打开 NanaFlow 计时器。")
    }
}
