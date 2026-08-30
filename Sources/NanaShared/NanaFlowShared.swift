import AppIntents
import Foundation
import SwiftUI

struct WidgetQuote: Equatable, Sendable {
    let text: String
    let author: String
}

enum NanaFlowWidgetFamily: Sendable {
    case small
    case medium
    case large
    case extraLarge
}

enum WidgetVisualMetrics {
    static let backgroundRed = 38.0 / 255.0
    static let backgroundGreen = 120.0 / 255.0
    static let backgroundBlue = 102.0 / 255.0
    static let foregroundRed = 233.0 / 255.0
    static let foregroundGreen = 242.0 / 255.0
    static let foregroundBlue = 240.0 / 255.0
    static let smallSize = CGSize(width: 158, height: 158)
    static let mediumSize = CGSize(width: 338, height: 158)
    static let largeSize = CGSize(width: 338, height: 338)
    static let extraLargeSize = CGSize(width: 720, height: 338)
    private static let showcaseQuotes = [
        WidgetQuote(
            text: "It's not what you look at that matters, it's what you see.",
            author: "Henry David Thoreau"
        ),
        WidgetQuote(
            text: "The price of greatness is responsibility.",
            author: "Winston Churchill"
        ),
        WidgetQuote(
            text: "Success without fulfillment is the ultimate failure.",
            author: "Tony Robbins"
        ),
        WidgetQuote(
            text: "Compassion and happiness are not a sign of weakness but a sign of strength.",
            author: "Dalai Lama"
        )
    ]

    private static let quoteSubjects = [
        "A clear intention", "Steady attention", "Quiet persistence", "A patient rhythm",
        "Focused effort", "A thoughtful pause", "One honest step", "A calm beginning",
        "Consistent practice", "A simple plan", "Careful work", "A rested mind",
        "A deliberate choice", "Gentle discipline", "A useful question", "A small commitment",
        "A clear boundary", "A fresh perspective", "A measured pace", "A curious mind",
        "A finished task", "A quiet hour", "A meaningful goal"
    ]

    private static let quoteEndings = [
        "makes difficult work easier to begin.",
        "turns small steps into lasting progress.",
        "creates room for work that matters.",
        "keeps attention close to the next step.",
        "builds momentum without unnecessary pressure.",
        "gives good ideas time to become real.",
        "protects the energy needed to finish.",
        "makes complexity easier to understand.",
        "brings the important work into view.",
        "helps patience outlast distraction.",
        "leaves less room for avoidable noise.",
        "strengthens every return to the task.",
        "makes steady progress easier to notice.",
        "keeps effort aligned with purpose.",
        "turns today into a useful foundation.",
        "makes completion feel more reachable.",
        "helps the mind return without judgment.",
        "reveals what deserves attention next.",
        "keeps the work moving at a human pace.",
        "makes room for both depth and recovery.",
        "rewards consistency more than urgency.",
        "transforms practice into quiet confidence.",
        "moves intention closer to a finished result."
    ]

    static let quotes: [WidgetQuote] = {
        let generated = quoteSubjects.flatMap { subject in
            quoteEndings.map { ending in
                WidgetQuote(text: "\(subject) \(ending)", author: "NanaFlow")
            }
        }
        return showcaseQuotes + generated.prefix(521 - showcaseQuotes.count)
    }()

    static let backgroundColor = Color(
        red: backgroundRed,
        green: backgroundGreen,
        blue: backgroundBlue
    )
    static let foregroundColor = Color(
        red: foregroundRed,
        green: foregroundGreen,
        blue: foregroundBlue
    )

    static func quoteFontSize(for family: NanaFlowWidgetFamily) -> CGFloat {
        switch family {
        case .small: 14
        case .medium: 24
        case .large: 34
        case .extraLarge: 42
        }
    }

    static func quote(for date: Date, calendar: Calendar = .current) -> WidgetQuote {
        let epoch = calendar.startOfDay(for: Date(timeIntervalSince1970: 0))
        let day = calendar.dateComponents(
            [.day],
            from: epoch,
            to: calendar.startOfDay(for: date)
        ).day ?? 0
        let index = ((day % quotes.count) + quotes.count) % quotes.count
        return quotes[index]
    }
}

struct NanaFlowStatisticsWidgetContent: View {
    let value: Int
    let unit: String
    var background = WidgetVisualMetrics.backgroundColor

