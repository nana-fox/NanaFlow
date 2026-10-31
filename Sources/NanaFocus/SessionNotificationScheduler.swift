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
    func scheduleCompletion(at date: Date, phase: SessionPhase, nextPhase: SessionPhase, autoStartsNext: Bool, sound: CompletionSound, volume: Double, quote: String?)
    func restoreCompletion(at date: Date, phase: SessionPhase)
    func completeCompletion(at date: Date, phase: SessionPhase)
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

    func scheduleCompletion(at date: Date, phase _: SessionPhase, nextPhase: SessionPhase, autoStartsNext: Bool, sound: CompletionSound, volume: Double, quote: String?) {
        scheduleCompletion(at: date, nextPhase: nextPhase, autoStartsNext: autoStartsNext, sound: sound, volume: volume, quote: quote)
    }

    // Restoring/retiring a phase never creates a notification. Simple effect spies
    // can keep implementing only scheduling and explicit cancellation.
    func restoreCompletion(at _: Date, phase _: SessionPhase) {}
    func completeCompletion(at _: Date, phase _: SessionPhase) {}
}

/// The port keeps ordering testable with a deliberately suspended asynchronous add.
@MainActor
protocol CompletionNotificationSubmitting {
    func add(_ request: UNNotificationRequest) async throws
    func pendingRequests() async -> [UNNotificationRequest]
    func removePending(identifiers: [String])
}

@MainActor
private struct SystemCompletionNotificationSubmission: CompletionNotificationSubmitting {
    func add(_ request: UNNotificationRequest) async throws {
        try await UNUserNotificationCenter.current().add(request)
    }
    func pendingRequests() async -> [UNNotificationRequest] {
        await UNUserNotificationCenter.current().pendingNotificationRequests()
    }
    func removePending(identifiers: [String]) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}

@MainActor
final class SessionNotificationScheduler: SessionNotificationScheduling {
    static let legacyNotificationIdentifier = "sessionCompletedNotification"

    static func notificationIdentifier(at date: Date, phase: SessionPhase) -> String {
        "\(legacyNotificationIdentifier).\(phase.rawValue).\(String(date.timeIntervalSinceReferenceDate.bitPattern, radix: 16))"
    }

    /// An entry retains the latest intent even after its phase naturally ends.
    /// The successor must not invalidate its queued add or remove its identifier.
    @MainActor private final class Completion {
        let identifier: String
        let deadline: Date
        let phase: SessionPhase
        var desiredRequest: UNNotificationRequest?
        var revision: UInt64 = 0
        var isQueued = false
        var ownsLegacyRequest = false
        var didComplete = false

        init(at date: Date, phase: SessionPhase) {
            identifier = SessionNotificationScheduler.notificationIdentifier(at: date, phase: phase)
            deadline = date
            self.phase = phase
        }
    }

    private let submission: any CompletionNotificationSubmitting
    private var activeCompletion: Completion?
    private var queuedCompletions: [Completion] = []
    private let now: () -> Date
    private var isSubmitting = false
    private var submissionTask: Task<Void, Never>?

    init(submission: any CompletionNotificationSubmitting = SystemCompletionNotificationSubmission(), now: @escaping () -> Date = { Date() }) {
        self.submission = submission
        self.now = now
    }

    func restoreCompletion(at date: Date, phase: SessionPhase) {
        guard activeCompletion == nil else { return }
        let completion = Completion(at: date, phase: phase)
        completion.ownsLegacyRequest = true
        activeCompletion = completion
    }

    func completeCompletion(at date: Date, phase: SessionPhase) {
        guard let completion = activeCompletion,
              completion.identifier == Self.notificationIdentifier(at: date, phase: phase) else { return }
        // Its OS trigger can still be future (for example the one-second floor).
        // Do not cancel, replay, or mark an in-flight add stale at natural expiry.
        completion.didComplete = true
        activeCompletion = nil
    }

