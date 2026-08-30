import AppKit
import Foundation
import UserNotifications

enum MenuBarStatusItemAction: Equatable {
    case showMenu
    case quickToggle
}

enum MenuBarStatusItemActionPolicy {
    static func action(
        eventType: NSEvent.EventType,
        modifiers: NSEvent.ModifierFlags
    ) -> MenuBarStatusItemAction? {
        if eventType == .rightMouseUp
            || (eventType == .leftMouseUp && modifiers.contains(.control)) {
            return .quickToggle
        }
        return eventType == .leftMouseUp ? .showMenu : nil
    }
}

enum SessionNotificationAction: String, Equatable, Sendable {
    case start
    case skip
    case open

    var title: String {
        switch self {
        case .start: String(localized: "开始")
        case .skip: String(localized: "跳过")
        case .open: String(localized: "打开")
        }
    }
}

struct SessionNotificationCategory: Equatable, Sendable {
    let identifier: String
    let actions: [SessionNotificationAction]
}

enum SessionNotificationContract {
    static let categories = [
        SessionNotificationCategory(identifier: "notification_app_blocked", actions: []),
        SessionNotificationCategory(identifier: "notification_pending_flow", actions: [.start]),
        SessionNotificationCategory(identifier: "notification_pending_break", actions: [.start, .skip]),
        SessionNotificationCategory(identifier: "notification_autostarted_flow", actions: [.open]),
        SessionNotificationCategory(identifier: "notification_autostarted_break", actions: [.start, .skip])
    ]

    static func categoryIdentifier(nextPhase: SessionPhase, autoStartsNext: Bool) -> String {
        switch (nextPhase == .focus, autoStartsNext) {
        case (false, false): "notification_pending_flow"
        case (false, true): "notification_autostarted_flow"
        case (true, false): "notification_pending_break"
        case (true, true): "notification_autostarted_break"
        }
    }

    static func command(for actionIdentifier: String) -> TimerAutomationCommand? {
        switch SessionNotificationAction(rawValue: actionIdentifier) {
        case .start: .start
        case .skip: .skip
        case .open: .show
        case nil: nil
        }
    }

    static var notificationCategories: Set<UNNotificationCategory> {
        Set(categories.map { category in
            UNNotificationCategory(
                identifier: category.identifier,
                actions: category.actions.map {
                    UNNotificationAction(
                        identifier: $0.rawValue,
                        title: $0.title,
                        options: [.foreground]
                    )
                },
                intentIdentifiers: []
            )
        })
    }
}

struct SessionNotificationMessage: Equatable, Sendable {
    let title: String
    let body: String
}

enum BlockedAppNotificationContract {
    static let categoryIdentifier = "notification_app_blocked"
    static let delay: TimeInterval = 0.5

    static func message(applicationName: String) -> SessionNotificationMessage {
        SessionNotificationMessage(
            title: String(
                format: String(localized: "%@ 在你的黑名单上"),
                locale: .autoupdatingCurrent,
                applicationName
            ),
            body: String(localized: "在NanaFlow期间，黑名单上的应用程序被阻止")
        )
    }
}

@MainActor
protocol BlockedAppNotificationScheduling {
    func scheduleBlockedApplication(applicationName: String)
}

@MainActor
final class BlockedAppNotificationScheduler: BlockedAppNotificationScheduling {
    private var identifiers: [String: String] = [:]

    func request(applicationName: String) -> UNNotificationRequest {
        let identifier: String
        if let existing = identifiers[applicationName] {
            identifier = existing
        } else {
            identifier = UUID().uuidString
            identifiers[applicationName] = identifier
        }

        let message = BlockedAppNotificationContract.message(applicationName: applicationName)
        let content = UNMutableNotificationContent()
        content.title = message.title
        content.body = message.body
        content.categoryIdentifier = BlockedAppNotificationContract.categoryIdentifier
        content.sound = nil

        return UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(
                timeInterval: BlockedAppNotificationContract.delay,
                repeats: false
            )
        )
    }

    func scheduleBlockedApplication(applicationName: String) {
        let request = request(applicationName: applicationName)
        Task {
            try await UNUserNotificationCenter.current().add(request)
        }
    }
}

enum SessionNotificationCopy {
    static let focusCompleted = (1 ... 10).map { index in
        SessionNotificationMessage(
            title: localized("flowCompletedTitle\(index)"),
            body: localized("flowCompletedBody\(index)")
        )
    }

    static let breakCompleted = (1 ... 10).map { index in
        SessionNotificationMessage(
            title: localized("breakCompletedTitle\(index)"),
            body: localized("breakCompletedBody\(index)")
        )
    }

    private static func localized(_ key: String) -> String {
        NSLocalizedString(key, bundle: Bundle(for: TimerController.self), comment: "")
    }

    static func message(nextPhase: SessionPhase, index: Int) -> SessionNotificationMessage {
        let messages = nextPhase == .focus ? breakCompleted : focusCompleted
        let normalizedIndex = ((index % messages.count) + messages.count) % messages.count
        return messages[normalizedIndex]
    }

    static func content(
        nextPhase: SessionPhase,
        index: Int,
        motivationalQuote: String?
    ) -> SessionNotificationMessage {
        let selected = message(nextPhase: nextPhase, index: index)
        guard nextPhase != .focus, let motivationalQuote else { return selected }
        return SessionNotificationMessage(title: selected.title, body: motivationalQuote)
    }
}