    var body: some View {
        VStack(spacing: 7) {
            Text("今天")
                .font(.system(size: 10, weight: .medium))
            Text("\(value)")
                .font(.system(size: 31, weight: .regular, design: .rounded))
            Text(unit)
                .font(.system(size: 9, weight: .regular))
        }
        .foregroundStyle(WidgetVisualMetrics.foregroundColor)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(background)
    }
}

struct NanaFlowQuoteWidgetContent: View {
    let quote: WidgetQuote
    let family: NanaFlowWidgetFamily
    var background = WidgetVisualMetrics.backgroundColor

    private var contentWidth: CGFloat? {
        switch family {
        case .large: 290
        default: nil
        }
    }

    private var padding: CGFloat {
        switch family {
        case .small: 16
        case .medium: 18
        case .large: 24
        case .extraLarge: 32
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: family == .small ? 6 : 10) {
            Image(systemName: "quote.opening")
                .font(.system(size: quoteMarkSize, weight: .bold))
                .foregroundStyle(WidgetVisualMetrics.foregroundColor.opacity(0.32))
            Text(quote.text)
                .font(.system(
                    size: WidgetVisualMetrics.quoteFontSize(for: family),
                    weight: .semibold,
                    design: .serif
                ))
                .lineSpacing(family == .small ? -1 : 0)
                .lineLimit(family == .small ? 5 : nil)
                .frame(maxWidth: contentWidth, alignment: .leading)
            Text(quote.author)
                .font(.system(size: authorFontSize, weight: .regular, design: .serif))
                .opacity(0.76)
        }
        .foregroundStyle(WidgetVisualMetrics.foregroundColor)
        .padding(padding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(background)
    }

    private var quoteMarkSize: CGFloat {
        switch family {
        case .small: 18
        case .medium: 22
        case .large: 30
        case .extraLarge: 34
        }
    }

    private var authorFontSize: CGFloat {
        switch family {
        case .small: 8
        case .medium: 11
        case .large: 12
        case .extraLarge: 16
        }
    }
}

enum NanaFlowShared {
    static let suiteName = "group.com.nanafox.NanaFlow"
    static var defaults: UserDefaults? { UserDefaults(suiteName: suiteName) }
}

struct OpenAppIntent: AppIntent {
    static let title: LocalizedStringResource = "打开 NanaFlow"
    static let description = IntentDescription("打开 NanaFlow 应用。")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        .result()
    }
}

enum RecordedSessionType: String, Codable, CaseIterable, Equatable, Sendable {
    case focus
    case shortBreak
    case longBreak
}

struct SessionInterruption: Codable, Equatable, Sendable {
    let stoppedAt: Date
    var resumedAt: Date?
}

struct FocusSession: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let startedAt: Date
    let endedAt: Date
    let duration: TimeInterval
    let completed: Bool
    var title: String
    var tag: String?
    let type: RecordedSessionType
    let interruptions: [SessionInterruption]

    var completedAt: Date? { completed ? endedAt : nil }

    var durationWithInterruptions: TimeInterval {
        max(duration, endedAt.timeIntervalSince(startedAt))
    }

    init(
        id: UUID,
        startedAt: Date,
        endedAt: Date,
        duration: TimeInterval,
        completed: Bool,
        title: String,
        tag: String? = nil,
        type: RecordedSessionType = .focus,
        interruptions: [SessionInterruption] = []
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.duration = duration
        self.completed = completed
        self.title = title
        self.tag = tag
        self.type = type
        self.interruptions = interruptions
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case startedAt
        case endedAt
        case duration
        case completed
        case title
        case tag
        case type
        case interruptions
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        startedAt = try values.decode(Date.self, forKey: .startedAt)
        endedAt = try values.decode(Date.self, forKey: .endedAt)
        duration = try values.decode(TimeInterval.self, forKey: .duration)
        completed = try values.decode(Bool.self, forKey: .completed)
        title = try values.decode(String.self, forKey: .title)
        tag = try values.decodeIfPresent(String.self, forKey: .tag)
        type = try values.decodeIfPresent(RecordedSessionType.self, forKey: .type) ?? .focus
        interruptions = try values.decodeIfPresent([SessionInterruption].self, forKey: .interruptions) ?? []
    }
}
