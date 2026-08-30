import SwiftUI
import XCTest
@testable import NanaFlow

@MainActor
final class PermissionParityTests: XCTestCase {
    func testReleaseEntitlementsCoverSandboxedSystemIntegrations() throws {
        let repositoryURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let entitlementURL = repositoryURL.appendingPathComponent("Sources/NanaFocus/NanaFlow.entitlements")
        let data = try Data(contentsOf: entitlementURL)
        let entitlements = try XCTUnwrap(
            PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        )

        XCTAssertEqual(entitlements["com.apple.security.app-sandbox"] as? Bool, true)
        XCTAssertEqual(entitlements["com.apple.security.automation.apple-events"] as? Bool, true)
        XCTAssertEqual(entitlements["com.apple.security.personal-information.calendars"] as? Bool, true)
        XCTAssertEqual(entitlements["com.apple.security.files.user-selected.read-write"] as? Bool, true)
        XCTAssertEqual(entitlements["com.apple.security.network.client"] as? Bool, true)
        XCTAssertEqual(
            entitlements["com.apple.security.temporary-exception.apple-events"] as? [String],
            [
                "com.apple.Safari",
                "com.google.Chrome",
                "com.microsoft.edgemac",
                "com.brave.Browser",
                "com.vivaldi.Vivaldi",
                "com.operasoftware.Opera",
                "com.pushplaylabs.sidekick",
                "company.thebrowser.Browser"
            ]
        )
        XCTAssertEqual(
            entitlements["com.apple.security.application-groups"] as? [String],
            ["group.com.nanafox.NanaFlow"]
        )
        XCTAssertEqual(
            entitlements["com.apple.developer.ubiquity-kvstore-identifier"] as? String,
            "$(TeamIdentifierPrefix)com.nanafox.NanaFlow"
        )
    }

    func testPermissionWindowsMatchFlowVisibleContract() {
        XCTAssertEqual(PermissionWindowMetrics.alertWidth, 300)
        XCTAssertEqual(PermissionWindowMetrics.alertHeight, 272)
        XCTAssertEqual(PermissionWindowMetrics.chooserWidth, 300)
        XCTAssertEqual(PermissionWindowMetrics.chooserHeight, 332)
        XCTAssertEqual(PermissionWindowMetrics.contentWidth, 268)
        XCTAssertEqual(PermissionWindowMetrics.notificationMessageFontSize, 12.5)
        XCTAssertEqual(PermissionWindowMetrics.calendarMessageFontSize, 11.5)
        XCTAssertEqual(PermissionWindowMetrics.primaryButtonHeight, 36)
        XCTAssertEqual(PermissionWindowMetrics.iconSize, 68)
        XCTAssertEqual(PermissionWindowMetrics.calendarIconSize, 82)

        XCTAssertEqual(PermissionAlertKind.notification.title, "允许通知")
        XCTAssertEqual(
            PermissionAlertKind.notification.message,
            "在系统设置中禁用通知。 转到系统设置以允许通知，然后重试。"
        )
        XCTAssertEqual(PermissionAlertKind.calendar.title, "允许日历访问")
        XCTAssertEqual(
            PermissionAlertKind.calendar.message,
            "系统偏好设置中已禁用日历访问权限。请转到系统偏好设置以允许完整的日历访问权限，然后重试。"
        )
    }

    func testPermissionRoutingKeepsDeniedFeaturesOff() {
        XCTAssertEqual(
            PermissionRouting.notification(enabled: true, status: .denied),
            .showNotificationAlert
        )
        XCTAssertEqual(
            PermissionRouting.notification(enabled: true, status: .notDetermined),
            .requestAuthorization
        )
        XCTAssertEqual(
            PermissionRouting.notification(enabled: true, status: .authorized),
            .enable
        )
        XCTAssertEqual(
            PermissionRouting.calendar(enabled: true, status: .authorized),
            .showCalendarChooser
        )
        XCTAssertEqual(
            PermissionRouting.calendar(enabled: false, status: .authorized),
            .disable
        )
    }

    func testPermissionAlertsAndEmptyCalendarChooserRender() {
        let notification = ImageRenderer(content: PermissionAlertView(kind: .notification, onDismiss: {}))
        notification.proposedSize = ProposedViewSize(
            width: PermissionWindowMetrics.alertWidth,
            height: PermissionWindowMetrics.alertHeight
        )
        let calendar = ImageRenderer(content: PermissionAlertView(kind: .calendar, onDismiss: {}))
        calendar.proposedSize = ProposedViewSize(
            width: PermissionWindowMetrics.alertWidth,
            height: PermissionWindowMetrics.alertHeight
        )
        let chooser = ImageRenderer(content: CalendarChooserView(
            choices: [],
            selectedIdentifier: .constant(nil),
            onCancel: {},
            onDone: {}
        ))
        chooser.proposedSize = ProposedViewSize(
            width: PermissionWindowMetrics.chooserWidth,
            height: PermissionWindowMetrics.chooserHeight
        )

        let notificationImage = notification.nsImage
        let calendarImage = calendar.nsImage
        let chooserImage = chooser.nsImage
        XCTAssertNotNil(notificationImage)
        XCTAssertNotNil(calendarImage)
        XCTAssertNotNil(chooserImage)
        if let notificationImage { attach(notificationImage, name: "nanaflow-notification-alert") }
        if let calendarImage { attach(calendarImage, name: "nanaflow-calendar-alert") }
        if let chooserImage { attach(chooserImage, name: "nanaflow-calendar-chooser") }
    }

    func testCalendarPermissionIconIsBundled() {
        XCTAssertNotNil(NSImage(named: "NanaFlowCalendarAccess"))
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
