import AppKit
import SwiftUI
import XCTest
@testable import NanaFlow

@MainActor
final class ViewRenderingTests: XCTestCase {
    func testMenuBarShowsTimeOnly() throws {
        let repositoryURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFocus/NanaFocusApp.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(source.contains("Text(controller.formattedTime)\n                .monospacedDigit()"))
        XCTAssertFalse(source.contains("circle.righthalf.filled"))
        XCTAssertFalse(source.contains("private var menuBarStatus"))
        XCTAssertFalse(source.contains("private var menuBarColor"))
        XCTAssertFalse(source.contains("controller.preferences.menuBarIconStyle"))
        XCTAssertFalse(source.contains("controller.preferences.showMenuBarTitle"))
        XCTAssertTrue(source.contains("hostingView?.appearance = statusItem.button?.effectiveAppearance"))

        let controller = makeController(engine: TimerEngine(
            configuration: .standard,
            state: TimerState(
                phase: .shortBreak,
                cycleIndex: 0,
                remainingWhenPaused: 5 * 60,
                endDate: nil,
                startedAt: nil
            )
        ))
        let size = NSSize(width: 120, height: 28)
        let host = NSHostingView(rootView: ZStack {
            Color(red: 0.12, green: 0.48, blue: 0.70)
            MenuBarStatusContent(controller: controller)
        }
        .frame(width: size.width, height: size.height))
        host.frame = NSRect(origin: .zero, size: size)
        host.appearance = NSAppearance(named: .darkAqua)
        host.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)

