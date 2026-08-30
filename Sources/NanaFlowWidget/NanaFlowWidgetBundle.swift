import SwiftUI
import WidgetKit

@main
struct NanaFlowWidgetBundle: WidgetBundle {
    var body: some Widget {
        DailyStatisticsWidget()
        DailyQuoteWidget()
        IconWidget()
        if #available(macOS 26.0, *) {
            IconControlWidget()
        }
    }
}
