import AppKit
import ServiceManagement
import SwiftUI

struct TimerSettingsView: View {
    @Environment(\.openWindow) private var openWindow
    let controller: TimerController
    let onBack: () -> Void
    let permissionClient: PermissionSystemClient

    @State private var launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
    @State private var launchError: String?

    init(
        controller: TimerController,
        onBack: @escaping () -> Void,
        permissionClient: PermissionSystemClient = .live
    ) {
        self.controller = controller
        self.onBack = onBack
        self.permissionClient = permissionClient
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    settingsSection("启动") {
                        SettingsToggleRow("登录时启动", isOn: launchAtLoginBinding)
                        SettingsToggleRow("启动时显示窗口", isOn: preferenceBinding(\.showWindowOnLaunch))
                        SettingsToggleRow(
                            "计时开始后隐藏窗口",
                            isOn: preferenceBinding(\.hideWindowWhenTimerStarts),
                            showsDivider: false
                        )
                    }

                    settingsSection("提醒") {
                        SettingsToggleRow("允许通知", isOn: notificationPermissionBinding)
                        SettingsMenuRow("完成声音", value: controller.preferences.focusCompletionSound.title) {
                            ForEach(CompletionSound.menuOrder) { sound in
                                Button(sound.title) { updateCompletionSound(sound) }
                            }
                        }
                        SettingsToggleRow(
                            "专注时播放滴答声",
                            isOn: preferenceBinding(\.tickingSoundEnabled),
                            showsDivider: false
                        )
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, SettingsVisualMetrics.contentOffsetY)
                .padding(.bottom, SettingsVisualMetrics.bottomPadding)
            }
            .scrollIndicators(.visible)
            .contentMargins(
                .trailing,
                SettingsVisualMetrics.scrollIndicatorTrailingInset,
                for: .scrollIndicators
            )
        }
        .frame(width: 380, height: 272)
        .background(FlowPalette.window)
        .preferredColorScheme(controller.preferences.appearance.colorScheme)
        .alert("无法更新登录项", isPresented: Binding(
            get: { launchError != nil },
            set: { if !$0 { launchError = nil } }
        )) {
            Button("好") { launchError = nil }
        } message: {
            Text(launchError ?? String(localized: "未知错误"))
        }
    }

    private var header: some View {
        ZStack {
            Text("设置")
                .font(.system(size: 13, weight: .semibold))

            HStack {
                Button(action: onBack) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 17, weight: .medium))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("返回")
                Spacer()
            }
        }
        .frame(height: 42)
        .padding(.horizontal, 10)
    }

    private func settingsSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(LocalizedStringKey(title))
                .font(.system(size: 13, weight: .semibold))
                .padding(.leading, 14)

            VStack(spacing: 0) {
                content()
            }
            .background(
                Color.primary.opacity(SettingsVisualMetrics.cardOverlayOpacity),
                in: RoundedRectangle(cornerRadius: 13, style: .continuous)
            )
        }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { launchAtLoginEnabled },
            set: { enabled in
                do {
                    if enabled {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                    launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
                } catch {
                    launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
                    launchError = error.localizedDescription
                }
            }
        )
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

    private func preferenceBinding(_ keyPath: WritableKeyPath<TimerPreferences, Double>) -> Binding<Double> {
        Binding(
            get: { controller.preferences[keyPath: keyPath] },
            set: { value in
                var preferences = controller.preferences
                preferences[keyPath: keyPath] = min(max(value, SettingsVolumeContract.range.lowerBound), SettingsVolumeContract.range.upperBound)
                controller.updatePreferences(preferences)
            }
        )
    }

    private var notificationPermissionBinding: Binding<Bool> {
        Binding(
            get: { controller.preferences.notificationsEnabled },
            set: { enabled in
                guard enabled else {
                    updatePermissionPreference(\.notificationsEnabled, enabled: false)
                    return
                }
                Task { @MainActor in
                    let status = await permissionClient.notificationStatus()
                    await handleNotificationRoute(
                        PermissionRouting.notification(enabled: true, status: status)
                    )
                }
            }
        )
    }

    private var calendarPermissionBinding: Binding<Bool> {
        Binding(
            get: { controller.preferences.calendarSyncEnabled },
            set: { enabled in
                guard enabled else {
                    updatePermissionPreference(\.calendarSyncEnabled, enabled: false)
                    return
                }
                Task { @MainActor in
                    await handleCalendarRoute(PermissionRouting.calendar(
                        enabled: true,
                        status: permissionClient.calendarStatus()
                    ))
                }
            }
        )
    }

    private func handleNotificationRoute(_ route: PermissionRoutingAction) async {
        switch route {
        case .enable:
            updatePermissionPreference(\.notificationsEnabled, enabled: true)
        case .requestAuthorization:
            if await permissionClient.requestNotificationAuthorization() {
                updatePermissionPreference(\.notificationsEnabled, enabled: true)
            } else {
                updatePermissionPreference(\.notificationsEnabled, enabled: false)
                openWindow(id: PermissionAlertKind.notification.windowID)
            }
        case .showNotificationAlert:
            updatePermissionPreference(\.notificationsEnabled, enabled: false)
            openWindow(id: PermissionAlertKind.notification.windowID)
        case .disable:
            updatePermissionPreference(\.notificationsEnabled, enabled: false)
        case .showCalendarAlert, .showCalendarChooser:
            break
        }
    }

    private func handleCalendarRoute(_ route: PermissionRoutingAction) async {
        switch route {
        case .showCalendarChooser:
            openWindow(id: "calendar-chooser")
        case .requestAuthorization:
            if await permissionClient.requestCalendarAuthorization() {
                openWindow(id: "calendar-chooser")
            } else {
                updatePermissionPreference(\.calendarSyncEnabled, enabled: false)
                openWindow(id: PermissionAlertKind.calendar.windowID)
            }
        case .showCalendarAlert:
            updatePermissionPreference(\.calendarSyncEnabled, enabled: false)
            openWindow(id: PermissionAlertKind.calendar.windowID)
        case .disable:
            updatePermissionPreference(\.calendarSyncEnabled, enabled: false)
        case .enable, .showNotificationAlert:
            break
        }
    }

    private func updatePermissionPreference(
        _ keyPath: WritableKeyPath<TimerPreferences, Bool>,
        enabled: Bool
    ) {
        var preferences = controller.preferences
        preferences[keyPath: keyPath] = enabled
        controller.updatePreferences(preferences)
    }

    private func updateAppearance(_ appearance: AppAppearance) {
        var preferences = controller.preferences
        preferences.appearance = appearance
        controller.updatePreferences(preferences)
    }

    private func updateCompletionSound(_ sound: CompletionSound) {
        var preferences = controller.preferences
        preferences.focusCompletionSound = sound
        preferences.breakCompletionSound = sound
        preferences.notificationSoundEnabled = preferences.focusCompletionSound != .none || preferences.breakCompletionSound != .none
        controller.updatePreferences(preferences)
        guard let fileName = sound.fileName,
              let url = Bundle.main.url(forResource: fileName, withExtension: nil) else { return }
        let preview = NSSound(contentsOf: url, byReference: true)
        preview?.volume = Float(preferences.notificationVolume / 2)
        preview?.play()
    }

}

