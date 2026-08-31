import AppKit
import SwiftUI

struct AboutNanaFlowView: View {
    let onBack: () -> Void

    init(onBack: @escaping () -> Void = {}) {
        self.onBack = onBack
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Text("关于 NanaFlow")
                    .font(.system(size: 14, weight: .semibold))
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .medium))
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("返回")
                    Spacer()
                }
            }
            .frame(height: 44)
            .padding(.horizontal, 8)

            VStack(spacing: 0) {
                Image(systemName: "timer")
                    .font(.system(size: 42, weight: .light))
                    .foregroundStyle(.white)
                    .frame(width: 62, height: 62)
                    .background(FlowPalette.compactAccent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                Text("NanaFlow")
                    .font(.system(size: 20, weight: .semibold))
                    .padding(.top, 9)
                Text("专注、休息、继续。")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
                Text("版本 \(version)")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 6)
                Button("完成", action: onBack)
                    .buttonStyle(.plain)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .frame(height: 32)
                    .background(FlowPalette.compactAccent, in: RoundedRectangle(cornerRadius: 8))
                    .padding(.top, 12)
            }
            .frame(maxHeight: .infinity)
            .offset(y: -6)
        }
        .frame(width: AboutVisualMetrics.contentWidth, height: AboutVisualMetrics.contentHeight)
        .background(FlowPalette.window)
        .preferredColorScheme(.light)
    }

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

}

enum AboutVisualMetrics {
    static let iconImageSize: CGFloat = 62
    static let contentWidth: CGFloat = 380
    static let contentHeight = TimerVisualMetrics.windowFrameHeight
    static let contentOffsetY: CGFloat = 0
}

struct HowNanaFlowWorksView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("怎么运行的")
                .font(.system(size: 26, weight: .bold))
                .padding(.bottom, 14)

            Text("NanaFlow 基于流行的时间管理方法，称为番茄工作法。")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .padding(.bottom, HelpVisualMetrics.introBottomPadding)

            helpStep(1, title: "选择任务", detail: "从您要关注的待办事项列表中选择一项任务。")
            helpStep(2, title: "启动计时器", detail: "25分钟的短时间是保持专注的理想选择。")
            helpStep(3, title: "专注于任务", detail: "一旦启动，请进行提交。这有助于避免分心。")
            helpStep(
                4,
                title: "稍作休息",
                detail: "享受短暂的5分钟休息。站起来，伸展双腿，喝水。",
                bottomPadding: HelpVisualMetrics.finalStepBottomPadding
            )

            HStack(spacing: 10) {
                Image(systemName: "repeat")
                    .font(.system(size: 16, weight: .bold))
                Text("重复4次")
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundStyle(FlowPalette.focus)
            .padding(.leading, 56)
            .padding(.top, 8)
            .padding(.bottom, 26)
            .offset(y: HelpVisualMetrics.closingOffsetY)

            VStack(alignment: .leading, spacing: 4) {
                Text("改为稍事休息")
                    .font(.system(size: 13, weight: .bold))
                Text("每四个休息时间都是一个较长的，更具恢复性的30分钟休息时间。")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
            }
            .padding(.leading, 56)
            .offset(y: HelpVisualMetrics.closingOffsetY)

            Spacer()
        }
        .padding(.top, 24)
        .padding(.horizontal, 28)
        .frame(width: 400, height: HelpVisualMetrics.contentHeight)
        .background(FlowPalette.window)
        .preferredColorScheme(.light)
    }

    private func helpStep(
        _ number: Int,
        title: String,
        detail: String,
        bottomPadding: CGFloat = HelpVisualMetrics.stepBottomPadding
    ) -> some View {
        HStack(alignment: .top, spacing: HelpVisualMetrics.stepSpacing) {
            Text("\(number)")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(
                    width: HelpVisualMetrics.stepCircleSize,
                    height: HelpVisualMetrics.stepCircleSize
                )
                .background(FlowPalette.focus, in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey(title))
                    .font(.system(size: 13, weight: .bold))
                Text(LocalizedStringKey(detail))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
            }
        }
        .padding(.bottom, bottomPadding)
    }
}

enum HelpVisualMetrics {
    static let contentHeight: CGFloat = 560
    static let introBottomPadding: CGFloat = 45
    static let stepBottomPadding: CGFloat = 30
    static let finalStepBottomPadding: CGFloat = 20
    static let stepCircleSize: CGFloat = 27
    static let stepSpacing: CGFloat = 22
    static let closingOffsetY: CGFloat = -11
}