@MainActor
protocol SessionNotificationScheduling {
    func scheduleCompletion(at date: Date, nextPhase: SessionPhase, sound: CompletionSound, volume: Double, quote: String?)
    func scheduleCompletion(
        at date: Date,
        nextPhase: SessionPhase,
        autoStartsNext: Bool,
        sound: CompletionSound,
        volume: Double,
        quote: String?
    )
    func cancelCompletion()
}

extension SessionNotificationScheduling {
    func scheduleCompletion(
        at date: Date,
        nextPhase: SessionPhase,
        autoStartsNext _: Bool,
        sound: CompletionSound,
        volume: Double,
        quote: String?
    ) {
        scheduleCompletion(at: date, nextPhase: nextPhase, sound: sound, volume: volume, quote: quote)
    }
}

@MainActor
final class SessionNotificationScheduler: SessionNotificationScheduling {
    private static let notificationIdentifier = "sessionCompletedNotification"

    func scheduleCompletion(at date: Date, nextPhase: SessionPhase, sound: CompletionSound, volume: Double, quote: String?) {
        scheduleCompletion(
            at: date,
            nextPhase: nextPhase,
            autoStartsNext: false,
            sound: sound,
            volume: volume,
            quote: quote
        )
    }

    func scheduleCompletion(
        at date: Date,
        nextPhase: SessionPhase,
        autoStartsNext: Bool,
        sound: CompletionSound,
        volume: Double,
        quote: String?
    ) {
        let interval = max(1, date.timeIntervalSinceNow)
        let message = SessionNotificationCopy.content(
            nextPhase: nextPhase,
            index: Int.random(in: 0 ..< SessionNotificationCopy.focusCompleted.count),
            motivationalQuote: quote
        )
        let content = UNMutableNotificationContent()
        content.title = message.title
        content.body = message.body
        content.categoryIdentifier = SessionNotificationContract.categoryIdentifier(
            nextPhase: nextPhase,
            autoStartsNext: autoStartsNext
        )
        content.sound = sound.fileName(volume: volume).map { UNNotificationSound(named: UNNotificationSoundName($0)) }

        let request = UNNotificationRequest(
            identifier: Self.notificationIdentifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        )

        Task {
            let center = UNUserNotificationCenter.current()
            center.removePendingNotificationRequests(withIdentifiers: [Self.notificationIdentifier])
            try await center.add(request)
        }
    }

    func cancelCompletion() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [Self.notificationIdentifier]
        )
    }
}

@MainActor
final class NanaFlowAppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private var statusItemService: AppStatusItemService?
    private var configuredInitialWindows = false

    func applicationDidFinishLaunching(_: Notification) {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.setNotificationCategories(SessionNotificationContract.notificationCategories)
        DispatchQueue.main.async {
            self.configureFileMenuCommands()
        }
        let statusItemService = AppStatusItemService(controller: TimerController.shared)
        self.statusItemService = statusItemService
        statusItemService.start()
    }

    func applicationShouldHandleReopen(
        _: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        if !flag {
            AppWindowActivation.bringToFront(title: "NanaFlow")
        }
        return true
    }

    func applicationWillTerminate(_: Notification) {
        statusItemService?.stop()
    }

    func claimInitialWindowConfiguration() -> Bool {
        guard !configuredInitialWindows else { return false }
        configuredInitialWindows = true
        return true
    }

    private func configureFileMenuCommands() {
        let fileTitle = String(localized: "文件")
        let fullscreenTitle = String(localized: "新Fullscreen窗口")
        let closeTitle = String(localized: "关闭")
        let closeAllTitle = String(localized: "全部关闭")
        guard let fileMenu = NSApplication.shared.mainMenu?.items
            .first(where: { $0.title == fileTitle })?.submenu else { return }

        for item in fileMenu.items {
            if item.title == fullscreenTitle {
                item.target = self
                item.action = #selector(showFullscreenWindow(_:))
                item.isEnabled = true
            } else if item.action == #selector(NSWindow.performClose(_:)) || item.title == closeTitle {
                item.target = self
                item.action = #selector(closeKeyWindow(_:))
                item.isEnabled = true
            } else if item.action == Selector(("closeAll:")) || item.title == closeAllTitle {
                item.target = self
                item.action = #selector(closeAllWindows(_:))
                item.isEnabled = true
            }
        }
    }

    @objc private func showFullscreenWindow(_: Any?) {
        FullscreenBreakWindowController.shared.show(
            controller: TimerController.shared,
            manuallyTriggered: true
        )
    }

    @objc private func closeKeyWindow(_: Any?) {
        let keyWindow = NSApplication.shared.keyWindow ?? NSApplication.shared.mainWindow
        if keyWindow === FullscreenBreakWindowController.shared.window {
            FullscreenBreakWindowController.shared.close()
        } else {
            keyWindow?.close()
        }
    }

    @objc private func closeAllWindows(_: Any?) {
        FullscreenBreakWindowController.shared.close()
        NSApplication.shared.windows.filter(\.isVisible).forEach { $0.close() }
    }

    nonisolated func userNotificationCenter(
        _: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard let command = SessionNotificationContract.command(
            for: response.actionIdentifier
        ) else { return }
        await MainActor.run {
            TimerController.shared.perform(command)
        }
    }

    nonisolated func userNotificationCenter(
        _: UNUserNotificationCenter,
        willPresent _: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

enum MotivationalQuotes {
    static let values = WidgetVisualMetrics.quotes.map(\.text)

    static func quote(for date: Date) -> String {
        WidgetVisualMetrics.quote(for: date).text
    }
}