enum SettingsVisualMetrics {
    static let cardOverlayOpacity = 0.024
    static let scrollIndicatorTrailingInset: CGFloat = 12
    static let contentOffsetY: CGFloat = 3
    static let bottomPadding: CGFloat = 5.5
}

enum SettingsVolumeContract {
    static let range = 0.0 ... 2.0

    static func percentage(for volume: Double) -> Int {
        Int(min(max(volume, range.lowerBound), range.upperBound) * 50)
    }
}

struct SettingsVolumeView: View {
    @Binding var volume: Double

    var body: some View {
        HStack(spacing: 8) {
            Slider(value: $volume, in: SettingsVolumeContract.range)
                .controlSize(.small)
                .tint(FlowPalette.focus)
            Text("\(SettingsVolumeContract.percentage(for: volume))%")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(width: 34, alignment: .trailing)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("音量")
        .accessibilityValue("\(SettingsVolumeContract.percentage(for: volume))%")
    }
}

private struct SettingsToggleRow: View {
    let title: String
    @Binding var isOn: Bool
    let showsDivider: Bool

    init(_ title: String, isOn: Binding<Bool>, showsDivider: Bool = true) {
        self.title = title
        _isOn = isOn
        self.showsDivider = showsDivider
    }

    var body: some View {
        HStack {
            Text(LocalizedStringKey(title))
            Spacer()
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .labelsHidden()
                .accessibilityLabel(Text(LocalizedStringKey(title)))
                .controlSize(.small)
                .tint(FlowPalette.focus)
        }
        .settingsRow(showsDivider: showsDivider)
    }
}

private struct SettingsValueRow: View {
    let title: String
    let value: String

    init(_ title: String, value: String) {
        self.title = title
        self.value = value
    }

    var body: some View {
        HStack {
            Text(LocalizedStringKey(title))
            Spacer()
            Text(value)
                .settingsValueStyle()
        }
        .settingsRow()
    }
}

private struct SettingsButtonRow: View {
    let title: String
    let value: String
    let action: () -> Void

    init(_ title: String, value: String, action: @escaping () -> Void) {
        self.title = title
        self.value = value
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack {
                Text(LocalizedStringKey(title))
                Spacer()
                Text(value)
                    .settingsValueStyle()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .settingsRow()
    }
}

private struct KeyboardShortcutsView: View {
    @Environment(\.dismiss) private var dismiss
    let controller: TimerController

    private let localShortcuts = [
        ("关闭窗口", "⌘W"),
        ("打开设置", "⌘,")
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("键盘快捷键")
                    .font(.headline)
                Spacer()
                Button("完成") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(16)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("激活全局键盘快捷键", isOn: globalHotkeysBinding)
                        .toggleStyle(.switch)
                        .tint(FlowPalette.focus)
                        .padding(12)
                        .background(.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 13))