    /// A scheduling barrier for controlled-port checks, never a delivery receipt.
    func waitForPendingSubmissions() async {
        await submissionTask?.value
    }

    private func removePending(for completion: Completion) {
        submission.removePending(identifiers: [completion.identifier])
    }

    private func removeLegacyIfOwned(by completion: Completion) async {
        guard completion.ownsLegacyRequest else { return }
        completion.ownsLegacyRequest = false
        let categories = completion.phase == .focus
            ? ["notification_pending_flow", "notification_autostarted_flow"]
            : ["notification_pending_break", "notification_autostarted_break"]
        let pending = await submission.pendingRequests()
        // A restart just after handoff can leave the predecessor's legacy ID.
        // Its existing category distinguishes focus completion from break completion.
        if pending.contains(where: { $0.identifier == Self.legacyNotificationIdentifier && categories.contains($0.content.categoryIdentifier) }) {
            submission.removePending(identifiers: [Self.legacyNotificationIdentifier])
        }
    }

    /// Serialize adds, but keep revisions and cleanup local to their phase.
    private func submit(_ completion: Completion) {
        if !completion.isQueued {
            completion.isQueued = true
            queuedCompletions.append(completion)
        }
        guard !isSubmitting else { return }
        isSubmitting = true
        submissionTask = Task { @MainActor in
            while !queuedCompletions.isEmpty {
                let completion = queuedCompletions.removeFirst()
                await removeLegacyIfOwned(by: completion)
                while let desired = completion.desiredRequest {
                    let submittedRevision = completion.revision
                    let submittedAt = now()
                    let interval = max(1, completion.deadline.timeIntervalSince(submittedAt))
                    // Calculate the relative trigger at submission, never before
                    // waiting for an older add to return.
                    let request = UNNotificationRequest(
                        identifier: completion.identifier,
                        content: desired.content,
                        trigger: UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
                    )
                    var added = false
                    do { try await submission.add(request); added = true }
                    catch { /* Notification delivery remains best effort. */ }
                    if submittedRevision == completion.revision {
                        completion.desiredRequest = nil
                    } else {
                        if completion.didComplete, completion.desiredRequest != nil, added,
                           submittedAt.addingTimeInterval(interval) <= now() {
                            let pending = await submission.pendingRequests()
                            if !pending.contains(where: { $0.identifier == completion.identifier }) {
                                // Absence cannot distinguish a removed request from
                                // an already-triggered notification awaiting display.
                                // Prefer no late replay over a possible second alert.
                                completion.desiredRequest = nil
                            }
                        }
                        // A preference replacement or explicit cancellation,
                        // never the next phase or natural completion.
                        removePending(for: completion)
                    }
                }
                completion.isQueued = false
            }
            isSubmitting = false
        }
    }

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
        scheduleCompletion(at: date, phase: nextPhase == .focus ? .shortBreak : .focus, nextPhase: nextPhase, autoStartsNext: autoStartsNext, sound: sound, volume: volume, quote: quote)
    }

    func scheduleCompletion(at date: Date, phase: SessionPhase, nextPhase: SessionPhase, autoStartsNext: Bool, sound: CompletionSound, volume: Double, quote: String?) {
        let identifier = Self.notificationIdentifier(at: date, phase: phase)
        if let activeCompletion, activeCompletion.identifier != identifier {
            cancelCompletion()
        }
        let completion = activeCompletion ?? Completion(at: date, phase: phase)
        activeCompletion = completion
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
            identifier: identifier,
            content: content,
            trigger: nil
        )

        completion.revision &+= 1
        completion.desiredRequest = request
        removePending(for: completion)
        submit(completion)
    }

    func cancelCompletion() {
        guard let completion = activeCompletion else { return }
        activeCompletion = nil
        completion.revision &+= 1
        completion.desiredRequest = nil
        removePending(for: completion)
        submit(completion)
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