        var lightPixels = 0
        for x in 0 ..< bitmap.pixelsWide {
            for y in 0 ..< bitmap.pixelsHigh {
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { continue }
                if color.redComponent > 0.8,
                   color.greenComponent > 0.8,
                   color.blueComponent > 0.8 {
                    lightPixels += 1
                }
            }
        }
        XCTAssertGreaterThan(lightPixels, 20)
        let image = NSImage(size: size)
        image.addRepresentation(bitmap)
        attach(image, name: "nanaflow-menu-bar-high-contrast")
    }

    func testMainMenuButtonUsesFlowsMenuAccessibilitySemantics() throws {
        let repositoryURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFocus/TimerView.swift"),
            encoding: .utf8
        )

        XCTAssertFalse(source.contains(".accessibilityLabel(\"更多\")"))
        XCTAssertTrue(source.contains(".accessibilityLabel(\"菜单\")"))
        XCTAssertTrue(source.contains(".help(\"菜单\")"))
    }

    func testMainTimerKeepsCoreToolbarVisibleLikeLockedDesign() throws {
        let repositoryURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFocus/TimerView.swift"),
            encoding: .utf8
        )

        XCTAssertFalse(source.contains("@State private var isHoveringToolbar"))
        XCTAssertFalse(source.contains("if isHoveringToolbar"))
        XCTAssertFalse(source.contains(".onHover { isHoveringToolbar = $0 }"))
        XCTAssertTrue(source.contains(".accessibilityLabel(\"重新开始周期\")"))
        XCTAssertTrue(source.contains(".accessibilityLabel(\"统计\")"))
    }

    func testEnglishMainTimerAndMenuStringsShipInTheAppBundle() throws {
        let appBundle = Bundle(for: TimerController.self)
        let englishURL = try XCTUnwrap(appBundle.url(forResource: "en", withExtension: "lproj"))
        let englishBundle = try XCTUnwrap(Bundle(url: englishURL))
        let repositoryURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let expected = [
            "休息": "Break",
            "长时间停顿": "Long Break",
            "菜单": "Menu",
            "NanaFlow 持续时间": "NanaFlow Duration",
            "休息时间": "Break Duration",
            "周期": "Cycle",
            "自动": "Auto-Start",
            "定时器同步": "Timer Sync",
            "标签": "Tags",
            "设置": "Settings",
            "应用与网页阻断器": "App & Web Blocker",
            "关于 NanaFlow": "About NanaFlow",
            "怎么运行的": "How It Works",
            "退出": "Quit",
            "第 %1$lld 轮，共 %2$lld 轮": "Session %1$lld of %2$lld",
        ]
        for (key, value) in expected {
            XCTAssertEqual(
                englishBundle.localizedString(forKey: key, value: nil, table: "Localizable"),
                value,
                key
            )
        }

        let timerViewSource = try String(
            contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFocus/TimerView.swift"),
            encoding: .utf8
        )
        let tagsSource = try String(
            contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFocus/SessionTags.swift"),
            encoding: .utf8
        )
        XCTAssertFalse(timerViewSource.contains("RecommendationMenu"))
        XCTAssertTrue(timerViewSource.contains("controller.cycleAccessibilityLabel"))
        XCTAssertTrue(tagsSource.contains("String(localized: \"工作\")"))
    }

    func testEnglishSecondarySurfaceStringsShipInTheAppBundle() throws {
        let appBundle = Bundle(for: TimerController.self)
        let englishURL = try XCTUnwrap(appBundle.url(forResource: "en", withExtension: "lproj"))
        let englishBundle = try XCTUnwrap(Bundle(url: englishURL))
        let expected = [
            // Settings and permissions
            "启动": "Launch",
            "在登录时启动": "Launch at Login",
            "一般": "General",
            "键盘快捷键": "Keyboard Shortcuts",
            "全局": "Global",
            "本地": "Local",
            "菜单栏图标": "Menu Bar Icon",
            "外观": "Appearance",
            "启用承诺模式": "Commitment Mode",
            "通知": "Notifications",
            "NanaFlow 已完成": "NanaFlow Complete",
            "休息已完成": "Break Complete",
            "恢复默认": "Restore Defaults",
            "音量": "Volume",
            "允许通知": "Allow Notifications",
            "允许日历访问": "Allow Calendar Access",
            "日历": "Calendar",

            // Statistics and sessions
            "按标签过滤": "Filter by Tags",
            "清除过滤": "Clear Filter",
            "统计图表": "Statistics chart",
            "显示全部": "Show All",
            "统计指标": "Statistics Metric",
            "总计次数": "Total Count",
            "总用时": "Total Time",
            "所有会话": "All Sessions",
            "载入更多": "Load More",
            "显示未完成": "Show Incomplete",
            "导出": "Export",
            "无法导出": "Unable to Export",
            "会话详情": "Session Details",
            "时长（含中断）": "Duration With Interruptions",
            "未完成": "Not Completed",
            "返回统计": "Back to Statistics",
            "返回所有会话": "Back to All Sessions",

            // Blocker, help and timer sync
            "阻止": "Block",
            "允许": "Allow",
            "应用": "App",
            "网页": "Web",
            "黑名单上的应用只会在正在运行的NanaFlow中被阻止。": "Apps on the list will be blocked during a NanaFlow session.",
            "支持": "Support",
            "网站": "Website",
            "NanaFlow 基于流行的时间管理方法，称为番茄工作法。": "NanaFlow is based on a popular focus timer method – the Pomodoro Technique. By default it consists of four simple steps.",
            "选择任务": "Choose a task",
            "稍作休息": "Take a short break",
            "可用": "Available",
            "不可用": "Unavailable",
            "如何使用 NanaFlow 的计时器同步": "How to use the NanaFlow timer sync",
            "解决问题": "Resolving issues",
            "诊断": "Diagnostics",
            "已启用": "Enabled",
            "已停用": "Disabled",
            "同步密钥": "Sync Key",
            "设备密钥": "Device Key",
            "返回": "Back",
            "移除": "Remove",
            "帮助": "Help",
            "关闭全屏休息": "Exit Fullscreen Break",
            "menu_bar_accessibility_format": "%1$@, %2$@ remaining",
            "edit_tag_accessibility_format": "Edit tag %1$@",
            "tag_color_accessibility_format": "Tag color %1$lld",
        ]

        for (key, value) in expected {
            XCTAssertEqual(
                englishBundle.localizedString(forKey: key, value: nil, table: "Localizable"),
                value,
                key
            )
        }
    }

    func testSecondarySurfaceDynamicStringsUseLocalization() throws {
        let repositoryURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let settings = try String(
            contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFocus/TimerSettingsView.swift"),
            encoding: .utf8
        )
        let sync = try String(
            contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFocus/TimerSyncView.swift"),
            encoding: .utf8
        )
        let statistics = try String(
            contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFocus/StatisticsView.swift"),
            encoding: .utf8
        )
        let app = try String(
            contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFocus/NanaFocusApp.swift"),
            encoding: .utf8
        )
        let tags = try String(
            contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFocus/TagManagementView.swift"),
            encoding: .utf8
        )
        let commands = try String(
            contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFocus/NanaFlowCommands.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(settings.contains("String(localized: \"系统\")"))
        XCTAssertTrue(settings.contains("Text(LocalizedStringKey(title))"))
        XCTAssertTrue(sync.contains("String(localized: \"定时器同步\")"))
        XCTAssertTrue(sync.contains("String(localized: \"可用\")"))
        XCTAssertTrue(statistics.contains("Locale.autoupdatingCurrent"))
        XCTAssertTrue(statistics.contains("localizedMinutes("))
        XCTAssertTrue(app.contains("String(localized: \"menu_bar_accessibility_format\")"))
        XCTAssertFalse(app.contains("，剩余"))
        XCTAssertTrue(tags.contains("String(localized: \"edit_tag_accessibility_format\")"))
        XCTAssertTrue(tags.contains("String(localized: \"tag_color_accessibility_format\")"))
        XCTAssertTrue(commands.contains("Button(LocalizedStringKey(title))"))
    }

    func testEnglishRemainingProductSurfaceStringsShipInTheAppBundle() throws {
        let appBundle = Bundle(for: TimerController.self)
        let englishURL = try XCTUnwrap(appBundle.url(forResource: "en", withExtension: "lproj"))
        let englishBundle = try XCTUnwrap(Bundle(url: englishURL))
        let expected = [
            // Tags
            "使用标签对会话进行分类和整理。": "Categorize and organize your sessions with tags.",
            "无标签": "No Tags",
            "已选择": "Selected",
            "未选择": "Not Selected",
            "删除标签 \"%@\"？": "Delete tag \"%@\"?",
            "此标签在 1 个会话中使用。该会话将失去此标签。": "This tag is used by 1 session. That session will lose this tag.",
            "此标签在 %lld 个会话中使用。这些会话将失去此标签。": "This tag is used by %lld sessions. Those sessions will lose this tag.",
            "此操作不能撤销。": "This can't be undone.",

            // Custom durations and welcome
            "自定义持续时间": "Custom Durations",
            "为您的 NanaFlows 和休息设置自定义持续时间。": "Set custom durations for your NanaFlows and breaks.",
            "欢迎来到NanaFlow": "Welcome to NanaFlow",
            "NanaFlow将您的工作流划分为具有已定义中断的部分，使您可以轻松保持专注。": "NanaFlow divides your work into sections with defined breaks to help you stay focused and productive.",
            "在启动时显示此窗口": "Show this window at launch",

            // Unlocked Pro surface
            "NanaFlow Pro 已解锁": "NanaFlow Pro Unlocked",
            "所有高级功能已在 NanaFlow 中全部解锁，无需订阅或购买。": "All Pro features are unlocked in NanaFlow—no subscription or purchase required.",
            "解锁所有功能": "Unlock the full NanaFlow experience",
            "自定义会话标题和持续时间": "Custom session title and durations",
            "网页阻止和日历同步": "Web blocking and calendar sync",
            "跨设备计时器同步": "Timer sync across devices",
            "跨设备同步": "Sync across devices",
            "终身使用": "Lifetime access",
            "所有高级功能已解锁": "All Pro features unlocked",
            "可通过 iCloud 同步": "Syncs via iCloud",
            "无需订阅或恢复购买": "No subscription or purchase to restore",
            "无需购买  ·  不设付费墙": "No purchase  ·  No paywall",
            "已全部解锁": "Everything unlocked",
            "已启用": "Enabled",
        ]

        for (key, value) in expected {
            XCTAssertEqual(
                englishBundle.localizedString(forKey: key, value: nil, table: "Localizable"),
                value,
                key
            )
        }
    }

    func testRemainingProductSurfaceDynamicStringsUseLocalization() throws {
        let repositoryURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let tags = try String(
            contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFocus/TagManagementView.swift"),
            encoding: .utf8
        )
        let durations = try String(
            contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFocus/CustomDurationView.swift"),
            encoding: .utf8
        )
        let pro = try String(
            contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFocus/ProUnlockedView.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(tags.contains("String(localized: \"删除标签 \\\"%@\\\"？\")"))
        XCTAssertTrue(tags.contains("String(localized: \"此标签在 %lld 个会话中使用。这些会话将失去此标签。\")"))
        XCTAssertTrue(tags.contains("Text(LocalizedStringKey(title))"))
        XCTAssertFalse(tags.contains("return \"删除标签"))
        XCTAssertTrue(durations.contains("String(localized: \"自定义持续时间\")"))
        XCTAssertTrue(durations.contains("Text(LocalizedStringKey(title))"))
        XCTAssertTrue(durations.contains("Text(\"\\(value.wrappedValue)\\(unit)\")"))
        XCTAssertTrue(pro.contains("String(localized: \"NanaFlow Pro 已解锁\")"))
        XCTAssertTrue(pro.contains("String(localized: \"跨设备同步\")"))
        XCTAssertTrue(pro.contains("Text(\"已启用\")"))
    }

    func testEnglishBackgroundAndSystemStringsShipInTheAppBundle() throws {
        let appBundle = Bundle(for: TimerController.self)
        let englishURL = try XCTUnwrap(appBundle.url(forResource: "en", withExtension: "lproj"))
        let englishBundle = try XCTUnwrap(Bundle(url: englishURL))
        let expected = [
            "开始": "Start",
            "暂停": "Pause",
            "跳过": "Skip",
            "打开": "Open",
            "%@ 在你的黑名单上": "%@ is on your blocking list",
            "在NanaFlow期间，黑名单上的应用程序被阻止": "Blocked apps are unavailable during a NanaFlow session",
            "flowCompletedTitle1": "Well done! Your NanaFlow is complete.",
            "flowCompletedTitle2": "Great work session!",
            "flowCompletedTitle3": "Good job! Session finished.",
            "flowCompletedTitle4": "You've done great this NanaFlow!",
            "flowCompletedTitle5": "Session complete. Awesome!",
            "flowCompletedTitle6": "Great effort! NanaFlow complete.",
            "flowCompletedTitle7": "Nice work! NanaFlow finished.",
            "flowCompletedTitle8": "You crushed it! NanaFlow is over.",
            "flowCompletedTitle9": "Way to go! Your session is done.",
            "flowCompletedTitle10": "Another session completed successfully.",
            "flowCompletedBody1": "It's time to have a break.",
            "flowCompletedBody2": "Time to relax and have a break.",
            "flowCompletedBody3": "Let's have a break.",
            "flowCompletedBody4": "It's the perfect moment for a break.",
            "flowCompletedBody5": "Let's relax for a few minutes!",
            "flowCompletedBody6": "You've earned a well-deserved break!",
            "flowCompletedBody7": "Recharge time! Enjoy a break.",
            "flowCompletedBody8": "Take a deep breath and unwind.",
            "flowCompletedBody9": "Let's pause and refresh.",
            "flowCompletedBody10": "Break time! You've earned it.",
            "breakCompletedTitle1": "Your break is over.",
            "breakCompletedTitle2": "Ready to focus again?",
            "breakCompletedTitle3": "Your time to relax is over.",
            "breakCompletedTitle4": "Enough relaxation. Let's focus!",
            "breakCompletedTitle5": "Well, that was a nice break.",
            "breakCompletedTitle6": "Break's done. Time to work!",
            "breakCompletedTitle7": "Back to it! Let's focus.",
            "breakCompletedTitle8": "Let's get back into the groove.",
            "breakCompletedTitle9": "Hope you enjoyed your break!",
            "breakCompletedTitle10": "Break is up! Focus time starts now.",
            "breakCompletedBody1": "Your next NanaFlow is waiting.",
            "breakCompletedBody2": "Feeling motivated? Great!",
            "breakCompletedBody3": "Let's get back to work.",
            "breakCompletedBody4": "Let's get things done.",
            "breakCompletedBody5": "Come on. Let's do it!",
            "breakCompletedBody6": "Time to get back to NanaFlow.",
            "breakCompletedBody7": "Back to productivity! You're ready.",
            "breakCompletedBody8": "Let's refocus and get started.",
            "breakCompletedBody9": "Back to NanaFlow. Let's go.",
            "breakCompletedBody10": "You're all set to dive back in.",
            "已完成的专注会话": "Completed focus session",
            "未完成的专注会话": "Incomplete focus session",
            "无法保存设置：%@": "Unable to save settings: %@",
            "无法保存会话记录：%@": "Unable to save session history: %@",
            "无法保存计时状态：%@": "Unable to save timer state: %@",
            "无法保存标签：%@": "Unable to save tags: %@",
            "无法同步会话记录：%@": "Unable to sync session history: %@",
            "无法同步计时器：%@": "Unable to sync timer: %@",
            "录制快捷键": "Record shortcut",
            "输入快捷键…": "Enter shortcut…",
            "新Fullscreen窗口": "New Fullscreen Window",
            "文件": "File",
            "全部关闭": "Close All",
            "完成": "Done",
            "使用 NanaFlow 保持专注": "Stay focused with NanaFlow",
        ]

        for (key, value) in expected {
            XCTAssertEqual(
                englishBundle.localizedString(forKey: key, value: nil, table: "Localizable"),
                value,
                key
            )
        }
    }

    func testBackgroundAndSystemDynamicStringsUseLocalization() throws {
        let repositoryURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let notification = try String(
            contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFocus/SessionNotificationScheduler.swift"),
            encoding: .utf8
        )
        let timer = try String(
            contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFocus/TimerController.swift"),
            encoding: .utf8
        )
        let menu = try String(
            contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFocus/TimerOptionsMenuContent.swift"),
            encoding: .utf8
        )
        let calendar = try String(
            contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFocus/FocusSessionCalendarRecorder.swift"),
            encoding: .utf8
        )
        let recorder = try String(
            contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFocus/KeyboardShortcutRecorder.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(notification.contains("String(localized: \"开始\")"))
        XCTAssertTrue(notification.contains("String(localized: \"%@ 在你的黑名单上\")"))
        XCTAssertTrue(notification.contains("localized(\"flowCompletedTitle\\(index)\")"))
        XCTAssertTrue(notification.contains("localized(\"breakCompletedTitle\\(index)\")"))
        XCTAssertTrue(notification.contains("NSLocalizedString(key, bundle: Bundle(for: TimerController.self)"))
        XCTAssertTrue(timer.contains("String(localized: \"无法保存设置：%@\")"))
        XCTAssertTrue(timer.contains("String(localized: \"无法同步计时器：%@\")"))
        XCTAssertTrue(menu.contains("Button(phaseSwitchTitle)"))
        XCTAssertTrue(calendar.contains("String(localized: \"已完成的专注会话\")"))
        XCTAssertTrue(recorder.contains("String(localized: \"录制快捷键\")"))
        XCTAssertTrue(recorder.contains("String(localized: \"输入快捷键…\")"))
    }

    func testHideTimerWindowLeavesVisibleAuxiliaryWindowAlone() {
        let fallbackTimerWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 272),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        fallbackTimerWindow.animationBehavior = .none
        fallbackTimerWindow.isReleasedWhenClosed = false
        fallbackTimerWindow.identifier = NSUserInterfaceItemIdentifier("timer")
        fallbackTimerWindow.title = "NanaFlow"
        let timerWindow = AppWindowActivation.timerWindow ?? fallbackTimerWindow
        let timerWasVisible = timerWindow.isVisible
        let auxiliaryWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 450),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        auxiliaryWindow.animationBehavior = .none
        auxiliaryWindow.isReleasedWhenClosed = false
        auxiliaryWindow.title = "统计"
        defer {
            if timerWindow === fallbackTimerWindow {
                fallbackTimerWindow.orderOut(nil)
            } else if timerWasVisible {
                timerWindow.orderFront(nil)
            }
            auxiliaryWindow.orderOut(nil)
        }

        timerWindow.orderFront(nil)
        auxiliaryWindow.orderFront(nil)
        AppWindowActivation.hideTimerWindow()

        XCTAssertFalse(timerWindow.isVisible)
        XCTAssertTrue(auxiliaryWindow.isVisible)
    }

    func testPostLaunchStartsShareTimerWindowPolicy() throws {
        let repositoryURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFocus/TimerController.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(source.contains("private func startEngine(at date: Date)"))
        XCTAssertTrue(source.contains("} else {\n            startEngine(at: date)\n        }\n        persist()"))
        XCTAssertTrue(source.contains("guard shouldStart else { return }\n        startEngine(at: date)"))
        XCTAssertTrue(source.contains("if preferences.hideWindowWhenTimerStarts {\n            AppWindowActivation.hideTimerWindow()"))
    }

    func testAppReopenRestoresFlowsMainTimerWindow() throws {
        let repositoryURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFocus/SessionNotificationScheduler.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(source.contains("applicationShouldHandleReopen"))
        XCTAssertTrue(source.contains("if !flag"))
        XCTAssertTrue(source.contains("AppWindowActivation.bringToFront(title: \"NanaFlow\")"))
    }

    func testFileMenuConfigurationUsesLocalizedTitles() throws {
        let repositoryURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFocus/SessionNotificationScheduler.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(source.contains("String(localized: \"文件\")"))
        XCTAssertTrue(source.contains("String(localized: \"新Fullscreen窗口\")"))
        XCTAssertTrue(source.contains("String(localized: \"关闭\")"))
        XCTAssertTrue(source.contains("String(localized: \"全部关闭\")"))
    }

    func testFileMenuCreatesFlowsDedicatedFullscreenWindow() throws {
        let repositoryURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFocus/NanaFlowCommands.swift"),
            encoding: .utf8
        )
        let timerSource = try String(
            contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFocus/TimerView.swift"),
            encoding: .utf8
        )
        let delegateSource = try String(
            contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFocus/SessionNotificationScheduler.swift"),
            encoding: .utf8
        )
        let appSource = try String(
            contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFocus/NanaFocusApp.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(source.contains("CommandGroup(replacing: .newItem)"))
        XCTAssertTrue(source.contains("Button(\"新Fullscreen窗口\")"))
        XCTAssertTrue(source.contains(
            "FullscreenBreakWindowController.shared.show(\n                    controller: TimerController.shared,\n                    manuallyTriggered: true"
        ))
        XCTAssertFalse(source.contains("showMiniTimer"))
        XCTAssertFalse(source.contains("CommandGroup(after: .appSettings)"))
        XCTAssertFalse(appSource.contains("Settings {"))
        XCTAssertFalse(timerSource.contains("publisher(for: .showMiniTimer)"))
        XCTAssertFalse(timerSource.contains("keyWindow?.orderOut"))
        XCTAssertTrue(timerSource.contains("NSApplication.shared.keyWindow?.close()"))
        XCTAssertFalse(timerSource.contains("window.styleMask.formUnion"))
        XCTAssertTrue(appSource.contains(".windowStyle(.plain)\n        .commands"))
        XCTAssertTrue(timerSource.contains("window.setAccessibilitySubrole(.standardWindow)"))
        XCTAssertTrue(delegateSource.contains("configureFileMenuCommands()"))
        XCTAssertTrue(delegateSource.contains("#selector(showFullscreenWindow(_:))"))
        XCTAssertTrue(delegateSource.contains(
            "FullscreenBreakWindowController.shared.show(\n            controller: TimerController.shared,\n            manuallyTriggered: true"
        ))
        XCTAssertFalse(delegateSource.contains("showMiniTimerWindow"))
        XCTAssertTrue(delegateSource.contains("#selector(closeKeyWindow(_:))"))
        XCTAssertTrue(delegateSource.contains("#selector(closeAllWindows(_:))"))
    }

    func testWindowMenuDeclaresFlowsWindowListInsteadOfEverySwiftUIScene() throws {
        let repositoryURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFocus/NanaFlowCommands.swift"),
            encoding: .utf8
        )
        let appSource = try String(
            contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFocus/NanaFocusApp.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(source.contains("CommandGroup(replacing: .singleWindowList)"))
        for title in ["Welcome", "Notification Alert", "Calendar Alert", "Calendar Chooser"] {
            XCTAssertTrue(source.contains("\"\(title)\""), "Missing Flow window item: \(title)")
        }
        for removedTitle in ["About", "Pro Upgrade", "How It Works"] {
            XCTAssertFalse(source.contains("\"\(removedTitle)\""))
        }
        for NanaFlowOnlyScene in ["应用与网页阻断器", "标签", "自定义时长"] {
            XCTAssertFalse(source.contains("Button(\"\(NanaFlowOnlyScene)\")"))
        }
        XCTAssertEqual(appSource.components(separatedBy: ".commandsRemoved()").count - 1, 4)
        XCTAssertFalse(appSource.contains("Window(\"自定义时长\""))
        XCTAssertTrue(source.contains("CommandGroup(after: .windowList)"))
        XCTAssertTrue(source.contains("windowButton(\"NanaFlow\", id: \"timer\""))
    }

    func testStatusItemUsesFlowsClickModelAndSettingsStayInTheMainWindow() throws {
        let repositoryURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let appSource = try String(
            contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFocus/NanaFocusApp.swift"),
            encoding: .utf8
        )
        let timerSource = try String(
            contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFocus/TimerView.swift"),
            encoding: .utf8
        )
        let commandsSource = try String(
            contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFocus/NanaFlowCommands.swift"),
            encoding: .utf8
        )
        let hotkeySource = try String(
            contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFocus/GlobalHotkeyMonitor.swift"),
            encoding: .utf8
        )

        XCTAssertFalse(appSource.contains("SettingsLink"))
        XCTAssertFalse(appSource.contains("MenuBarExtra"))
        XCTAssertTrue(appSource.contains("button.sendAction(on: [.leftMouseUp, .rightMouseUp])"))
        XCTAssertTrue(appSource.contains("case .showMenu:\n            showMenu()"))
        XCTAssertFalse(appSource.contains("circle.righthalf.filled"))
        XCTAssertTrue(appSource.contains("? \"隐藏计时器\" : \"显示计时器\""))
        XCTAssertTrue(appSource.contains("menu.addItem(item(\"显示统计\""))
        XCTAssertTrue(appSource.contains("systemImage: \"chart.bar\""))
        XCTAssertFalse(appSource.contains("显示迷你计时器"))
        XCTAssertFalse(appSource.contains("关闭迷你计时器"))
        XCTAssertTrue(timerSource.contains("publisher(for: .showSettings)"))
        XCTAssertTrue(timerSource.contains("page = .settings"))
        XCTAssertFalse(commandsSource.contains("CommandGroup(replacing: .appSettings)"))
        XCTAssertFalse(commandsSource.contains("Button(\"设置…\")"))
        XCTAssertTrue(appSource.contains("GlobalHotkeyMonitor.shared.configure(enabled: configuration.enabled"))
        XCTAssertTrue(hotkeySource.contains("NSEvent.addLocalMonitorForEvents"))
        XCTAssertTrue(hotkeySource.contains("case let .global(action)"))
        XCTAssertTrue(hotkeySource.contains("case .resetCycle: controller.resetCycle()"))
        XCTAssertTrue(hotkeySource.contains("NotificationCenter.default.post(name: .showSettings"))
    }

    func testFlowSurfaceDoesNotExposeNanaFocusMiniTimer() throws {
        let repositoryURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let appSource = try String(
            contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFocus/NanaFocusApp.swift"),
            encoding: .utf8
        )
        let timerSource = try String(
            contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFocus/TimerView.swift"),
            encoding: .utf8
        )
        let commandsSource = try String(
            contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFocus/NanaFlowCommands.swift"),
            encoding: .utf8
        )
        let projectSource = try String(
            contentsOf: repositoryURL.appendingPathComponent("NanaFlow.xcodeproj/project.pbxproj"),
            encoding: .utf8
        )

        XCTAssertFalse(appSource.contains("Window(\"Mini\""))
        XCTAssertFalse(appSource.contains("显示迷你计时器"))
        XCTAssertFalse(appSource.contains("关闭迷你计时器"))
        XCTAssertFalse(appSource.contains("showMiniTimer"))
        XCTAssertFalse(timerSource.contains("showMiniTimer"))
        XCTAssertFalse(commandsSource.contains("windowButton(\"Mini\""))
        XCTAssertFalse(projectSource.contains("MiniTimerView.swift"))
    }

    func testMainWindowConfiguresTileableStandardChromeWithoutGrowingOuterFrame() throws {
        let repositoryURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let timerSource = try String(
            contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFocus/TimerView.swift"),
            encoding: .utf8
        )
        let appSource = try String(
            contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFocus/NanaFocusApp.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(timerSource.contains("NSHashTable<NSWindow>.weakObjects()"))
        XCTAssertTrue(timerSource.contains("guard !Self.configuredWindows.contains(window) else { return }"))
        XCTAssertTrue(timerSource.contains("Self.configuredWindows.add(window)"))
        XCTAssertTrue(timerSource.contains("DispatchQueue.main.async"))
        XCTAssertTrue(timerSource.contains("[.titled, .resizable, .fullSizeContentView]"))
        XCTAssertTrue(timerSource.contains(
            ".frame(width: 380, height: TimerVisualMetrics.windowContentHeight, alignment: .top)"
        ))
        XCTAssertTrue(timerSource.contains("window.titlebarAppearsTransparent = true"))
        XCTAssertTrue(timerSource.contains("window.standardWindowButton(.zoomButton)?.isEnabled = false"))
        XCTAssertTrue(timerSource.contains(".ignoresSafeArea()"))
        XCTAssertTrue(appSource.contains(".windowResizability(.contentMinSize)\n        .windowStyle(.plain)"))
        XCTAssertFalse(appSource.contains(".windowResizability(.automatic)\n        .windowStyle(.plain)"))
    }

    func testCompactProductSurfaceUsesSingleTimerWindow() throws {
        let repositoryURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let appSource = try String(
            contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFocus/NanaFocusApp.swift"),
            encoding: .utf8
        )

        XCTAssertFalse(appSource.contains("Window(\"统计\", id: \"statistics\")"))
        XCTAssertFalse(appSource.contains("Window(\"应用与网页阻断器\", id: \"blocker\")"))
        XCTAssertFalse(appSource.contains("Window(\"标签\", id: \"tags\")"))

        let timerSource = try String(
            contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFocus/TimerView.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(timerSource.contains("case .statistics:"))
        XCTAssertTrue(timerSource.contains("StatisticsView(controller: controller)"))
        XCTAssertTrue(timerSource.contains("publisher(for: .showStatistics)"))
        XCTAssertFalse(timerSource.contains("case .blocker:"))
        XCTAssertFalse(timerSource.contains("case .tags:"))
        XCTAssertFalse(timerSource.contains("Button(\"应用与网页阻断器\")"))
    }

    func testMainTimerMatchesFlowLayoutContract() {
        XCTAssertEqual(TimerVisualMetrics.windowCornerRadius, 26)
        XCTAssertEqual(TimerVisualMetrics.titleFontSize, 20)
        XCTAssertEqual(TimerVisualMetrics.timerFontSize, 70)
        XCTAssertEqual(TimerVisualMetrics.timerKerning, -1.5)
        XCTAssertEqual(TimerVisualMetrics.titleCenterY, 60.5)
        XCTAssertEqual(TimerVisualMetrics.timerCenterY, 120)
        XCTAssertEqual(TimerVisualMetrics.cycleCenterY, 168.5)
        XCTAssertEqual(TimerVisualMetrics.primaryButtonCenterY, 220)
        XCTAssertEqual(TimerVisualMetrics.primaryButtonDiameter, 42)
        XCTAssertEqual(TimerVisualMetrics.closeSymbolSize, 17)
        XCTAssertEqual(TimerVisualMetrics.toolbarControlDiameter, 29)
        XCTAssertEqual(TimerVisualMetrics.skipSymbolSize, 20.5)
        XCTAssertEqual(TimerVisualMetrics.resetSymbolSize, 19)
        XCTAssertEqual(TimerVisualMetrics.statisticsSymbolSize, 20)
        XCTAssertEqual(TimerVisualMetrics.menuSymbolSize, 20)
        XCTAssertEqual(TimerVisualMetrics.playSymbolSize, 25)
        XCTAssertEqual(TimerVisualMetrics.pauseSymbolSize, 22)
        XCTAssertEqual(TimerVisualMetrics.closeControlX, 28.5)
        XCTAssertEqual(TimerVisualMetrics.resetControlX, 286)
        XCTAssertEqual(TimerVisualMetrics.statisticsControlX, 318.5)
        XCTAssertEqual(TimerVisualMetrics.menuControlX, 351.5)
        XCTAssertEqual(TimerVisualMetrics.toolbarCenterY, 26)
        XCTAssertEqual(TimerVisualMetrics.activeIndicatorWidth, 27)
        XCTAssertEqual(TimerVisualMetrics.indicatorDiameter, 12)
        XCTAssertEqual(TimerVisualMetrics.indicatorSpacing, 5)
        XCTAssertEqual(TimerVisualMetrics.inactiveIndicatorOpacity, 0.23)
        XCTAssertEqual(TimerVisualMetrics.toolbarFocusOpacity, 1)
        XCTAssertEqual(TimerVisualMetrics.closeFocusOpacity, 0.42)
        XCTAssertEqual(TimerVisualMetrics.windowContentHeight, 240)
        XCTAssertTrue(TimerVisualMetrics.showsSkipButton(for: .shortBreak))
        XCTAssertFalse(TimerVisualMetrics.showsSkipButton(for: .focus))
        XCTAssertEqual(FlowPalette.windowRed, 248.0 / 255.0, accuracy: 0.0001)
        XCTAssertEqual(FlowPalette.windowGreen, 249.0 / 255.0, accuracy: 0.0001)
        XCTAssertEqual(FlowPalette.windowBlue, 250.0 / 255.0, accuracy: 0.0001)
        XCTAssertEqual(FlowPalette.focusRed, 62.0 / 255.0, accuracy: 0.0001)
        XCTAssertEqual(FlowPalette.focusGreen, 146.0 / 255.0, accuracy: 0.0001)
        XCTAssertEqual(FlowPalette.focusBlue, 122.0 / 255.0, accuracy: 0.0001)
        XCTAssertEqual(FlowPalette.primaryButtonRed, 223.0 / 255.0, accuracy: 0.0001)
        XCTAssertEqual(FlowPalette.primaryButtonGreen, 236.0 / 255.0, accuracy: 0.0001)
        XCTAssertEqual(FlowPalette.primaryButtonBlue, 232.0 / 255.0, accuracy: 0.0001)
        XCTAssertEqual(FlowPalette.compactAccentRed, 47.0 / 255.0, accuracy: 0.0001)
        XCTAssertEqual(FlowPalette.compactAccentGreen, 123.0 / 255.0, accuracy: 0.0001)
        XCTAssertEqual(FlowPalette.compactAccentBlue, 103.0 / 255.0, accuracy: 0.0001)
        XCTAssertEqual(FlowPalette.breakRed, 51.0 / 255.0, accuracy: 0.0001)
        XCTAssertEqual(FlowPalette.breakGreen, 124.0 / 255.0, accuracy: 0.0001)
        XCTAssertEqual(FlowPalette.breakBlue, 104.0 / 255.0, accuracy: 0.0001)
        XCTAssertEqual(SettingsVisualMetrics.cardOverlayOpacity, 0.024, accuracy: 0.0001)
        XCTAssertEqual(SettingsVisualMetrics.scrollIndicatorTrailingInset, 12)
        XCTAssertEqual(SettingsVisualMetrics.contentOffsetY, 3)
        XCTAssertEqual(SettingsVisualMetrics.bottomPadding, 5.5)
        XCTAssertEqual(BlockerVisualMetrics.segmentWidth, 260)
        XCTAssertEqual(BlockerVisualMetrics.segmentHeight, 28)
        XCTAssertEqual(BlockerVisualMetrics.headerOffsetY, -5)
        XCTAssertEqual(WelcomeVisualMetrics.iconImageSize, 155)
        XCTAssertEqual(WelcomeVisualMetrics.iconTopPadding, 48)
        XCTAssertEqual(WelcomeVisualMetrics.backgroundOffsetY, -80)
        XCTAssertEqual(AboutVisualMetrics.iconImageSize, 62)
        XCTAssertEqual(AboutVisualMetrics.contentWidth, 380)
        XCTAssertEqual(AboutVisualMetrics.contentHeight, 272)
        XCTAssertEqual(AboutVisualMetrics.contentOffsetY, 0)
        XCTAssertEqual(HelpVisualMetrics.contentHeight, 560)
        XCTAssertEqual(HelpVisualMetrics.introBottomPadding, 45)
        XCTAssertEqual(HelpVisualMetrics.stepBottomPadding, 30)
        XCTAssertEqual(HelpVisualMetrics.finalStepBottomPadding, 20)
        XCTAssertEqual(HelpVisualMetrics.stepCircleSize, 27)
        XCTAssertEqual(HelpVisualMetrics.stepSpacing, 22)
        XCTAssertEqual(HelpVisualMetrics.closingOffsetY, -11)
        XCTAssertEqual(StatisticsVisualMetrics.windowWidth, 380)
        XCTAssertEqual(StatisticsVisualMetrics.contentHeight, 240)
        XCTAssertEqual(StatisticsVisualMetrics.headerHeight, 49)
        XCTAssertEqual(StatisticsVisualMetrics.periodSwitcherHeight, 42)
        XCTAssertEqual(StatisticsVisualMetrics.sessionListHorizontalInset, 8)
        XCTAssertEqual(SessionEditVisualMetrics.width, 470)
        XCTAssertEqual(SessionEditVisualMetrics.height, 410)
        XCTAssertEqual(SessionListMenuVisualMetrics.addIcon, "plus")
        XCTAssertEqual(SessionListMenuVisualMetrics.incompleteIcon, "eye")
        XCTAssertEqual(SessionListMenuVisualMetrics.exportIcon, "square.and.arrow.up")
        XCTAssertEqual(SessionListMenuVisualMetrics.resetIcon, "trash")
        XCTAssertEqual(SessionListMenuVisualMetrics.resetTitle, "重置统计数据")
        XCTAssertEqual(SessionListMenuVisualMetrics.csvTitle, "CSV...")
        XCTAssertEqual(SessionListMenuVisualMetrics.textTitle, "Text...")
        XCTAssertEqual(StatisticsVisualMetrics.periodPickerWidth, 300)
        XCTAssertEqual(StatisticsVisualMetrics.periodPickerHeight, 32)
        XCTAssertEqual(StatisticsVisualMetrics.periodPickerCornerRadius, 10)
        XCTAssertEqual(StatisticsVisualMetrics.selectedPeriodOpacity, 1, accuracy: 0.0001)
        XCTAssertEqual(StatisticsVisualMetrics.chartHeight, 149)
        XCTAssertEqual(StatisticsVisualMetrics.chartTrackHeight, 105)
        XCTAssertEqual(StatisticsVisualMetrics.navigationButtonDiameter, 31)
        XCTAssertEqual(StatisticsVisualMetrics.periodTitleWidth, 258)
    }

    func testStatisticsUsesTheMainWindowContentHeight() {
        XCTAssertEqual(
            StatisticsVisualMetrics.contentHeight,
            TimerVisualMetrics.windowContentHeight
        )
        XCTAssertEqual(
            StatisticsVisualMetrics.headerHeight
                + StatisticsVisualMetrics.periodSwitcherHeight
                + StatisticsVisualMetrics.chartHeight,
            TimerVisualMetrics.windowContentHeight
        )
    }

    func testMainTimerUsesThePhosphorIconsSelectedInTheDesign() throws {
        let repositoryURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFocus/TimerView.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(source.contains("Image(controller.engine.state.isRunning ? \"phosphor-pause\" : \"phosphor-play-fill\")"))
        XCTAssertTrue(source.contains("Image(\"phosphor-x-circle-fill\")"))
        XCTAssertTrue(source.contains("Image(\"phosphor-arrow-counter-clockwise\")"))
        XCTAssertTrue(source.contains("Image(\"phosphor-chart-bar\")"))
        XCTAssertTrue(source.contains("static let assetName = \"phosphor-dots-three-vertical-bold\""))
        XCTAssertTrue(source.contains("size: TimerVisualMetrics.skipSymbolSize"))
        XCTAssertTrue(source.contains("width: TimerVisualMetrics.resetSymbolSize"))
        XCTAssertTrue(source.contains("width: TimerVisualMetrics.statisticsSymbolSize"))
        XCTAssertFalse(source.contains("Image(systemName: \"arrow.counterclockwise\")"))
        XCTAssertFalse(source.contains("Image(systemName: \"chart.bar\")"))
        XCTAssertTrue(source.contains("TimerMenuIcon(foregroundColor: toolbarForegroundColor)\n                    .allowsHitTesting(false)"))
        XCTAssertFalse(source.contains("TimerMenuIcon(foregroundColor: toolbarForegroundColor)\n                    .offset(y: 4)"))

        let assetRoot = repositoryURL.appendingPathComponent("Sources/NanaFocus/TimerIcons.xcassets")
        for assetName in [
            "phosphor-x-circle-fill",
            "phosphor-arrow-counter-clockwise",
            "phosphor-chart-bar",
            "phosphor-dots-three-vertical-bold",
            "phosphor-play-fill",
            "phosphor-pause",
        ] {
            XCTAssertTrue(
                FileManager.default.fileExists(
                    atPath: assetRoot.appendingPathComponent("\(assetName).imageset/\(assetName).svg").path
                ),
                "Missing selected Phosphor asset: \(assetName)"
            )
        }
    }

    func testMainToolbarVisualRendersAtFlowSize() throws {
        let controller = makeController(engine: TimerEngine(
            configuration: .standard,
            state: TimerState(
                phase: .shortBreak,
                cycleIndex: 0,
                remainingWhenPaused: 5 * 60,
                endDate: nil,
                startedAt: nil
            )
        ))
        let renderer = ImageRenderer(content: TimerView(
            controller: controller,
            initiallyShowsToolbar: true
        ))
        renderer.proposedSize = ProposedViewSize(width: 380, height: 272)

        let image = try XCTUnwrap(renderer.nsImage)
        XCTAssertEqual(image.size, NSSize(width: 380, height: TimerVisualMetrics.windowContentHeight))
        attach(image, name: "nanaflow-main-break-toolbar-polished")
    }

    func testCycleCelebrationMatchesFlowsParticleContract() {
        XCTAssertEqual(CycleCelebrationView.particleCount, 119)
        XCTAssertEqual(CycleCelebrationView.animationDuration, 1.5)
        XCTAssertEqual(CycleCelebrationView.particleSizeRange, 3 ... 6)
        XCTAssertEqual(CycleCelebrationView.particleOpacityRange, 0.1 ... 0.3)
        XCTAssertEqual(CycleCelebrationView.particleDistanceRange, 20 ... 220)
    }

    func testSettingsVolumeControlMatchesFlowsRangeAndPercentage() {
        XCTAssertEqual(SettingsVolumeContract.range, 0 ... 2)
        XCTAssertEqual(SettingsVolumeContract.percentage(for: 0), 0)
        XCTAssertEqual(SettingsVolumeContract.percentage(for: 1), 50)
        XCTAssertEqual(SettingsVolumeContract.percentage(for: 2), 100)
    }

    func testSettingsVolumeControlRendersAtFlowsCompactRowSize() throws {
        let size = NSSize(width: 340, height: 41)
        let host = NSHostingView(rootView: SettingsVolumeView(volume: .constant(1))
            .frame(width: 340, height: 41)
            .background(FlowPalette.window))
        host.frame = NSRect(origin: .zero, size: size)
        let window = NSWindow(
            contentRect: host.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.animationBehavior = .none
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.orderFront(nil)
        defer {
            window.orderOut(nil)
            window.contentView = nil
        }

        host.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)

        let image = NSImage(size: size)
        image.addRepresentation(bitmap)
        XCTAssertEqual(image.size, size)
        attach(image, name: "settings-volume-control")
    }

    func testCycleCelebrationRendersWhiteParticlesOverTheLongBreak() throws {
        var isPresented = true
        let size = NSSize(width: 380, height: TimerVisualMetrics.windowContentHeight)
        let host = NSHostingView(rootView: ZStack {
            FlowPalette.breakBackground
            CycleCelebrationView(
                isPresented: Binding(
                    get: { isPresented },
                    set: { isPresented = $0 }
                )
            )
        }.frame(width: size.width, height: size.height))
        host.frame = NSRect(origin: .zero, size: size)
        let window = NSWindow(
            contentRect: host.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.animationBehavior = .none
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.orderFront(nil)
        defer {
            window.orderOut(nil)
            window.contentView = nil
        }

        RunLoop.main.run(until: Date().addingTimeInterval(0.25))
        host.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)

        let background = try XCTUnwrap(bitmap.colorAt(x: 0, y: 0)?.usingColorSpace(.deviceRGB))
        var whiteParticleSamples = 0
        var occupiedQuadrants = Set<Int>()
        for x in stride(from: 0, to: bitmap.pixelsWide, by: 4) {
            for y in stride(from: 0, to: bitmap.pixelsHigh, by: 4) {
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { continue }
                if color.redComponent > background.redComponent + 0.01,
                   color.greenComponent > background.greenComponent + 0.01,
                   color.blueComponent > background.blueComponent + 0.01 {
                    whiteParticleSamples += 1
                    occupiedQuadrants.insert(
                        (x < bitmap.pixelsWide / 2 ? 0 : 1)
                            + (y < bitmap.pixelsHigh / 2 ? 0 : 2)
                    )
                }
            }
        }

        XCTAssertGreaterThan(whiteParticleSamples, 5)
        XCTAssertEqual(occupiedQuadrants, Set(0 ... 3))
        let image = NSImage(size: size)
        image.addRepresentation(bitmap)
        attach(image, name: "cycle-celebration")
    }

    func testCommitmentModeDisablesEveryFlowControlThatCouldEscapeIt() throws {
        let repositoryURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sources = try [
            "TimerView.swift",
            "TimerSettingsView.swift",
            "NanaFocusApp.swift",
        ].map {
            try String(
                contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFocus/\($0)"),
                encoding: .utf8
            )
        }

        XCTAssertEqual(
            sources.reduce(0) { $0 + $1.components(separatedBy: ".disabled(controller.isCommittedFocus)").count - 1 },
            3
        )
    }

    func testCustomDurationsUseFlowsEmbeddedMainWindowRoute() throws {
        let repositoryURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let menuSource = try String(
            contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFocus/TimerOptionsMenuContent.swift"),
            encoding: .utf8
        )

        XCTAssertEqual(CustomDurationContract.title, "自定义持续时间")
        XCTAssertEqual(CustomDurationContract.explanation, "为您的 NanaFlows 和休息设置自定义持续时间。")
        XCTAssertFalse(menuSource.contains("openWindow(id: \"custom-durations\")"))

        let renderer = ImageRenderer(content: CustomDurationView(controller: makeController()))
        renderer.proposedSize = ProposedViewSize(width: 380, height: 272)
        XCTAssertEqual(renderer.nsImage?.size, NSSize(width: 380, height: 272))
    }

    func testHowItWorksUsesFlowsObservedLongBreakPunctuation() throws {
        let repositoryURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFocus/HelpViews.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(source.contains("每四个休息时间都是一个较长的，更具恢复性的30分钟休息时间。"))
        XCTAssertFalse(source.contains("每四个休息时间都是一个较长的、更具恢复性的"))
    }

    func testCoreTimerMenuKeepsOnlyLockedCompactActions() throws {
        let repositoryURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let menuSource = try String(
            contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFocus/TimerOptionsMenuContent.swift"),
            encoding: .utf8
        )
        let timerSource = try String(
            contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFocus/TimerView.swift"),
            encoding: .utf8
        )

        XCTAssertFalse(menuSource.contains("Button(\"管理标签\")"))
        XCTAssertFalse(menuSource.contains("Menu(\"标签\")"))
        XCTAssertTrue(menuSource.contains("Button(\"计时设置\""))
        XCTAssertTrue(menuSource.contains("Button(phaseSwitchTitle"))
        XCTAssertTrue(menuSource.contains("Button(\"统计\""))
        XCTAssertTrue(menuSource.contains("Button(\"设置…\""))
        XCTAssertTrue(menuSource.contains("Button(\"关于 NanaFlow\""))
        XCTAssertFalse(menuSource.contains("编辑会话名称"))
        XCTAssertFalse(menuSource.contains("定时器同步"))
        XCTAssertFalse(timerSource.contains("TextField(\"标题\", text: $titleDraft)"))
    }

    func testMainMenuUsesDirectActionsInsteadOfNestedConfigurationMenus() throws {
        let repositoryURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFocus/TimerOptionsMenuContent.swift"),
            encoding: .utf8
        )

        XCTAssertFalse(source.contains("✓ "))
        XCTAssertFalse(source.contains("Toggle("))
        XCTAssertFalse(source.contains("Menu("))
        XCTAssertTrue(source.contains("controller.skip()"))
    }

    func testMainToolbarMatchesFlowsRestartAndSkipActions() throws {
        let repositoryURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let timerSource = try String(
            contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFocus/TimerView.swift"),
            encoding: .utf8
        )
        let fullscreenSource = try String(
            contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFocus/FullscreenBreakView.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(timerSource.contains("Button { controller.resetCycle() }"))
        XCTAssertTrue(timerSource.contains(".accessibilityLabel(\"重新开始周期\")"))
        XCTAssertTrue(timerSource.contains(".accessibilityLabel(\"跳过休息时间\")"))
        XCTAssertFalse(timerSource.contains("Button { controller.previous() }"))
        XCTAssertFalse(timerSource.contains(".accessibilityLabel(\"跳过休息\")"))
        XCTAssertTrue(fullscreenSource.contains("label: String(localized: \"跳过休息时间\")"))
    }

    func testRunningMainTimerUsesFlowsStopAccessibilityLabel() throws {
        let repositoryURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let timerSource = try String(
            contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFocus/TimerView.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(timerSource.contains(#".accessibilityLabel(controller.engine.state.isRunning ? "停止" : "开始")"#))
    }

    func testTagAndSessionDeletionUseFlowsConfirmationCopy() throws {
        let repositoryURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let tagSource = try String(
            contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFocus/TagManagementView.swift"),
            encoding: .utf8
        )
        let statisticsSource = try String(
            contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFocus/StatisticsView.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(tagSource.contains("@State private var confirmsDeleteTag = false"))
        XCTAssertTrue(tagSource.contains("selectedTag = tag"))
        XCTAssertTrue(tagSource.contains(#"删除标签 \""#))
        XCTAssertTrue(tagSource.contains("此标签在 1 个会话中使用。该会话将失去此标签。"))
        XCTAssertTrue(tagSource.contains("此标签在 %lld 个会话中使用。这些会话将失去此标签。"))
        XCTAssertTrue(tagSource.contains("此操作不能撤销。"))
        XCTAssertTrue(statisticsSource.contains("您确定要重置您的统计数据吗？"))
        XCTAssertTrue(statisticsSource.contains("你确定要删除此会话吗？"))
        XCTAssertTrue(statisticsSource.contains("完成你的第一次会话，在这里查看详细概览。"))
        XCTAssertFalse(statisticsSource.contains("使用标签对您的统计数据进行分类。"))
    }

    func testTagManagementUsesFlowsOverviewAddAndEditRoutes() throws {
        let repositoryURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFocus/TagManagementView.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(source.contains("private struct TagsOverview"))
        XCTAssertTrue(source.contains("private struct TagEditView"))
        XCTAssertTrue(source.contains("case addTag"))
        XCTAssertTrue(source.contains("case editTag(String)"))
        XCTAssertTrue(source.contains("Text(\"使用标签对会话进行分类和整理。\")"))
        XCTAssertTrue(source.contains("TextField(\"标题\", text: $title)"))
        XCTAssertTrue(source.contains("SessionTagSettings.palette.enumerated()"))
        XCTAssertTrue(source.contains("controller.updateTag(originalName, name: title, colorHex: colorHex)"))
    }

    func testVisibleSessionNounsUseNanaFlowBrand() throws {
        let repositoryURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let statisticsSource = try String(
            contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFocus/StatisticsView.swift"),
            encoding: .utf8
        )
        let widgetSource = try String(
            contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFlowWidget/NanaFlowWidgets.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(statisticsSource.contains(#"\(statistics.totalCount)次"#))
        XCTAssertTrue(statisticsSource.contains(#"case .focus: "NanaFlow""#))
        XCTAssertTrue(statisticsSource.contains(#".accessibilityLabel("统计图表")"#))
        XCTAssertTrue(statisticsSource.contains(#""\(bucket.sessionCount)次""#))
        XCTAssertFalse(statisticsSource.contains(#".accessibilityLabel("显示所有会话")"#))
        XCTAssertFalse(statisticsSource.contains(#"String(localized: "tag_summary_format")"#))
        XCTAssertTrue(widgetSource.contains(#"entry.statisticsUnit == .count ? "NanaFlows" : String(localized: "分钟")"#))
        XCTAssertFalse(ProUnlockedContract.message.hasPrefix("Flow "))
    }

    func testStatisticsBarsExposeConciseHoverDetailsWithoutOpeningAnotherWindow() throws {
        let repositoryURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFocus/StatisticsView.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(source.contains("@State private var hoveredBucketID: Date?"))
        XCTAssertTrue(source.contains(".onHover { isHovered in"))
        XCTAssertTrue(source.contains("statisticsBucketTooltipText(bucket)"))
        XCTAssertTrue(source.contains(".fixedSize(horizontal: true, vertical: false)"))
        XCTAssertFalse(source.contains("@State private var selectedBucketID: Date?"))
        XCTAssertFalse(source.contains("点击固定此数据"))
        XCTAssertFalse(source.contains("Window(\"统计详情\""))
    }

    func testFullscreenBreakUsesDedicatedWindowInsteadOfMutatingMainWindow() throws {
        let repositoryURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let timerSource = try String(
            contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFocus/TimerView.swift"),
            encoding: .utf8
        )
        let controller = makeController()
        controller.skip()

        XCTAssertFalse(timerSource.contains("window.toggleFullScreen(nil)"))
        XCTAssertTrue(timerSource.contains("FullscreenBreakWindowController.shared.show"))
        XCTAssertEqual(FullscreenBreakContract.windowTitle, "Fullscreen")
        XCTAssertTrue(FullscreenBreakContract.usesDedicatedWindow)
        XCTAssertTrue(FullscreenBreakContract.coversCurrentScreen)

        let renderer = ImageRenderer(content: FullscreenBreakView(
            controller: controller,
            onClose: {}
        ))
        renderer.proposedSize = ProposedViewSize(width: 960, height: 540)
        let renderedImage = try XCTUnwrap(renderer.nsImage)
        XCTAssertEqual(renderedImage.size, NSSize(width: 960, height: 540))
        attach(renderedImage, name: "nanaflow-fullscreen-break")

        FullscreenBreakWindowController.shared.show(controller: controller)
        defer { FullscreenBreakWindowController.shared.close() }
        let fullscreenWindow = try XCTUnwrap(FullscreenBreakWindowController.shared.window)
        XCTAssertTrue(fullscreenWindow.isVisible)
        XCTAssertTrue(fullscreenWindow.canBecomeKey)
        XCTAssertEqual(fullscreenWindow.styleMask, [.borderless])
        XCTAssertEqual(fullscreenWindow.frame, fullscreenWindow.screen?.frame)
        XCTAssertFalse(FullscreenBreakWindowController.shared.manuallyTriggered)

        FullscreenBreakWindowController.shared.show(
            controller: controller,
            manuallyTriggered: true
        )
        XCTAssertTrue(FullscreenBreakWindowController.shared.manuallyTriggered)
    }

    func testCompactMainMenuDoesNotExposeRecommendationSurface() throws {
        let repositoryURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFocus/TimerView.swift"),
            encoding: .utf8
        )

        XCTAssertFalse(source.contains("RecommendationMenu"))
        XCTAssertFalse(source.contains("ShareLink"))
    }

    func testSettingsSwitchesExposeFlowLabelsToAccessibility() throws {
        let repositoryURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFocus/TimerSettingsView.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(source.contains(".accessibilityLabel(Text(LocalizedStringKey(title)))"))
    }

    func testSettingsSectionLastRowsDoNotDrawBottomDivider() throws {
        let repositoryURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFocus/TimerSettingsView.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(source.contains("func settingsRow(showsDivider: Bool = true)"))
        XCTAssertEqual(source.components(separatedBy: "showsDivider: false").count - 1, 2)
        XCTAssertTrue(source.contains(".padding(.top, SettingsVisualMetrics.contentOffsetY)"))
        XCTAssertFalse(source.contains(".offset(y: SettingsVisualMetrics.contentOffsetY)"))
    }

    func testCompactSettingsDoesNotExposeSecondaryVolumeRows() throws {
        let repositoryURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFocus/TimerSettingsView.swift"),
            encoding: .utf8
        )

        XCTAssertFalse(source.contains("NotificationVolumeRow"))
        let visibleSettings = try XCTUnwrap(
            source.split(separator: "enum SettingsVisualMetrics", maxSplits: 1).first
        )
        XCTAssertFalse(visibleSettings.contains("SettingsVolumeView(volume:"))
    }

    func testKeyboardShortcutDescriptionsMatchFlowLocalizedResources() throws {
        let repositoryURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFocus/TimerSettingsView.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(source.contains("全局快捷键或系统快捷键是激活的，可以在任何应用程序当前处于焦点时触发。"))
        XCTAssertTrue(source.contains("本地快捷键或特定应用程序快捷键仅在应用程序处于焦点时才激活。"))
        XCTAssertFalse(source.contains("点击按键组合即可重新录制"))
    }

    func testMainTimerRenders() {
        let controller = makeController()
        let renderer = ImageRenderer(content: TimerView(controller: controller))
        renderer.proposedSize = ProposedViewSize(width: 380, height: 272)

        XCTAssertNotNil(renderer.nsImage)
    }

    func testRunningFocusUsesAccentPauseIconAndStableCyclePill() throws {
        let now = Date(timeIntervalSince1970: 10_000)
        let controller = makeController(engine: TimerEngine(
            configuration: .standard,
            state: TimerState(
                phase: .focus,
                cycleIndex: 0,
                remainingWhenPaused: 25 * 60,
                endDate: now.addingTimeInterval(25 * 60 - 20),
                startedAt: now
            )
        ))
        let renderer = ImageRenderer(content: TimerView(controller: controller))
        renderer.proposedSize = ProposedViewSize(width: 380, height: 272)

        XCTAssertNotNil(renderer.nsImage)

        let repositoryURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFocus/TimerView.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(source.contains(".foregroundStyle(primaryButtonForeground)"))
        XCTAssertTrue(source.contains("controller.engine.state.phase == .focus ? FlowPalette.focus : .white"))
        XCTAssertFalse(source.contains("proxy.size.width * controller.progress"))
        XCTAssertTrue(source.contains("width: TimerVisualMetrics.activeIndicatorWidth"))
    }

    func testBreakMenuIconUsesExplicitWhiteForeground() throws {
        XCTAssertEqual(TimerMenuIcon.assetName, "phosphor-dots-three-vertical-bold")
        XCTAssertEqual(TimerMenuIcon.symbolSize, 20)

        let renderer = ImageRenderer(content: ZStack {
            FlowPalette.breakBackground
            TimerMenuIcon(foregroundColor: .white)
        })
        renderer.proposedSize = ProposedViewSize(width: 28, height: 28)

        let image = try XCTUnwrap(renderer.nsImage)
        let tiff = try XCTUnwrap(image.tiffRepresentation)
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: tiff))
        var brightPixelCount = 0
        for y in 0 ..< bitmap.pixelsHigh {
            for x in 0 ..< bitmap.pixelsWide {
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
                if color.redComponent > 0.7, color.greenComponent > 0.7, color.blueComponent > 0.7 {
                    brightPixelCount += 1
                }
            }
        }
        XCTAssertGreaterThan(brightPixelCount, 5)
        attach(image, name: "nanaflow-break-menu-icon")
    }

    func testLongBreakMatchesFlowVisibleContract() throws {
        let controller = makeController(engine: TimerEngine(
            configuration: TimerConfiguration(
                focusDuration: 30 * 60,
                shortBreakDuration: 5 * 60,
                longBreakDuration: 20 * 60,
                sessionsPerCycle: 4
            ),
            state: TimerState(
                phase: .longBreak,
                cycleIndex: 3,
                remainingWhenPaused: 20 * 60,
                endDate: nil,
                startedAt: nil
            )
        ))
        XCTAssertEqual(controller.phaseTitle, "长时间停顿")

        let renderer = ImageRenderer(content: TimerView(controller: controller))
        renderer.proposedSize = ProposedViewSize(width: 380, height: 272)

        let image = try XCTUnwrap(renderer.nsImage)
        let tiff = try XCTUnwrap(image.tiffRepresentation)
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: tiff))
        let background = try XCTUnwrap(bitmap.colorAt(x: 20, y: 120)?.usingColorSpace(.sRGB))
        let shortBreakController = makeController(engine: TimerEngine(
            configuration: controller.engine.configuration,
            state: TimerState(
                phase: .shortBreak,
                cycleIndex: 3,
                remainingWhenPaused: 5 * 60,
                endDate: nil,
                startedAt: nil
            )
        ))
        let shortBreakRenderer = ImageRenderer(content: TimerView(controller: shortBreakController))
        shortBreakRenderer.proposedSize = ProposedViewSize(width: 380, height: 272)
        let shortBreakImage = try XCTUnwrap(shortBreakRenderer.nsImage)
        let shortBreakTIFF = try XCTUnwrap(shortBreakImage.tiffRepresentation)
        let shortBreakBitmap = try XCTUnwrap(NSBitmapImageRep(data: shortBreakTIFF))
        let shortBreakBackground = try XCTUnwrap(shortBreakBitmap.colorAt(x: 20, y: 120)?.usingColorSpace(.sRGB))
        XCTAssertEqual(background.redComponent, shortBreakBackground.redComponent, accuracy: 0.005)
        XCTAssertEqual(background.greenComponent, shortBreakBackground.greenComponent, accuracy: 0.005)
        XCTAssertEqual(background.blueComponent, shortBreakBackground.blueComponent, accuracy: 0.005)
        attach(image, name: "nanaflow-main-long-break")
    }

    func testSettingsRender() {
        let controller = makeController()
        let renderer = ImageRenderer(content: TimerSettingsView(controller: controller, onBack: {}))
        renderer.proposedSize = ProposedViewSize(width: 380, height: 272)

        XCTAssertNotNil(renderer.nsImage)
    }

    func testAboutAndHowItWorksRender() {
        let about = ImageRenderer(content: AboutNanaFlowView())
        about.proposedSize = ProposedViewSize(
            width: AboutVisualMetrics.contentWidth,
            height: AboutVisualMetrics.contentHeight
        )
        let how = ImageRenderer(content: HowNanaFlowWorksView())
        how.proposedSize = ProposedViewSize(width: 400, height: HelpVisualMetrics.contentHeight)

        XCTAssertNotNil(about.nsImage)
        XCTAssertEqual(about.nsImage?.size.width, AboutVisualMetrics.contentWidth)
        XCTAssertEqual(about.nsImage?.size.height, AboutVisualMetrics.contentHeight)
        XCTAssertNotNil(how.nsImage)
    }

    func testAboutAndHelpWindowsMatchFlowsOuterFrameAndTransparentTitleBarContract() throws {
        let repositoryURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let appSource = try String(
            contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFocus/NanaFocusApp.swift"),
            encoding: .utf8
        )
        let helpSource = try String(
            contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFocus/HelpViews.swift"),
            encoding: .utf8
        )

        XCTAssertFalse(appSource.contains("Window(\"About\", id: \"about\")"))
        XCTAssertFalse(appSource.contains("Window(\"How It Works\", id: \"how-it-works\")"))
        XCTAssertTrue(helpSource.contains("25分钟"))
        XCTAssertTrue(helpSource.contains("5分钟休息"))
        XCTAssertTrue(helpSource.contains("重复4次"))
        XCTAssertTrue(helpSource.contains("30分钟休息时间"))
        XCTAssertFalse(helpSource.contains("25 分钟"))
    }

    func testAboutContentMatchesFlowsInformationAndActionHierarchy() throws {
        let repositoryURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFocus/HelpViews.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(source.contains("Text(\"关于 NanaFlow\")"))
        XCTAssertTrue(source.contains("Text(\"专注、休息、继续。\")"))
        XCTAssertTrue(source.contains("Text(\"版本 \\(version)\")"))
        XCTAssertTrue(source.contains("Button(\"完成\", action: onBack)"))
    }

    func testWelcomeRenders() throws {
        let repositoryURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let appSource = try String(
            contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFocus/NanaFocusApp.swift"),
            encoding: .utf8
        )
        let welcomeSource = try String(
            contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFocus/WelcomeView.swift"),
            encoding: .utf8
        )

        XCTAssertNotNil(Bundle.main.url(forResource: "NanaFlowWelcomeBackground", withExtension: "png"))
        XCTAssertTrue(appSource.contains("Window(\"Welcome\", id: \"welcome\")"))
        XCTAssertTrue(welcomeSource.contains("Text(\"欢迎来到NanaFlow\")"))
        XCTAssertFalse(welcomeSource.contains("Text(\"欢迎来到 NanaFlow\")"))
        XCTAssertTrue(welcomeSource.contains(
            "Text(\"NanaFlow将您的工作流划分为具有已定义中断的部分，使您可以轻松保持专注。\")"
        ))
        XCTAssertTrue(welcomeSource.contains(
            ".padding(.top, WelcomeVisualMetrics.iconTopPadding)"
        ))
        XCTAssertFalse(welcomeSource.contains(".ignoresSafeArea()"))
        XCTAssertTrue(welcomeSource.contains(".frame(width: 420, height: 460)"))
        XCTAssertFalse(welcomeSource.contains(".frame(maxHeight: .infinity)"))
        let welcome = ImageRenderer(content: NanaFlowWelcomeView(
            showAtLaunch: .constant(false),
            onDone: {}
        ))
        welcome.proposedSize = ProposedViewSize(width: 420, height: 460)

        XCTAssertNotNil(welcome.nsImage)
    }

    @MainActor
    func testWelcomeNativeWindowBlendsTitlebarWithoutChangingContentLayout() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 460),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.animationBehavior = .none
        window.isReleasedWhenClosed = false
        let originalFrame = window.frame
        window.contentView = NSHostingView(rootView: NanaFlowWelcomeView(
            showAtLaunch: .constant(false),
            onDone: {}
        ))
        window.orderFront(nil)
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        defer {
            window.orderOut(nil)
            window.contentView = nil
        }

        XCTAssertEqual(window.frame.size, originalFrame.size)
        XCTAssertFalse(window.styleMask.contains(.fullSizeContentView))
        XCTAssertEqual(window.titleVisibility, .hidden)
        XCTAssertTrue(window.titlebarAppearsTransparent)
        XCTAssertEqual(window.titlebarSeparatorStyle, .none)
        let windowColor = window.backgroundColor.usingColorSpace(.sRGB)
        XCTAssertEqual(windowColor?.redComponent ?? 0, 1, accuracy: 1.0 / 255.0)
        XCTAssertEqual(windowColor?.greenComponent ?? 0, 1, accuracy: 1.0 / 255.0)
        XCTAssertEqual(windowColor?.blueComponent ?? 0, 1, accuracy: 1.0 / 255.0)
        let titlebarColor = window.standardWindowButton(.closeButton)?.superview?.layer?.backgroundColor
            .flatMap(NSColor.init(cgColor:))?
            .usingColorSpace(.sRGB)
        XCTAssertEqual(titlebarColor?.redComponent ?? 0, 90.0 / 255.0, accuracy: 1.0 / 255.0)
        XCTAssertEqual(titlebarColor?.greenComponent ?? 0, 150.0 / 255.0, accuracy: 1.0 / 255.0)
        XCTAssertEqual(titlebarColor?.blueComponent ?? 0, 144.0 / 255.0, accuracy: 1.0 / 255.0)
        XCTAssertFalse(window.standardWindowButton(.closeButton)?.isHidden ?? true)
        XCTAssertFalse(window.standardWindowButton(.miniaturizeButton)?.isHidden ?? true)
    }

    func testChineseMenuLocalizationIsBundled() {
        XCTAssertNotNil(Bundle.main.url(
            forResource: "Localizable",
            withExtension: "strings",
            subdirectory: nil,
            localization: "zh-Hans"
        ))
        XCTAssertNotNil(Bundle.main.url(
            forResource: "InfoPlist",
            withExtension: "strings",
            subdirectory: nil,
            localization: "zh-Hans"
        ))
    }

    func testAllFlowLanguageRegionsShipCompleteBrandSafeLocalizations() throws {
        let repositoryURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let localizationRoot = repositoryURL.appendingPathComponent("Sources/NanaFocus")
        let expectedLocales = [
            "ca", "de", "en", "es", "fr", "it", "ja", "ko", "nb", "nl",
            "pl", "pt-BR", "pt-PT", "ru", "sv", "tr", "uk", "vi", "zh-Hans", "zh-Hant",
        ]
        let englishURL = localizationRoot
            .appendingPathComponent("en.lproj/Localizable.strings")
        let english = try XCTUnwrap(
            try PropertyListSerialization.propertyList(
                from: Data(contentsOf: englishURL),
                options: [],
                format: nil
            ) as? [String: String]
        )
        let appBundle = Bundle(for: TimerController.self)
        let widgetURL = try XCTUnwrap(
            appBundle.builtInPlugInsURL?.appendingPathComponent("NanaFlowWidget.appex")
        )
        let widgetBundle = try XCTUnwrap(Bundle(url: widgetURL))

        for locale in expectedLocales {
            let localizationURL = localizationRoot
                .appendingPathComponent("\(locale).lproj/Localizable.strings")
            XCTAssertTrue(
                FileManager.default.fileExists(atPath: localizationURL.path),
                "Missing \(locale) localization"
            )
            guard FileManager.default.fileExists(atPath: localizationURL.path) else { continue }

            let localization = try XCTUnwrap(
                try PropertyListSerialization.propertyList(
                    from: Data(contentsOf: localizationURL),
                    options: [],
                    format: nil
                ) as? [String: String],
                locale
            )
            if ["ca", "de", "es", "fr", "it", "ja", "ko", "nb", "nl", "pl", "pt-BR", "pt-PT", "ru", "zh-Hant"].contains(locale) {
                let stringsdictURL = localizationRoot
                    .appendingPathComponent("\(locale).lproj/Localizable.stringsdict")
                let stringsdict = try XCTUnwrap(
                    try PropertyListSerialization.propertyList(
                        from: Data(contentsOf: stringsdictURL),
                        options: [],
                        format: nil
                    ) as? [String: Any]
                )
                let cycle = try XCTUnwrap(stringsdict["cycle_session_count"] as? [String: Any])
                let sessions = try XCTUnwrap(cycle["sessions"] as? [String: String])
                let expected: [String: String]
                switch locale {
                case "ca":
                    expected = ["one": "%lld sessió", "other": "%lld sessions"]
                case "es":
                    expected = ["one": "%lld sesión", "other": "%lld sesiones"]
                case "it":
                    expected = ["one": "%lld sessione", "other": "%lld sessioni"]
                case "pt-BR", "pt-PT":
                    expected = ["one": "%lld sessão", "other": "%lld sessões"]
                case "nl":
                    expected = ["one": "%lld sessie", "other": "%lld sessies"]
                case "nb":
                    expected = ["one": "%lld økt", "other": "%lld økter"]
                case "pl":
                    expected = [
                        "one": "%lld sesja",
                        "few": "%lld sesje",
                        "many": "%lld sesji",
                        "other": "%lld sesji",
                    ]
                case "ru":
                    expected = [
                        "one": "%lld сеанс",
                        "few": "%lld сеанса",
                        "many": "%lld сеансов",
                        "other": "%lld сеанса",
                    ]
                case "ja":
                    expected = ["one": "%lldセッション", "other": "%lldセッション"]
                case "de":
                    expected = ["one": "%lld Session", "other": "%lld Sessions"]
                case "ko":
                    expected = ["one": "%lld개 세션", "other": "%lld개 세션"]
                case "fr":
                    expected = ["one": "%lld session", "other": "%lld sessions"]
                default:
                    expected = ["one": "%lld 個會話", "other": "%lld 個會話"]
                }
                for (category, value) in expected {
                    XCTAssertEqual(sessions[category], value, "\(locale) \(category) plural form")
                }
            }
            if locale != "zh-Hans" {
                XCTAssertEqual(
                    Set(localization.keys),
                    Set(english.keys),
                    "\(locale) must localize every user-facing key"
                )
            }
            if locale != "en" && locale != "zh-Hans" {
                let translatedCount = english.reduce(into: 0) { count, entry in
                    if localization[entry.key] != entry.value { count += 1 }
                }
                if locale == "zh-Hant" {
                    XCTAssertEqual(
                        translatedCount,
                        english.count,
                        "Traditional Chinese must not fall back to English"
                    )
                    XCTAssertEqual(
                        localization["终身使用"],
                        "終身使用",
                        "Traditional Chinese Pro copy must not leak simplified characters"
                    )
                } else if ["ca", "de", "es", "fr", "it", "ja", "ko", "nb", "nl", "pl", "pt-BR", "pt-PT", "ru"].contains(locale) {
                    let intentionallySharedValues: Set<String>
                    switch locale {
                    case "ca":
                        intentionallySharedValues = ["网页", "好", "圆形", "本地", "颜色", "duration_hms_format", "全局", "定时器同步", "一般", "个人", "应用"]
                    case "es":
                        intentionallySharedValues = ["网页", "好", "圆形", "本地", "颜色", "duration_hms_format", "全局", "定时器同步", "一般", "个人", "应用"]
                    case "it":
                        intentionallySharedValues = ["网页", "好", "菜单", "文件", "File", "音量", "duration_hms_format", "定时器同步", "应用", "网站"]
                    case "pt-BR", "pt-PT":
                        intentionallySharedValues = ["网页", "好", "菜单", "圆形", "本地", "音量", "duration_hms_format", "定时器同步", "状态", "全局", "应用", "网站"]
                    case "nl":
                        intentionallySharedValues = ["网页", "Help", "好", "菜单", "帮助", "本地", "音量", "duration_hms_format", "全局", "自动", "竖琴", "定时器同步", "停止", "重置", "升级", "类型", "状态", "应用", "标签", "周", "网站", "筛选"]
                    case "nb":
                        intentionallySharedValues = ["好", "暂停", "本地", "系统", "音量", "duration_hms_format", "全局", "定时器同步", "开始", "类型", "状态", "应用"]
                    case "pl":
                        intentionallySharedValues = ["好", "好的", "菜单", "系统", "开始", "状态"]
                    case "ru":
                        intentionallySharedValues = []
                    case "ja":
                        intentionallySharedValues = ["好"]
                    case "de":
                        intentionallySharedValues = ["网页", "好", "系统", "支持", "升级", "状态", "阶段", "应用", "标签", "筛选", "全局"]
                    case "fr":
                        intentionallySharedValues = [
                            "网页", "好", "菜单", "暂停", "本地", "音量", "风格 1", "打断", "全局",
                            "风格 2", "%lld 分钟", "风格 3", "周期", "风格 4", "通知", "分钟",
                            "支持", "类型", "阶段", "应用", "标签", "网站",
                        ]
                    default:
                        intentionallySharedValues = []
                    }
                    let englishMatches = Set(english.compactMap { entry in
                        localization[entry.key] == entry.value ? entry.key : nil
                    })
                    XCTAssertEqual(
                        englishMatches,
                        intentionallySharedValues,
                        "\(locale) must only retain words that are conventionally identical to English"
                    )
                    if locale == "pl" {
                        XCTAssertEqual(localization["%lld 分钟"], "%lld min")
                        XCTAssertEqual(localization["休息时间"], "Czas przerwy")
                        XCTAssertEqual(localization["统计"], "Statystyki")
                        XCTAssertEqual(localization["建议"], "Poleć aplikację")
                        XCTAssertEqual(localization["启用承诺模式"], "Tryb zobowiązania")
                    } else if locale == "ru" {
                        XCTAssertEqual(localization["%lld 分钟"], "%lld мин")
                        XCTAssertEqual(localization["自动启动NanaFlow会话"], "Автоматически начинать сеансы NanaFlow")
                        XCTAssertEqual(localization["编辑会话名称"], "Редактировать название сеанса")
                        XCTAssertEqual(localization["自定义"], "Настроить…")
                        XCTAssertEqual(localization["升级"], "Перейти на Pro")
                    }
                    if locale == "de" {
                        XCTAssertEqual(
                            localization["终身使用"],
                            "Lebenslanger Zugriff",
                            "German Pro copy must not retain the English Lifetime label"
                        )
                    }
                } else {
                    XCTAssertGreaterThanOrEqual(
                        translatedCount,
                        250,
                        "\(locale) must contain real localized copy instead of an English-only shell"
                    )
                }
            }
            for value in localization.values {
                let withoutNanaFlow = value
                    .replacingOccurrences(of: "NanaFlows", with: "")
                    .replacingOccurrences(of: "NanaFlow", with: "")
                XCTAssertFalse(
                    withoutNanaFlow.contains("Flow"),
                    "\(locale) leaks the source product brand: \(value)"
                )
                if ["ca", "es", "it", "nb", "nl", "pl", "pt-BR", "pt-PT"].contains(locale) {
                    XCTAssertFalse(
                        value.contains(" flow") || value.hasPrefix("flow"),
                        "\(locale) must use the NanaFlow product name instead of a lowercase English flow: \(value)"
                    )
                }
            }
            XCTAssertNotNil(
                appBundle.url(
                    forResource: "Localizable",
                    withExtension: "strings",
                    subdirectory: nil,
                    localization: locale
                ),
                "App bundle is missing \(locale)"
            )
            XCTAssertNotNil(
                widgetBundle.url(
                    forResource: "Localizable",
                    withExtension: "strings",
                    subdirectory: nil,
                    localization: locale
                ),
                "Widget bundle is missing \(locale)"
            )
        }
    }

    func testWelcomeDisplayPolicyShowsFirstLaunchAndRespectsPreference() {
        XCTAssertTrue(WelcomeDisplayPolicy.shouldPresent(hasBeenShown: false, showAtLaunch: false))
        XCTAssertTrue(WelcomeDisplayPolicy.shouldPresent(hasBeenShown: true, showAtLaunch: true))
        XCTAssertFalse(WelcomeDisplayPolicy.shouldPresent(hasBeenShown: true, showAtLaunch: false))
    }

    func testCustomDurationEditorRenders() {
        let renderer = ImageRenderer(content: CustomDurationView(controller: makeController()))
        renderer.proposedSize = ProposedViewSize(width: 360, height: 260)
        XCTAssertNotNil(renderer.nsImage)
    }

    func testStatisticsRender() {
        let controller = makeController()
        let renderer = ImageRenderer(content: StatisticsView(controller: controller))
        renderer.proposedSize = ProposedViewSize(
            width: StatisticsVisualMetrics.windowWidth,
            height: StatisticsVisualMetrics.contentHeight
        )

        XCTAssertNotNil(renderer.nsImage)
    }

    func testAllSessionsRender() {
        let controller = makeController()
        let renderer = ImageRenderer(content: AllSessionsView(controller: controller))
        renderer.proposedSize = ProposedViewSize(
            width: StatisticsVisualMetrics.windowWidth,
            height: StatisticsVisualMetrics.contentHeight
        )

        XCTAssertNotNil(renderer.nsImage)
    }

    func testStatisticsAndAllSessionsRenderWithHistory() throws {
        let end = Date()
        let controller = makeController(
            sessions: [
                FocusSession(
                    id: UUID(),
                    startedAt: end.addingTimeInterval(-20 * 60),
                    endedAt: end,
                    duration: 20 * 60,
                    completed: true,
                    title: "NanaFlow",
                    tag: "工作"
                ),
                FocusSession(
                    id: UUID(),
                    startedAt: end.addingTimeInterval(-10 * 60),
                    endedAt: end,
                    duration: 10 * 60,
                    completed: true,
                    title: "NanaFlow",
                    tag: "学习"
                )
            ]
        )

        let statistics = ImageRenderer(content: StatisticsView(controller: controller))
        statistics.proposedSize = ProposedViewSize(
            width: StatisticsVisualMetrics.windowWidth,
            height: StatisticsVisualMetrics.contentHeight
        )
        let sessions = ImageRenderer(content: AllSessionsView(controller: controller))
        sessions.proposedSize = ProposedViewSize(
            width: StatisticsVisualMetrics.windowWidth,
            height: StatisticsVisualMetrics.contentHeight
        )

        let statisticsImage = try XCTUnwrap(statistics.nsImage)
        let sessionsImage = try XCTUnwrap(sessions.nsImage)
        attach(statisticsImage, name: "nanaflow-statistics-tag-colors")
        attach(sessionsImage, name: "nanaflow-sessions-tag-colors")
    }

    func testAllSessionsUsesFlowsLoadMoreControl() throws {
        let repositoryURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFocus/StatisticsView.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(source.contains("Button(\"载入更多\")"))
        XCTAssertTrue(source.contains("ForEach(visibleSessions)"))
        XCTAssertTrue(source.contains("@AppStorage(\"showIncompleteSessions\")"))
        XCTAssertFalse(source.contains("@State private var showIncomplete = false"))
    }

    func testAllSessionsToolbarMenusHideNativeIndicatorsLikeFlow() throws {
        let repositoryURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFocus/StatisticsView.swift"),
            encoding: .utf8
        )
        let allSessionsSource = try XCTUnwrap(
            source.split(separator: "struct AllSessionsView", maxSplits: 1).last?
                .split(separator: "struct SessionDetailView", maxSplits: 1).first
        )

        XCTAssertEqual(
            allSessionsSource.components(separatedBy: ".menuIndicator(.hidden)").count - 1,
            2
        )
    }

    func testAllSessionsFilterMenuMatchesFlowsSelectionContract() throws {
        let repositoryURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFocus/StatisticsView.swift"),
            encoding: .utf8
        )
        let allSessionsSource = try XCTUnwrap(
            source.split(separator: "struct AllSessionsView", maxSplits: 1).last?
                .split(separator: "struct SessionDetailView", maxSplits: 1).first
        )

        XCTAssertTrue(allSessionsSource.contains("Section(SessionListMenuVisualMetrics.filterTitle)"))
        XCTAssertTrue(allSessionsSource.contains("Toggle(tag, isOn: filterSelectionBinding(for: tag))"))
        XCTAssertTrue(allSessionsSource.contains(
            "Button(SessionListMenuVisualMetrics.clearFilterTitle, systemImage: SessionListMenuVisualMetrics.clearFilterIcon)"
        ))
        XCTAssertFalse(allSessionsSource.contains("Button(\"所有标签\")"))
        XCTAssertFalse(allSessionsSource.contains("Button(\"清除筛选\")"))
    }

    func testAllSessionsExportUsesNonblockingSavePanelAfterMenuDismissal() throws {
        let repositoryURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFocus/StatisticsView.swift"),
            encoding: .utf8
        )
        let allSessionsSource = try XCTUnwrap(
            source.split(separator: "struct AllSessionsView", maxSplits: 1).last?
                .split(separator: "struct SessionDetailView", maxSplits: 1).first
        )

        XCTAssertTrue(allSessionsSource.contains("DispatchQueue.main.async"))
        XCTAssertTrue(allSessionsSource.contains("let panel = NSSavePanel()"))
        XCTAssertTrue(allSessionsSource.contains("panel.nameFieldStringValue = String("))
        XCTAssertTrue(allSessionsSource.contains("String(localized: \"NanaFlow 会话.%@\")"))
        XCTAssertTrue(allSessionsSource.contains("panel.beginSheetModal(for: window)"))
        XCTAssertTrue(allSessionsSource.contains("contents.write(to: url, atomically: true, encoding: .utf8)"))
        XCTAssertFalse(allSessionsSource.contains(".fileExporter("))
        XCTAssertFalse(allSessionsSource.contains("runModal()"))
    }

    func testStatisticsContentUsesCompactMainWindowFrame() throws {
        let repositoryURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFocus/StatisticsView.swift"),
            encoding: .utf8
        )
        let statisticsSource = try XCTUnwrap(
            source.split(separator: "struct StatisticsView", maxSplits: 1).last?
                .split(separator: "private struct StatisticsPeriodPicker", maxSplits: 1).first
        )

        XCTAssertTrue(statisticsSource.contains(
            ".frame(width: StatisticsVisualMetrics.windowWidth, height: StatisticsVisualMetrics.contentHeight)"
        ))
        XCTAssertFalse(statisticsSource.contains("minWidth: StatisticsVisualMetrics.windowWidth"))
    }

    func testBlockerRenders() {
        let controller = BlockerController(
            persistence: RenderingBlockerPersistence(
                configuration: BlockerConfiguration(
                    mode: .block,
                    appBundleIdentifiers: ["com.apple.TextEdit"],
                    websitePatterns: []
                )
            )
        )
        let renderer = ImageRenderer(content: BlockerView(controller: controller))
        renderer.proposedSize = ProposedViewSize(width: 380, height: 272)

        XCTAssertNotNil(renderer.nsImage)
    }

    func testWebsiteBlockerRenders() {
        let controller = BlockerController(
            persistence: RenderingBlockerPersistence(
                configuration: BlockerConfiguration(
                    mode: .allow,
                    appBundleIdentifiers: [],
                    websitePatterns: ["youtube", "social.example.com"]
                )
            )
        )
        let renderer = ImageRenderer(content: BlockerView(controller: controller, initialTab: .websites))
        renderer.proposedSize = ProposedViewSize(width: 380, height: 272)

        XCTAssertNotNil(renderer.nsImage)
    }

    func testTimerOptionsMenuBuilds() {
        let renderer = ImageRenderer(content: TimerOptionsMenuContent(
            controller: makeController(),
            onTimerSettings: {},
            onStatistics: {},
            onSettings: {},
            onAbout: {}
        ))
        renderer.proposedSize = ProposedViewSize(width: 320, height: 240)

        XCTAssertNotNil(renderer.nsImage)
    }

    func testTagManagementRenders() {
        let renderer = ImageRenderer(content: TagManagementView(controller: makeController()))
        renderer.proposedSize = ProposedViewSize(width: 380, height: 272)

        XCTAssertNotNil(renderer.nsImage)
    }

    func testTaggedSessionRowRenders() {
        let end = Date(timeIntervalSince1970: 10_000)
        let renderer = ImageRenderer(
            content: SessionRow(
                session: FocusSession(
                    id: UUID(),
                    startedAt: end.addingTimeInterval(-1_200),
                    endedAt: end,
                    duration: 1_200,
                    completed: false,
                    title: "NanaFlow",
                    tag: "工作"
                )
            )
        )
        renderer.proposedSize = ProposedViewSize(width: 400, height: 100)

        XCTAssertNotNil(renderer.nsImage)
    }

    func testSessionDetailRenders() {
        let end = Date(timeIntervalSince1970: 10_000)
        let session = FocusSession(
            id: UUID(),
            startedAt: end.addingTimeInterval(-1_500),
            endedAt: end,
            duration: 1_500,
            completed: true,
            title: "深度工作",
            tag: "工作"
        )
        let controller = makeController(sessions: [session])
        controller.addTag("工作")
        let renderer = ImageRenderer(content: SessionDetailView(
            controller: controller,
            session: session,
            dismiss: {}
        ))
        renderer.proposedSize = ProposedViewSize(width: 430, height: 330)

        XCTAssertNotNil(renderer.nsImage)
    }

    func testLockedCompactDesignUsesOneSurfaceAndOnlyCoreNavigation() throws {
        let repositoryURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let statistics = try String(
            contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFocus/StatisticsView.swift"),
            encoding: .utf8
        )
        let timer = try String(
            contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFocus/TimerView.swift"),
            encoding: .utf8
        )
        let menu = try String(
            contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFocus/TimerOptionsMenuContent.swift"),
            encoding: .utf8
        )
        let settingsFile = try String(
            contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFocus/TimerSettingsView.swift"),
            encoding: .utf8
        )
        let settings = try XCTUnwrap(
            settingsFile.split(separator: "enum SettingsVisualMetrics", maxSplits: 1).first
        )
        let app = try String(
            contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFocus/NanaFocusApp.swift"),
            encoding: .utf8
        )

        XCTAssertEqual(StatisticsVisualMetrics.contentHeight, 240)
        XCTAssertEqual(StatisticsVisualMetrics.headerHeight, 49)
        XCTAssertEqual(StatisticsVisualMetrics.periodSwitcherHeight, 42)
        XCTAssertEqual(StatisticsVisualMetrics.chartHeight, 149)
        XCTAssertEqual(StatisticsVisualMetrics.chartTrackHeight, 105)
        XCTAssertFalse(statistics.contains("FlowPalette.breakBackground"))
        XCTAssertFalse(statistics.contains("cardInset"))
        XCTAssertFalse(statistics.contains("cardCornerRadius"))
        XCTAssertTrue(statistics.contains(#"\(statistics.totalCount)次"#))

        XCTAssertTrue(timer.contains("case .about:"))
        XCTAssertTrue(timer.contains("AboutNanaFlowView"))
        XCTAssertFalse(timer.contains("openWindow(id: \"about\")"))
        XCTAssertFalse(timer.contains("openWindow(id: \"how-it-works\")"))
        XCTAssertFalse(timer.contains("RecommendationMenu()"))
        XCTAssertTrue(statistics.contains(".position(x: 214, y: StatisticsVisualMetrics.headerHeight / 2)"))
        XCTAssertTrue(menu.contains("Button(\"计时设置\""))
        XCTAssertTrue(menu.contains("Button(phaseSwitchTitle"))
        XCTAssertTrue(menu.contains("Button(\"统计\""))
        XCTAssertFalse(menu.contains("ProUnlockedContract.menuTitle"))
        XCTAssertFalse(menu.contains("编辑会话名称"))
        XCTAssertFalse(menu.contains("定时器同步"))

        XCTAssertTrue(settings.contains("登录时启动"))
        XCTAssertTrue(settings.contains("启动时显示窗口"))
        XCTAssertTrue(settings.contains("计时开始后隐藏窗口"))
        XCTAssertTrue(settings.contains("完成声音"))
        XCTAssertTrue(settings.contains("专注时播放滴答声"))
        XCTAssertFalse(settings.contains("休息时全屏模式"))
        XCTAssertFalse(settings.contains("键盘快捷键"))
        XCTAssertFalse(settings.contains("与日历同步"))
        XCTAssertFalse(app.contains("Window(\"About\", id: \"about\")"))
        XCTAssertFalse(app.contains("Window(\"How It Works\", id: \"how-it-works\")"))
    }

    private func makeController(
        sessions: [FocusSession] = [],
        engine: TimerEngine? = nil
    ) -> TimerController {
        TimerController(
            persistence: RenderingPersistence(engine: engine),
            preferencesPersistence: RenderingPreferencesPersistence(),
            historyPersistence: RenderingHistoryPersistence(sessions: sessions),
            tagPersistence: RenderingTagPersistence(),
            notifications: RenderingNotifications(),
            now: Date(timeIntervalSince1970: 10_000)
        )
    }

    private func attach(_ image: NSImage, name: String) {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            XCTFail("Unable to encode \(name) as PNG")
            return
        }

        let attachment = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

@MainActor
private struct RenderingPersistence: TimerPersisting {
    let engine: TimerEngine?

    init(engine: TimerEngine? = nil) {
        self.engine = engine
    }

    func load() -> TimerEngine? { engine }
    func save(_: TimerEngine) throws {}
}

@MainActor
private struct RenderingTagPersistence: SessionTagPersisting {
    func load() -> SessionTagSettings? { .standard }
    func save(_: SessionTagSettings) throws {}
}

@MainActor
private struct RenderingPreferencesPersistence: TimerPreferencesPersisting {
    func load() -> TimerPreferences? { nil }
    func save(_: TimerPreferences) throws {}
}

@MainActor
private struct RenderingHistoryPersistence: SessionHistoryPersisting {
    let sessions: [FocusSession]

    func load() -> [FocusSession] { sessions }
    func save(_: [FocusSession]) throws {}
}

@MainActor
private struct RenderingNotifications: SessionNotificationScheduling {
    func scheduleCompletion(at _: Date, nextPhase _: SessionPhase, sound _: CompletionSound, volume _: Double, quote _: String?) {}
    func cancelCompletion() {}
}

@MainActor
private struct RenderingBlockerPersistence: BlockerConfigurationPersisting {
    let configuration: BlockerConfiguration

    func load() -> BlockerConfiguration? { configuration }
    func save(_: BlockerConfiguration) throws {}
}