                    Text("全局快捷键或系统快捷键是激活的，可以在任何应用程序当前处于焦点时触发。")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)

                    globalShortcutSection
                    shortcutSection("本地快捷键", shortcuts: localShortcuts)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }

            Spacer()
        }
        .frame(width: 360, height: 390)
        .background(FlowPalette.window)
    }

    private var globalHotkeysBinding: Binding<Bool> {
        Binding(
            get: { controller.preferences.globalHotkeysEnabled },
            set: { enabled in
                var preferences = controller.preferences
                preferences.globalHotkeysEnabled = enabled
                controller.updatePreferences(preferences)
            }
        )
    }

    private var globalShortcutSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("全局快捷键")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("恢复默认") {
                    var preferences = controller.preferences
                    preferences.globalShortcuts = .flowDefault
                    controller.updatePreferences(preferences)
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(FlowPalette.focus)
            }
            .padding(.horizontal, 12)

            VStack(spacing: 0) {
                shortcutRecorderRow("启动或停止计时器", keyPath: \.toggle)
                shortcutRecorderRow("跳过会话或休息", keyPath: \.skip)
                shortcutRecorderRow("重置循环", keyPath: \.reset)
                shortcutRecorderRow("显示或隐藏窗口", keyPath: \.showOrHideWindow)
            }
            .background(.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
    }

    private func shortcutRecorderRow(
        _ title: String,
        keyPath: WritableKeyPath<GlobalShortcutSet, GlobalShortcut>
    ) -> some View {
        HStack {
            Text(LocalizedStringKey(title))
            Spacer()
            KeyboardShortcutRecorder(shortcut: shortcutBinding(keyPath))
                .frame(width: 112, height: 26)
        }
        .padding(.horizontal, 14)
        .frame(height: 42)
        .overlay(alignment: .bottom) { Divider().padding(.leading, 14) }
    }

    private func shortcutBinding(
        _ keyPath: WritableKeyPath<GlobalShortcutSet, GlobalShortcut>
    ) -> Binding<GlobalShortcut> {
        Binding(
            get: { controller.preferences.globalShortcuts[keyPath: keyPath] },
            set: { shortcut in
                var preferences = controller.preferences
                preferences.globalShortcuts[keyPath: keyPath] = shortcut
                controller.updatePreferences(preferences)
            }
        )
    }

    private func shortcutSection(
        _ title: String,
        shortcuts: [(String, String)]
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(LocalizedStringKey(title))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 12)

            Text("本地快捷键或特定应用程序快捷键仅在应用程序处于焦点时才激活。")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)

            VStack(spacing: 0) {
                ForEach(shortcuts, id: \.0) { shortcut in
                    HStack {
                        Text(LocalizedStringKey(shortcut.0))
                        Spacer()
                        Text(shortcut.1)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 6))
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 42)
                    .overlay(alignment: .bottom) { Divider().padding(.leading, 14) }
                }
            }
            .background(.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
    }
}

private struct SettingsMenuRow<Content: View>: View {
    let title: String
    let value: String
    @ViewBuilder let content: () -> Content

    init(_ title: String, value: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.value = value
        self.content = content
    }

    var body: some View {
        HStack {
            Text(LocalizedStringKey(title))
            Spacer()
            Menu(content: content) {
                Text(value)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .font(.system(size: 12, weight: .medium))
            .tint(FlowPalette.focus)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(FlowPalette.focus.opacity(0.09), in: Capsule())
            .fixedSize()
        }
        .settingsRow()
    }
}

private extension View {
    func settingsRow(showsDivider: Bool = true) -> some View {
        self
            .font(.system(size: 13))
            .padding(.horizontal, 14)
            .frame(height: 41)
            .overlay(alignment: .bottom) {
                if showsDivider {
                    Divider().padding(.leading, 14)
                }
            }
    }

    func settingsValueStyle() -> some View {
        self
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(FlowPalette.focus)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(FlowPalette.focus.opacity(0.09), in: Capsule())
    }
}

extension AppAppearance {
    var title: String {
        switch self {
        case .system: String(localized: "系统")
        case .light: String(localized: "浅色")
        case .dark: String(localized: "深色")
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

extension CompletionSound {
    var title: String {
        switch self {
        case .none: String(localized: "无")
        case .alarmClock: String(localized: "闹钟")
        case .bell: String(localized: "铃声")
        case .bells: String(localized: "铃铛")
        case .bowl: String(localized: "唱钵")
        case .chime: String(localized: "风铃")
        case .chord: String(localized: "和弦")
        case .harp: String(localized: "竖琴")
        case .milestone: String(localized: "重要事件")
        case .pulse: String(localized: "脉冲")
        case .ripple: String(localized: "波纹")
        case .whistle: String(localized: "吹口哨")
        }
    }
}
