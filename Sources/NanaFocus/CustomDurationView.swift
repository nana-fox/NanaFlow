import SwiftUI

enum CustomDurationContract {
    static let title = String(localized: "自定义持续时间")
    static let explanation = String(localized: "为您的 NanaFlows 和休息设置自定义持续时间。")
}

struct CustomDurationView: View {
    let controller: TimerController
    let onBack: () -> Void

    @State private var focusMinutes: Int
    @State private var shortBreakMinutes: Int
    @State private var longBreakMinutes: Int
    @State private var cycles: Int

    init(controller: TimerController, onBack: @escaping () -> Void = {}) {
        self.controller = controller
        self.onBack = onBack
        let configuration = controller.engine.configuration
        _focusMinutes = State(initialValue: Int(configuration.focusDuration / 60))
        _shortBreakMinutes = State(initialValue: Int(configuration.shortBreakDuration / 60))
        _longBreakMinutes = State(initialValue: Int(configuration.longBreakDuration / 60))
        _cycles = State(initialValue: configuration.sessionsPerCycle)
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    sectionLabel("时长")
                    VStack(spacing: 0) {
                        durationRow("专注", value: $focusMinutes, range: 5 ... 90, step: 5, unit: "分钟")
                        durationRow("短休息", value: $shortBreakMinutes, range: 1 ... 30, step: 1, unit: "分钟")
                        durationRow("长休息", value: $longBreakMinutes, range: 5 ... 60, step: 5, unit: "分钟")
                        durationRow("循环", value: $cycles, range: 1 ... 8, step: 1, unit: "轮")
                    }
                    .background(
                        Color.primary.opacity(SettingsVisualMetrics.cardOverlayOpacity),
                        in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                    )

                    sectionLabel("自动开始")
                    VStack(spacing: 0) {
                        planToggleRow("休息", isOn: preferenceBinding(\.autoStartBreaks))
                        planToggleRow("专注", isOn: preferenceBinding(\.autoStartFocus), showsDivider: false)
                    }
                    .background(
                        Color.primary.opacity(SettingsVisualMetrics.cardOverlayOpacity),
                        in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                    )
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }
            .scrollIndicators(.visible)
            .contentMargins(.trailing, 2, for: .scrollIndicators)
        }
        .frame(width: 380, height: 272)
        .background(FlowPalette.window)
        .preferredColorScheme(controller.preferences.appearance.colorScheme)
    }

    private var header: some View {
        ZStack {
            Text("计时设置")
                .font(.system(size: 14, weight: .semibold))

            HStack {
                Button(action: save) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("返回")
                Spacer()
                Button("完成", action: save)
                    .buttonStyle(.plain)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(FlowPalette.focus)
            }
        }
        .frame(height: 44)
        .padding(.horizontal, 8)
    }

    private func save() {
        controller.updateDurations(
            focusMinutes: focusMinutes,
            shortBreakMinutes: shortBreakMinutes,
            longBreakMinutes: longBreakMinutes,
            cycle: cycles
        )
        onBack()
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(LocalizedStringKey(title))
            .font(.system(size: 12, weight: .semibold))
            .padding(.leading, 7)
            .padding(.vertical, 6)
    }

    private func durationRow(
        _ title: String,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        step: Int,
        unit: String
    ) -> some View {
        HStack {
            Text(LocalizedStringKey(title))
            Spacer()
            HStack(spacing: 0) {
                stepperButton("minus") {
                    value.wrappedValue = max(range.lowerBound, value.wrappedValue - step)
                }
                Text("\(value.wrappedValue)\(unit)")
                    .font(.system(size: 13, weight: .semibold))
                    .monospacedDigit()
                    .frame(width: 62)
                stepperButton("plus") {
                    value.wrappedValue = min(range.upperBound, value.wrappedValue + step)
                }
            }
        }
        .font(.system(size: 13))
        .padding(.horizontal, 12)
        .frame(height: 41)
        .overlay(alignment: .bottom) { Divider().padding(.leading, 12) }
    }

    private func stepperButton(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 27, height: 27)
                .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
    }

    private func planToggleRow(
        _ title: String,
        isOn: Binding<Bool>,
        showsDivider: Bool = true
    ) -> some View {
        HStack {
            Text(LocalizedStringKey(title))
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .tint(FlowPalette.focus)
        }
        .font(.system(size: 13))
        .padding(.horizontal, 12)
        .frame(height: 41)
        .overlay(alignment: .bottom) {
            if showsDivider { Divider().padding(.leading, 12) }
        }
    }

    private func preferenceBinding(_ keyPath: WritableKeyPath<TimerPreferences, Bool>) -> Binding<Bool> {
        Binding(
            get: { controller.preferences[keyPath: keyPath] },
            set: { value in
                var preferences = controller.preferences
                preferences[keyPath: keyPath] = value
                controller.updatePreferences(preferences)
            }
        )
    }
}
