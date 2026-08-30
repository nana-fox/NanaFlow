import SwiftUI
import XCTest
@testable import NanaFlow

@MainActor
final class TimerSyncParityTests: XCTestCase {
    func testTimerSyncSettingsOnlyApplyFlowsPublishedCrossDeviceBoundary() {
        let remotePreferences = TimerPreferences(
            autoStartFocus: true,
            autoStartBreaks: true,
            notificationSoundEnabled: false,
            commitmentModeEnabled: true,
            showWindowOnLaunch: true,
            tickingSoundEnabled: true,
            timerSyncEnabled: true,
            notificationsEnabled: false,
            appearance: .dark,
            menuBarIconStyle: .progress,
            globalHotkeysEnabled: true,
            sessionTitle: "远程标题"
        )
        let settings = TimerSyncSettings(
            configuration: TimerConfiguration(
                focusDuration: 45 * 60,
                shortBreakDuration: 10 * 60,
                longBreakDuration: 30 * 60,
                sessionsPerCycle: 6
            ),
            preferences: remotePreferences
        )
        let localPreferences = TimerPreferences(
            autoStartFocus: false,
            autoStartBreaks: false,
            notificationSoundEnabled: true,
            commitmentModeEnabled: false,
            showWindowOnLaunch: false,
            tickingSoundEnabled: false,
            timerSyncEnabled: true,
            notificationsEnabled: true,
            appearance: .light,
            menuBarIconStyle: .circle,
            globalHotkeysEnabled: false,
            sessionTitle: "本机标题"
        )

        let applied = settings.applying(to: localPreferences)

        XCTAssertEqual(settings.flowDurationInMinutes, 45)
        XCTAssertEqual(settings.shortBreakDurationInMinutes, 10)
        XCTAssertEqual(settings.longBreakDurationInMinutes, 30)
        XCTAssertEqual(settings.sessionCount, 6)
        XCTAssertTrue(applied.autoStartFocus)
        XCTAssertTrue(applied.autoStartBreaks)
        XCTAssertEqual(applied.appearance, .light)
        XCTAssertEqual(applied.menuBarIconStyle, .circle)
        XCTAssertTrue(applied.notificationsEnabled)
        XCTAssertFalse(applied.commitmentModeEnabled)
        XCTAssertFalse(applied.tickingSoundEnabled)
        XCTAssertFalse(applied.globalHotkeysEnabled)
        XCTAssertEqual(applied.sessionTitle, "本机标题")
        XCTAssertTrue(applied.timerSyncEnabled)
    }

    func testTimerSyncHelpContractMatchesObservedFlowResources() {
        XCTAssertEqual(TimerSyncContract.title, "定时器同步")
        XCTAssertEqual(TimerSyncContract.howToTitle, "如何使用 NanaFlow 的计时器同步")
        XCTAssertEqual(TimerSyncContract.statisticsTitle, "我的统计数据怎么办？")
        XCTAssertEqual(TimerSyncContract.troubleshootingTitle, "解决问题")
        XCTAssertEqual(TimerSyncContract.diagnosticsTitle, "诊断")
        XCTAssertEqual(TimerSyncContract.troubleshootingSteps.count, 4)
        XCTAssertEqual(
            TimerSyncContract.regionalWarning,
            "某些云服务在您的地区可能无法完全使用。因此，计时同步功能可能无法正常运行。我们正在积极寻找解决方案。"
        )
    }

    func testTimerSyncSettingsClampCorruptCloudValuesToSupportedRanges() throws {
        let data = try XCTUnwrap("""
        {
          "flowDurationInMinutes": -2,
          "shortBreakDurationInMinutes": 999,
          "longBreakDurationInMinutes": 0,
          "sessionCount": 999999,
          "startBreakAutomatically": false,
          "startFlowAutomatically": false
        }
        """.data(using: .utf8))

        let configuration = try JSONDecoder().decode(TimerSyncSettings.self, from: data).configuration

        XCTAssertEqual(configuration.focusDuration, 60)
        XCTAssertEqual(configuration.shortBreakDuration, 60 * 60)
        XCTAssertEqual(configuration.longBreakDuration, 60)
        XCTAssertEqual(configuration.sessionsPerCycle, 12)
    }

    func testTimerSyncViewRendersAtMainWindowSize() {
        let renderer = ImageRenderer(content: TimerSyncView(
            isEnabled: .constant(true),
            diagnostics: TimerSyncDiagnostics(
                status: .available,
                syncKey: "A1B2-C3D4",
                deviceKey: "E5F6-G7H8",
                lastSyncDate: nil
            ),
            onBack: {}
        ))
        renderer.proposedSize = ProposedViewSize(width: 380, height: 272)

        XCTAssertEqual(renderer.nsImage?.size, NSSize(width: 380, height: 272))
    }
}
