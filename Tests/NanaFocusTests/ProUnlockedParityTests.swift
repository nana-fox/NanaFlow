import SwiftUI
import XCTest
@testable import NanaFlow

@MainActor
final class ProUnlockedParityTests: XCTestCase {
    func testProWindowKeepsFlowGeometryWithoutReintroducingAPaywall() {
        XCTAssertEqual(ProWindowMetrics.width, 650)
        XCTAssertEqual(ProWindowMetrics.height, 552)
        XCTAssertEqual(ProWindowMetrics.windowContentHeight, 520)
        XCTAssertEqual(ProWindowMetrics.leftPaneWidth, 315)
        XCTAssertEqual(ProWindowMetrics.featureMinimumScaleFactor, 0.88, accuracy: 0.001)
        XCTAssertEqual(ProWindowMetrics.featureLineLimit, 2)
        XCTAssertTrue(ProWindowMetrics.usesFullSizeContent)
        XCTAssertTrue(ProWindowMetrics.usesFixedWindowFrame)
        XCTAssertEqual(ProUnlockedContract.menuTitle, "升级")
        XCTAssertEqual(ProUnlockedContract.headline, "NanaFlow Pro 已解锁")
        XCTAssertEqual(ProUnlockedContract.features, [
            "解锁所有功能",
            "自定义会话标题和持续时间",
            "网页阻止和日历同步",
            "跨设备计时器同步",
        ])
        XCTAssertFalse(ProUnlockedContract.requiresPurchase)
    }

    func testProUnlockedViewRenders() {
        let renderer = ImageRenderer(content: ProUnlockedView(onDone: {}))
        renderer.proposedSize = ProposedViewSize(
            width: ProWindowMetrics.width,
            height: ProWindowMetrics.height
        )

        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            return XCTFail("Unable to render NanaFlow Pro unlocked window")
        }
        XCTAssertEqual(image.size.width, ProWindowMetrics.width)
        XCTAssertEqual(image.size.height, ProWindowMetrics.height)
        let attachment = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
        attachment.name = "nanaflow-pro-unlocked"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testNativeProWindowMatchesFlowOuterFrame() {
        let controller = ProUnlockedWindowController.shared
        controller.window?.animationBehavior = .none
        controller.show()
        RunLoop.main.run(until: Date().addingTimeInterval(0.25))
        defer { controller.close() }

        guard let window = controller.window else {
            return XCTFail("NanaFlow Pro window is missing")
        }
        XCTAssertEqual(window.frame.width, ProWindowMetrics.width)
        XCTAssertEqual(window.frame.height, ProWindowMetrics.height)
        XCTAssertTrue(window.styleMask.contains(.fullSizeContentView))
        XCTAssertFalse(window.styleMask.contains(.resizable))
        XCTAssertEqual(window.titleVisibility, .hidden)
        XCTAssertEqual(window.titlebarAppearsTransparent, true)
        XCTAssertEqual(window.standardWindowButton(.zoomButton)?.isEnabled, false)
    }
}
