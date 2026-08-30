import SwiftUI

struct TimerSyncSettings: Codable, Equatable, Sendable {
    let flowDurationInMinutes: Int
    let shortBreakDurationInMinutes: Int
    let longBreakDurationInMinutes: Int
    let sessionCount: Int
    let startBreakAutomatically: Bool
    let startFlowAutomatically: Bool

    init(configuration: TimerConfiguration, preferences: TimerPreferences) {
        flowDurationInMinutes = Int(configuration.focusDuration / 60)
        shortBreakDurationInMinutes = Int(configuration.shortBreakDuration / 60)
        longBreakDurationInMinutes = Int(configuration.longBreakDuration / 60)
        sessionCount = configuration.sessionsPerCycle
        startBreakAutomatically = preferences.autoStartBreaks
        startFlowAutomatically = preferences.autoStartFocus
    }

    var configuration: TimerConfiguration {
        TimerConfiguration(
            focusDuration: Double(min(max(flowDurationInMinutes, 1), 180)) * 60,
            shortBreakDuration: Double(min(max(shortBreakDurationInMinutes, 1), 60)) * 60,
            longBreakDuration: Double(min(max(longBreakDurationInMinutes, 1), 90)) * 60,
            sessionsPerCycle: min(max(sessionCount, 1), 12)
        )
    }

    func applying(to local: TimerPreferences) -> TimerPreferences {
        var result = local
        result.autoStartBreaks = startBreakAutomatically
        result.autoStartFocus = startFlowAutomatically
        return result
    }
}

enum TimerSyncStatus: Equatable, Sendable {
    case available
    case unavailable

    var title: String {
        switch self {
        case .available: String(localized: "可用")
        case .unavailable: String(localized: "不可用")
        }
    }
}

struct TimerSyncDiagnostics: Equatable, Sendable {
    var status: TimerSyncStatus
    var syncKey: String
    var deviceKey: String
    var lastSyncDate: Date?

    static let unavailable = TimerSyncDiagnostics(
        status: .unavailable,
        syncKey: "—",
        deviceKey: "—",
        lastSyncDate: nil
    )
}

enum TimerSyncContract {
    static var title: String { String(localized: "定时器同步") }
    static var howToTitle: String { String(localized: "如何使用 NanaFlow 的计时器同步") }
    static var explanation: String { String(localized: "启用后，您的计时器和会话设置（包括持续时间、循环和自动启动选项）会通过相同的 iCloud 账户在所有设备上同步。") }
    static var statisticsTitle: String { String(localized: "我的统计数据怎么办？") }
    static var statisticsExplanation: String { String(localized: "您的统计数据会通过 iCloud 自动独立同步，与此设置无关。") }
    static var troubleshootingTitle: String { String(localized: "解决问题") }
    static var troubleshootingSteps: [String] {
        [
            String(localized: "确保每台设备都登录了相同的 iCloud 账户（设置 → Apple ID）。"),
            String(localized: "确认每台设备都为 NanaFlow 启用了 iCloud（设置 → Apple ID → iCloud）。"),
            String(localized: "确保所有设备都连接到互联网。"),
            String(localized: "检查下面的同步密钥是否在每台设备上相同。如果不同，重新启动应用并在所有设备上重新启用计时器同步设置。"),
        ]
    }
    static var regionalWarning: String { String(localized: "某些云服务在您的地区可能无法完全使用。因此，计时同步功能可能无法正常运行。我们正在积极寻找解决方案。") }
    static var diagnosticsTitle: String { String(localized: "诊断") }
}

struct TimerSyncView: View {
    @Binding var isEnabled: Bool
    let diagnostics: TimerSyncDiagnostics
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    toggleCard
                    textSection(TimerSyncContract.howToTitle, TimerSyncContract.explanation)
                    textSection(TimerSyncContract.statisticsTitle, TimerSyncContract.statisticsExplanation)
                    troubleshootingSection
                    diagnosticsSection
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 16)
            }
            .scrollIndicators(.visible)
            .contentMargins(.trailing, 2, for: .scrollIndicators)
        }
        .frame(width: 380, height: 272)
        .background(FlowPalette.window)
    }

    private var header: some View {
        ZStack {
            Text(TimerSyncContract.title)
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

    private var toggleCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(TimerSyncContract.title)
                    .font(.system(size: 13, weight: .medium))
                Text(isEnabled ? String(localized: "已启用") : String(localized: "已停用"))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: $isEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .tint(FlowPalette.focus)
        }
        .padding(.horizontal, 14)
        .frame(height: 52)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    private func textSection(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            sectionTitle(title)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(cardBackground, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
    }

    private var troubleshootingSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            sectionTitle(TimerSyncContract.troubleshootingTitle)
            VStack(alignment: .leading, spacing: 9) {
                ForEach(Array(TimerSyncContract.troubleshootingSteps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(index + 1)")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 18, height: 18)
                            .background(FlowPalette.focus, in: Circle())
                        Text(step)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Text(TimerSyncContract.regionalWarning)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .background(cardBackground, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
    }

    private var diagnosticsSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            sectionTitle(TimerSyncContract.diagnosticsTitle)
            VStack(spacing: 0) {
                diagnosticRow("状态", diagnostics.status.title)
                Divider().padding(.leading, 12)
                diagnosticRow("同步密钥", diagnostics.syncKey)
                Divider().padding(.leading, 12)
                diagnosticRow("设备密钥", diagnostics.deviceKey)
                if let lastSyncDate = diagnostics.lastSyncDate {
                    Divider().padding(.leading, 12)
                    diagnosticRow("上次同步", lastSyncDate.formatted(date: .abbreviated, time: .shortened))
                }
            }
            .background(cardBackground, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
    }

    private func diagnosticRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(LocalizedStringKey(title))
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .font(.system(size: 12))
        .padding(.horizontal, 12)
        .frame(height: 36)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .padding(.leading, 12)
    }

    private var cardBackground: Color {
        Color.primary.opacity(SettingsVisualMetrics.cardOverlayOpacity)
    }
}
