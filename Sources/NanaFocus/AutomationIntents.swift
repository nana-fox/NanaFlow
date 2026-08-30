import AppIntents

private protocol NanaFlowCommandIntent: AppIntent {}

extension NanaFlowCommandIntent {
    @MainActor
    func run(_ command: TimerAutomationCommand) {
        TimerController.shared.perform(command)
    }
}

enum Phase: String, AppEnum, CaseIterable {
    case flow
    case shortBreak
    case longBreak

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "阶段")
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .flow: "NanaFlow",
        .shortBreak: "短暂休息",
        .longBreak: "长时间停顿"
    ]

    init(_ phase: SessionPhase) {
        switch phase {
        case .focus: self = .flow
        case .shortBreak: self = .shortBreak
        case .longBreak: self = .longBreak
        }
    }
}

struct StartSessionIntent: NanaFlowCommandIntent {
    static let title: LocalizedStringResource = "启动或恢复会话"
    static let description = IntentDescription("启动或恢复当前 NanaFlow 会话或休息。")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        run(.start)
        return .result()
    }
}

struct PauseSessionIntent: NanaFlowCommandIntent {
    static let title: LocalizedStringResource = "暂停会话"
    static let description = IntentDescription("暂停当前 NanaFlow 会话或休息。")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        run(.pause)
        return .result()
    }
}

struct ToggleTimerIntent: NanaFlowCommandIntent {
    static let title: LocalizedStringResource = "切换计时器"
    static let description = IntentDescription("在运行和暂停之间切换 NanaFlow 计时器。")

    @MainActor
    func perform() async throws -> some IntentResult & OpensIntent {
        run(.toggle)
        return .result(opensIntent: OpenAppIntent())
    }
}

struct SkipSessionIntent: NanaFlowCommandIntent {
    static let title: LocalizedStringResource = "跳过会话"
    static let description = IntentDescription("跳过当前 NanaFlow 会话或休息。")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        run(.skip)
        return .result()
    }
}

struct ResetCycleIntent: NanaFlowCommandIntent {
    static let title: LocalizedStringResource = "重置周期"
    static let description = IntentDescription("重新开始 NanaFlow 会话周期。")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        run(.resetCycle)
        return .result()
    }
}

struct GetRemainingTimeIntent: AppIntent {
    static let title: LocalizedStringResource = "获取剩余秒数"
    static let description = IntentDescription("获取当前 NanaFlow 会话或休息的剩余秒数。")

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Int> {
        .result(value: TimerController.shared.remainingSeconds)
    }
}

struct GetCurrentPhaseIntent: AppIntent {
    static let title: LocalizedStringResource = "获取阶段"
    static let description = IntentDescription("获取当前 NanaFlow 阶段。")

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Phase> {
        .result(value: Phase(TimerController.shared.engine.state.phase))
    }
}

struct GetSessionTitleIntent: AppIntent {
    static let title: LocalizedStringResource = "获取会话标题"
    static let description = IntentDescription("获取当前 NanaFlow 会话标题。")

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        .result(value: TimerController.shared.preferences.sessionTitle)
    }
}

struct SetSessionTitleIntent: AppIntent {
    static let title: LocalizedStringResource = "设置会话标题"
    static let description = IntentDescription("设置 NanaFlow 会话标题。")

    @Parameter(
        title: "会话标题",
        description: "NanaFlow 会话的标题。",
        requestValueDialog: "输入会话标题"
    )
    var sessionTitle: String

    @MainActor
    func perform() async throws -> some IntentResult {
        TimerController.shared.updateSessionTitle(sessionTitle)
        return .result()
    }
}

struct NanaFlowShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartSessionIntent(),
            phrases: ["Start or Resume \(.applicationName)"],
            shortTitle: "Start",
            systemImageName: "play"
        )
        AppShortcut(
            intent: PauseSessionIntent(),
            phrases: ["Pause \(.applicationName)"],
            shortTitle: "Pause",
            systemImageName: "pause"
        )
        AppShortcut(
            intent: SkipSessionIntent(),
            phrases: ["Skip Session in \(.applicationName)"],
            shortTitle: "Skip",
            systemImageName: "chevron.right"
        )
        AppShortcut(
            intent: ResetCycleIntent(),
            phrases: ["Reset \(.applicationName) Cycle"],
            shortTitle: "Reset",
            systemImageName: "arrow.counterclockwise"
        )
        AppShortcut(
            intent: SetSessionTitleIntent(),
            phrases: ["Set \(.applicationName) session title"],
            shortTitle: "Set title",
            systemImageName: "character.cursor.ibeam"
        )
    }
}
