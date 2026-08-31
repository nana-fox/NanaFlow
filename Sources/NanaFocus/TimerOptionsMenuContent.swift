import SwiftUI

struct TimerOptionsMenuContent: View {
    let controller: TimerController
    let onTimerSettings: () -> Void
    let onStatistics: () -> Void
    let onSettings: () -> Void
    let onAbout: () -> Void

    var body: some View {
        Button("计时设置", action: onTimerSettings)
        Button(phaseSwitchTitle) { controller.skip() }
            .disabled(controller.isCommittedFocus)
        Button("统计", action: onStatistics)
        Divider()
        Button("设置…", action: onSettings)
        Button("关于 NanaFlow", action: onAbout)
    }

    private var phaseSwitchTitle: String {
        controller.engine.state.phase == .focus ? "开始休息" : "返回专注"
    }
}
