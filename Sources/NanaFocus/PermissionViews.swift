import AppKit
import SwiftUI
import UserNotifications

enum PermissionAlertKind: Equatable {
    case notification

    var title: String {
        String(localized: "允许通知")
    }

    var message: String {
        String(localized: "在系统设置中禁用通知。 转到系统设置以允许通知，然后重试。")
    }

    var windowID: String {
        "notification-alert"
    }
}

enum PermissionWindowMetrics {
    static let alertWidth: CGFloat = 300
    static let alertHeight: CGFloat = 272
    static let contentWidth: CGFloat = 268
    static let notificationMessageFontSize: CGFloat = 12.5
    static let primaryButtonHeight: CGFloat = 36
    static let iconSize: CGFloat = 68
}

enum PermissionAuthorizationStatus: Equatable {
    case notDetermined
    case authorized
    case denied
}

enum PermissionRoutingAction: Equatable {
    case disable
    case requestAuthorization
    case enable
    case showNotificationAlert
}

enum PermissionRouting {
    static func notification(
        enabled: Bool,
        status: PermissionAuthorizationStatus
    ) -> PermissionRoutingAction {
        guard enabled else { return .disable }
        return switch status {
        case .notDetermined: .requestAuthorization
        case .authorized: .enable
        case .denied: .showNotificationAlert
        }
    }

}

struct PermissionAlertView: View {
    let kind: PermissionAlertKind
    let onDismiss: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            Image(nsImage: icon)
                .resizable()
                .frame(
                    width: iconSize,
                    height: iconSize
                )
                .shadow(color: .black.opacity(0.18), radius: 9, y: 5)
                .position(x: 150, y: 61)

            Text(kind.title)
                .font(.system(size: 14, weight: .semibold))
                .position(x: 150, y: 124)

            Text(kind.message)
                .font(.system(size: PermissionWindowMetrics.notificationMessageFontSize))
                .foregroundStyle(.primary.opacity(0.86))
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .frame(width: PermissionWindowMetrics.contentWidth)
                .position(x: 150, y: 157)

            Button("好的", action: onDismiss)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(
                    width: PermissionWindowMetrics.contentWidth,
                    height: PermissionWindowMetrics.primaryButtonHeight
                )
                .background(FlowPalette.focus, in: Capsule())
                .buttonStyle(.plain)
                .position(x: 150, y: 238)
        }
        .frame(
            width: PermissionWindowMetrics.alertWidth,
            height: PermissionWindowMetrics.alertHeight
        )
        .background(FlowPalette.window)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .preferredColorScheme(.light)
    }

    private var icon: NSImage {
        NSImage(named: "NanaFlowIcon") ?? NSApplication.shared.applicationIconImage
    }

    private var iconSize: CGFloat {
        PermissionWindowMetrics.iconSize
    }
}

@MainActor
struct PermissionSystemClient {
    let notificationStatus: () async -> PermissionAuthorizationStatus
    let requestNotificationAuthorization: () async -> Bool

    static var live: PermissionSystemClient {
        return PermissionSystemClient(
            notificationStatus: {
                let settings = await UNUserNotificationCenter.current().notificationSettings()
                return switch settings.authorizationStatus {
                case .notDetermined: .notDetermined
                case .authorized, .provisional, .ephemeral: .authorized
                case .denied: .denied
                @unknown default: .denied
                }
            },
            requestNotificationAuthorization: {
                (try? await UNUserNotificationCenter.current().requestAuthorization(
                    options: [.alert, .sound]
                )) == true
            }
        )
    }
}

struct PermissionAlertWindow: View {
    @Environment(\.dismissWindow) private var dismissWindow
    let kind: PermissionAlertKind

    var body: some View {
        PermissionAlertView(kind: kind) {
            dismissWindow(id: kind.windowID)
        }
    }
}
