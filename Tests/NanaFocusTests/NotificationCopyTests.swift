import XCTest
import UserNotifications
@testable import NanaFlow

final class NotificationCopyTests: XCTestCase {
    func testFlowNotificationCategoryContract() {
        XCTAssertEqual(
            SessionNotificationContract.categories,
            [
                .init(identifier: "notification_app_blocked", actions: []),
                .init(identifier: "notification_pending_flow", actions: [.start]),
                .init(identifier: "notification_pending_break", actions: [.start, .skip]),
                .init(identifier: "notification_autostarted_flow", actions: [.open]),
                .init(identifier: "notification_autostarted_break", actions: [.start, .skip])
            ]
        )
    }

    @MainActor
    func testBlockedAppNotificationRequestMatchesFlowContract() throws {
        let scheduler = BlockedAppNotificationScheduler()

        let first = scheduler.request(applicationName: "聊天")
        let repeated = scheduler.request(applicationName: "聊天")
        let other = scheduler.request(applicationName: "视频")

        XCTAssertEqual(first.content.title, "聊天 在你的黑名单上")
        XCTAssertEqual(first.content.body, "在NanaFlow期间，黑名单上的应用程序被阻止")
        XCTAssertEqual(first.content.categoryIdentifier, "notification_app_blocked")
        XCTAssertNil(first.content.sound)
        let trigger = try XCTUnwrap(first.trigger as? UNTimeIntervalNotificationTrigger)
        XCTAssertEqual(trigger.timeInterval, 0.5, accuracy: 0.001)
        XCTAssertFalse(trigger.repeats)
        XCTAssertEqual(first.identifier, repeated.identifier)
        XCTAssertNotEqual(first.identifier, other.identifier)
    }

    func testCompletionSelectsFlowCategoryFromCompletedPhaseAndAutoStart() {
        XCTAssertEqual(
            SessionNotificationContract.categoryIdentifier(nextPhase: .shortBreak, autoStartsNext: false),
            "notification_pending_flow"
        )
        XCTAssertEqual(
            SessionNotificationContract.categoryIdentifier(nextPhase: .longBreak, autoStartsNext: true),
            "notification_autostarted_flow"
        )
        XCTAssertEqual(
            SessionNotificationContract.categoryIdentifier(nextPhase: .focus, autoStartsNext: false),
            "notification_pending_break"
        )
        XCTAssertEqual(
            SessionNotificationContract.categoryIdentifier(nextPhase: .focus, autoStartsNext: true),
            "notification_autostarted_break"
        )
    }

    func testNotificationActionsMapToTimerCommands() {
        XCTAssertEqual(SessionNotificationContract.command(for: "start"), .start)
        XCTAssertEqual(SessionNotificationContract.command(for: "skip"), .skip)
        XCTAssertEqual(SessionNotificationContract.command(for: "open"), .show)
        XCTAssertNil(SessionNotificationContract.command(for: "unknown"))
    }

    func testProvidesFlowsExactChineseFocusAndBreakCompletionVariants() {
        XCTAssertEqual(
            SessionNotificationCopy.focusCompleted,
            [
                .init(title: "做得好！NanaFlow完成了。", body: "是时候休息了。"),
                .init(title: "做得好！", body: "是时候放松。 休息一下？"),
                .init(title: "做得好！ NanaFlow完成了。", body: "我们休息吧。 现在开始？"),
                .init(title: "你做得很棒！", body: "这是休息的完美时刻。"),
                .init(title: "继续你的伟大工作！", body: "让我们放松几分钟吧！"),
                .init(title: "做得好！你的专注环节完成了。", body: "是时候休息一下了。"),
                .init(title: "太棒了！工作环节结束了。", body: "来放松一下，你值得的。"),
                .init(title: "干得好！这次专注时间结束了。", body: "现在是时候让自己放松一下了。"),
                .init(title: "出色完成！你完成了这个专注环节。", body: "这是休息的绝佳时刻。"),
                .init(title: "专注时间结束了，干得漂亮！", body: "休息一下，恢复一下能量吧！")
            ]
        )
        XCTAssertEqual(
            SessionNotificationCopy.breakCompleted,
            [
                .init(title: "你的休息时间结束了。", body: "你的下一个NanaFlow已经在等待了。"),
                .init(title: "准备再次工作？", body: "你有动力吗？ 大！"),
                .init(title: "休息时间结束了。 开始下一个NanaFlow？", body: "让我们回去工作吧！"),
                .init(title: "让我们专注！", body: "让我们来完成任务！"),
                .init(title: "让我们专注！", body: "让我们完成一些任务吧！"),
                .init(title: "休息时间结束了，准备好了吗？", body: "下一轮专注时间在等着你。"),
                .init(title: "准备再次进入专注模式了吗？", body: "感觉有动力了吗？太棒了！"),
                .init(title: "你的放松时间结束了！", body: "让我们重新专注，继续前进。"),
                .init(title: "休息够了，现在开始专注吧！", body: "是时候以全新的能量开始了。"),
                .init(title: "休息很棒，现在让我们开始吧！", body: "集中注意力，让我们一起完成吧！")
            ]
        )
    }

    func testNextPhaseSelectsThePhaseThatJustCompleted() {
        XCTAssertEqual(
            SessionNotificationCopy.message(nextPhase: .shortBreak, index: 3),
            SessionNotificationCopy.focusCompleted[3]
        )
        XCTAssertEqual(
            SessionNotificationCopy.message(nextPhase: .longBreak, index: 13),
            SessionNotificationCopy.focusCompleted[3]
        )
        XCTAssertEqual(
            SessionNotificationCopy.message(nextPhase: .focus, index: 4),
            SessionNotificationCopy.breakCompleted[4]
        )
        XCTAssertEqual(
            SessionNotificationCopy.message(nextPhase: .focus, index: -1),
            SessionNotificationCopy.breakCompleted[9]
        )
    }

    func testMotivationalQuoteReplacesOnlyTheFocusCompletionBody() {
        let focus = SessionNotificationCopy.content(
            nextPhase: .shortBreak,
            index: 0,
            motivationalQuote: "专注当下。"
        )
        let rest = SessionNotificationCopy.content(
            nextPhase: .focus,
            index: 0,
            motivationalQuote: "不应出现"
        )

        XCTAssertEqual(focus.title, "做得好！NanaFlow完成了。")
        XCTAssertEqual(focus.body, "专注当下。")
        XCTAssertEqual(rest.body, "你的下一个NanaFlow已经在等待了。")
    }
}
