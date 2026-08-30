import AppKit
import EventKit
import SwiftUI
import UserNotifications

enum PermissionAlertKind: Equatable {
    case notification
    case calendar

    var title: String {
        switch self {
        case .notification: String(localized: "允许通知")
        case .calendar: String(localized: "允许日历访问")
        }
    }

    var message: String {
        switch self {
        case .notification:
            String(localized: "在系统设置中禁用通知。 转到系统设置以允许通知，然后重试。")
        case .calendar:
            String(localized: "系统偏好设置中已禁用日历访问权限。请转到系统偏好设置以允许完整的日历访问权限，然后重试。")
        }
    }

    var windowID: String {
        switch self {
        case .notification: "notification-alert"
        case .calendar: "calendar-alert"
        }
    }
}

enum PermissionWindowMetrics {
    static let alertWidth: CGFloat = 300
    static let alertHeight: CGFloat = 272
    static let chooserWidth: CGFloat = 300
    static let chooserHeight: CGFloat = 332
    static let contentWidth: CGFloat = 268
    static let notificationMessageFontSize: CGFloat = 12.5
    static let calendarMessageFontSize: CGFloat = 11.5
    static let primaryButtonHeight: CGFloat = 36
    static let iconSize: CGFloat = 68
    static let calendarIconSize: CGFloat = 82
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
    case showCalendarAlert
    case showCalendarChooser
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

    static func calendar(
        enabled: Bool,
        status: PermissionAuthorizationStatus
    ) -> PermissionRoutingAction {
        guard enabled else { return .disable }
        return switch status {
        case .notDetermined: .requestAuthorization
        case .authorized: .showCalendarChooser
        case .denied: .showCalendarAlert
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
                .font(.system(size: kind == .notification
                    ? PermissionWindowMetrics.notificationMessageFontSize
                    : PermissionWindowMetrics.calendarMessageFontSize))
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
        switch kind {
        case .notification:
            NSImage(named: "NanaFlowIcon") ?? NSApplication.shared.applicationIconImage
        case .calendar:
            NSImage(named: "NanaFlowCalendarAccess") ?? NSApplication.shared.applicationIconImage
        }
    }

    private var iconSize: CGFloat {
        kind == .calendar
            ? PermissionWindowMetrics.calendarIconSize
            : PermissionWindowMetrics.iconSize
    }
}

struct CalendarChoice: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let red: Double
    let green: Double
    let blue: Double
}

struct CalendarChooserView: View {
    let choices: [CalendarChoice]
    @Binding var selectedIdentifier: String?
    let onCancel: () -> Void
    let onDone: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            Text("日历")
                .font(.system(size: 13, weight: .semibold))
                .position(x: 150, y: 25)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(choices) { choice in
                        Button {
                            selectedIdentifier = choice.id
                        } label: {
                            HStack(spacing: 9) {
                                Circle()
                                    .fill(Color(
                                        red: choice.red,
                                        green: choice.green,
                                        blue: choice.blue
                                    ))
                                    .frame(width: 10, height: 10)
                                Text(choice.title)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selectedIdentifier == choice.id {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(FlowPalette.focus)
                                }
                            }
                            .padding(.horizontal, 12)
                            .frame(height: 36)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if choice.id != choices.last?.id {
                            Divider().padding(.leading, 31)
                        }
                    }
                }
            }
            .frame(width: PermissionWindowMetrics.contentWidth, height: 224)
            .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .position(x: 150, y: 161)

            HStack(spacing: 12) {
                chooserButton("取消", filled: false, action: onCancel)
                chooserButton("完成", filled: true, action: onDone)
            }
            .position(x: 150, y: 304)
        }
        .frame(
            width: PermissionWindowMetrics.chooserWidth,
            height: PermissionWindowMetrics.chooserHeight
        )
        .background(FlowPalette.window)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .preferredColorScheme(.light)
    }

    private func chooserButton(
        _ title: String,
        filled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(LocalizedStringKey(title))
        }
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(filled ? Color.white : FlowPalette.focus)
            .frame(width: 128, height: 28)
            .background(
                filled ? FlowPalette.focus : FlowPalette.focus.opacity(0.045),
                in: Capsule()
            )
            .buttonStyle(.plain)
    }
}

@MainActor
struct PermissionSystemClient {
    let notificationStatus: () async -> PermissionAuthorizationStatus
    let requestNotificationAuthorization: () async -> Bool
    let calendarStatus: () -> PermissionAuthorizationStatus
    let requestCalendarAuthorization: () async -> Bool
    let calendarChoices: () -> [CalendarChoice]

    static var live: PermissionSystemClient {
        let eventStore = EKEventStore()
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
            },
            calendarStatus: {
                switch EKEventStore.authorizationStatus(for: .event) {
                case .notDetermined: .notDetermined
                case .fullAccess: .authorized
                case .restricted, .denied, .writeOnly, .authorized: .denied
                @unknown default: .denied
                }
            },
            requestCalendarAuthorization: {
                (try? await eventStore.requestFullAccessToEvents()) == true
            },
            calendarChoices: {
                eventStore.calendars(for: .event)
                    .filter(\.allowsContentModifications)
                    .map { calendar in
                        let color = NSColor(cgColor: calendar.cgColor)?
                            .usingColorSpace(.sRGB) ?? .systemGreen
                        return CalendarChoice(
                            id: calendar.calendarIdentifier,
                            title: calendar.title,
                            red: color.redComponent,
                            green: color.greenComponent,
                            blue: color.blueComponent
                        )
                    }
                    .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
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

struct CalendarChooserWindow: View {
    @Environment(\.dismissWindow) private var dismissWindow
    let controller: TimerController
    let permissionClient: PermissionSystemClient

    @State private var choices: [CalendarChoice] = []
    @State private var selectedIdentifier: String?

    init(
        controller: TimerController,
        permissionClient: PermissionSystemClient = .live
    ) {
        self.controller = controller
        self.permissionClient = permissionClient
        _selectedIdentifier = State(initialValue: controller.preferences.calendarIdentifier)
    }

    var body: some View {
        CalendarChooserView(
            choices: choices,
            selectedIdentifier: $selectedIdentifier,
            onCancel: { dismissWindow(id: "calendar-chooser") },
            onDone: saveSelection
        )
        .onAppear {
            choices = permissionClient.calendarChoices()
            if !choices.contains(where: { $0.id == selectedIdentifier }) {
                selectedIdentifier = choices.first?.id
            }
        }
    }

    private func saveSelection() {
        var preferences = controller.preferences
        preferences.calendarIdentifier = selectedIdentifier
        preferences.calendarSyncEnabled = selectedIdentifier != nil
        controller.updatePreferences(preferences)
        dismissWindow(id: "calendar-chooser")
    }
}
