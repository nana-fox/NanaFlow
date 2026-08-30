import AppKit
import SwiftUI
import XCTest
@testable import NanaFlow

@MainActor
final class WidgetParityTests: XCTestCase {
    func testWidgetBundleShipsEnglishConfigurationStrings() throws {
        let appBundle = Bundle(for: TimerController.self)
        let widgetURL = try XCTUnwrap(
            appBundle.builtInPlugInsURL?.appendingPathComponent("NanaFlowWidget.appex")
        )
        let widgetBundle = try XCTUnwrap(Bundle(url: widgetURL))
        let englishURL = try XCTUnwrap(widgetBundle.url(forResource: "en", withExtension: "lproj"))
        let englishBundle = try XCTUnwrap(Bundle(url: englishURL))
        let expected = [
            "统计单位": "Statistics Unit",
            "数量": "Count",
            "分钟": "Minutes",
            "组件颜色": "Widget Color",
            "每日统计组件": "Daily Statistics Widget",
            "显示今天完成的 NanaFlow 数量或专注分钟数。": "Show today's completed NanaFlows or focused minutes.",
            "每日引语组件": "Daily Quote Widget",
            "显示每日励志引语。": "Show a daily motivational quote.",
            "每日统计": "Daily Statistics",
            "显示您的每日统计数据。": "Shows your total completed NanaFlows for the day.",
            "每日励志": "Daily Motivation",
            "以励志名言开始新的一天。": "Get daily motivational quotes.",
            "打开 NanaFlow": "Open NanaFlow",
            "NanaFlow 快捷方式": "NanaFlow Shortcut",
            "快速打开 NanaFlow。": "A quick way to open NanaFlow.",
        ]

        for (key, value) in expected {
            XCTAssertEqual(
                englishBundle.localizedString(forKey: key, value: nil, table: "Localizable"),
                value,
                key
            )
        }
    }

    func testWidgetBundleIncludesControlCenterLauncher() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let bundleSource = try String(
            contentsOf: repositoryRoot
                .appendingPathComponent("Sources/NanaFlowWidget/NanaFlowWidgetBundle.swift"),
            encoding: .utf8
        )
        let widgetSource = try String(
            contentsOf: repositoryRoot
                .appendingPathComponent("Sources/NanaFlowWidget/NanaFlowWidgets.swift"),
            encoding: .utf8
        )
        let sharedSource = try String(
            contentsOf: repositoryRoot
                .appendingPathComponent("Sources/NanaShared/NanaFlowShared.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(bundleSource.contains("IconControlWidget()"))
        XCTAssertTrue(widgetSource.contains("显示您的每日统计数据。"))
        XCTAssertTrue(widgetSource.contains("以励志名言开始新的一天。"))
        XCTAssertTrue(widgetSource.contains(".systemLarge, .systemExtraLarge"))
        XCTAssertFalse(widgetSource.contains("accent.opacity(0.14)"))
        XCTAssertFalse(widgetSource.contains("Label(\"今天专注\""))
        XCTAssertFalse(sharedSource.contains("Spacer(minLength: 0)"))
    }

    func testWidgetVisualContractMatchesFlow() {
        XCTAssertEqual(WidgetVisualMetrics.backgroundRed, 38.0 / 255.0, accuracy: 0.0001)
        XCTAssertEqual(WidgetVisualMetrics.backgroundGreen, 120.0 / 255.0, accuracy: 0.0001)
        XCTAssertEqual(WidgetVisualMetrics.backgroundBlue, 102.0 / 255.0, accuracy: 0.0001)
        XCTAssertEqual(WidgetVisualMetrics.foregroundRed, 233.0 / 255.0, accuracy: 0.0001)
        XCTAssertEqual(WidgetVisualMetrics.foregroundGreen, 242.0 / 255.0, accuracy: 0.0001)
        XCTAssertEqual(WidgetVisualMetrics.foregroundBlue, 240.0 / 255.0, accuracy: 0.0001)
        XCTAssertEqual(WidgetVisualMetrics.smallSize, CGSize(width: 158, height: 158))
        XCTAssertEqual(WidgetVisualMetrics.mediumSize, CGSize(width: 338, height: 158))
        XCTAssertEqual(WidgetVisualMetrics.largeSize, CGSize(width: 338, height: 338))
        XCTAssertEqual(WidgetVisualMetrics.extraLargeSize, CGSize(width: 720, height: 338))
        XCTAssertEqual(WidgetVisualMetrics.quoteFontSize(for: .small), 14)
        XCTAssertEqual(WidgetVisualMetrics.quoteFontSize(for: .medium), 24)
        XCTAssertEqual(WidgetVisualMetrics.quoteFontSize(for: .large), 34)
        XCTAssertEqual(WidgetVisualMetrics.quoteFontSize(for: .extraLarge), 42)
        XCTAssertEqual(WidgetVisualMetrics.quotes.count, 521)
        XCTAssertEqual(Set(WidgetVisualMetrics.quotes.map(\.text)).count, 521)
        XCTAssertEqual(MotivationalQuotes.values.count, 521)
        XCTAssertEqual(WidgetVisualMetrics.quotes.first?.author, "Henry David Thoreau")

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = Date(timeIntervalSince1970: 0)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: start)!
        let nextCycle = calendar.date(byAdding: .day, value: 521, to: start)!
        XCTAssertNotEqual(
            WidgetVisualMetrics.quote(for: start, calendar: calendar),
            WidgetVisualMetrics.quote(for: nextDay, calendar: calendar)
        )
        XCTAssertEqual(
            WidgetVisualMetrics.quote(for: start, calendar: calendar),
            WidgetVisualMetrics.quote(for: nextCycle, calendar: calendar)
        )
    }

    func testFlowWidgetViewsRender() {
        let statistics = ImageRenderer(content: NanaFlowStatisticsWidgetContent(value: 0, unit: "Flows")
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous)))
        statistics.proposedSize = ProposedViewSize(WidgetVisualMetrics.smallSize)

        let quote = ImageRenderer(content: NanaFlowQuoteWidgetContent(
            quote: WidgetVisualMetrics.quotes[1],
            family: .medium
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous)))
        quote.proposedSize = ProposedViewSize(WidgetVisualMetrics.mediumSize)

        XCTAssertNotNil(statistics.nsImage)
        XCTAssertNotNil(quote.nsImage)
        if let statisticsImage = statistics.nsImage {
            attach(statisticsImage, name: "nanaflow-widget-statistics-small")
        }
        if let quoteImage = quote.nsImage {
            attach(quoteImage, name: "nanaflow-widget-quote-medium")
        }

        renderQuote(family: .small, index: 0, size: WidgetVisualMetrics.smallSize)
        renderQuote(family: .large, index: 2, size: WidgetVisualMetrics.largeSize)
        renderQuote(family: .extraLarge, index: 3, size: WidgetVisualMetrics.extraLargeSize)
        renderQuote(family: .small, index: 520, size: WidgetVisualMetrics.smallSize)
    }

    private func renderQuote(family: NanaFlowWidgetFamily, index: Int, size: CGSize) {
        let renderer = ImageRenderer(content: NanaFlowQuoteWidgetContent(
            quote: WidgetVisualMetrics.quotes[index],
            family: family
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous)))
        renderer.proposedSize = ProposedViewSize(size)
        guard let image = renderer.nsImage else {
            XCTFail("Unable to render \(family)")
            return
        }
        attach(image, name: "nanaflow-widget-quote-\(family)-\(index)")
    }

    private func attach(_ image: NSImage, name: String) {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            XCTFail("Unable to encode \(name) as PNG")
            return
        }

        let attachment = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
