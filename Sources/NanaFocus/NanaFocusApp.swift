import AppKit
import SwiftUI

@MainActor
private func menuBarAccessibilityLabel(_ controller: TimerController) -> String {
    String(
        format: String(localized: "menu_bar_accessibility_format"),
        controller.phaseTitle,
        controller.formattedTime
    )
}

@main
struct NanaFlowApp: App {
    @NSApplicationDelegateAdaptor(NanaFlowAppDelegate.self) private var appDelegate
    @State private var controller = TimerController.shared

    var body: some Scene {
        Window("NanaFlow", id: "timer") {
            TimerView(controller: controller)
                .onOpenURL { url in
                    guard let command = TimerAutomationCommand(url: url) else { return }
                    controller.perform(command)
                }
        }
        .defaultSize(width: 380, height: TimerVisualMetrics.windowFrameHeight)
        .windowResizability(.contentMinSize)
        .windowStyle(.plain)
        .commands {
            NanaFlowCommands()
        }

        Window("Welcome", id: "welcome") {
            NanaFlowWelcomeWindow()
        }
        .defaultSize(width: 420, height: 460)
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        .commandsRemoved()

        Window("Notification Alert", id: PermissionAlertKind.notification.windowID) {
            PermissionAlertWindow(kind: .notification)
        }
        .defaultSize(
            width: PermissionWindowMetrics.alertWidth,
            height: PermissionWindowMetrics.alertHeight
        )
        .windowResizability(.contentSize)
        .windowStyle(.plain)
        .commandsRemoved()

        Window("Calendar Alert", id: PermissionAlertKind.calendar.windowID) {
            PermissionAlertWindow(kind: .calendar)
        }
        .defaultSize(
            width: PermissionWindowMetrics.alertWidth,
            height: PermissionWindowMetrics.alertHeight
        )
        .windowResizability(.contentSize)
        .windowStyle(.plain)
        .commandsRemoved()

        Window("Calendar Chooser", id: "calendar-chooser") {
            CalendarChooserWindow(controller: controller)
        }
        .defaultSize(
            width: PermissionWindowMetrics.chooserWidth,
            height: PermissionWindowMetrics.chooserHeight
        )
        .windowResizability(.contentSize)
        .windowStyle(.plain)
        .commandsRemoved()

    }
}

struct MenuBarStatusContent: View {
    let controller: TimerController

    var body: some View {
        Text(controller.formattedTime)
                .monospacedDigit()
                .foregroundStyle(Color(nsColor: .labelColor))
            .accessibilityLabel(menuBarAccessibilityLabel(controller))
            .help("\(controller.phaseTitle) · \(controller.formattedTime)")
            .fixedSize()
            .frame(height: 22)
            .allowsHitTesting(false)
    }
}

@MainActor
final class AppStatusItemService: NSObject {
    private let controller: TimerController
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var ticker: Timer?
    private var hostingView: NSHostingView<MenuBarStatusContent>?
    private var hotkeyConfiguration: (enabled: Bool, shortcuts: GlobalShortcutSet)?

    init(controller: TimerController) {
        self.controller = controller
    }

    func start() {
        guard ticker == nil, let button = statusItem.button else { return }

        let hostingView = NSHostingView(rootView: MenuBarStatusContent(controller: controller))
        hostingView.setAccessibilityElement(false)
        hostingView.frame = button.bounds
        hostingView.autoresizingMask = [.width, .height]
        button.addSubview(hostingView)
        button.target = self
        button.action = #selector(handleClick)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        self.hostingView = hostingView

        controller.startCloudSync()
        refresh()

        let ticker = Timer(timeInterval: 1, target: self, selector: #selector(refresh), userInfo: nil, repeats: true)
        RunLoop.main.add(ticker, forMode: .common)
        self.ticker = ticker
    }

    func stop() {
        ticker?.invalidate()
        ticker = nil
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    @objc private func handleClick() {
        guard let event = NSApplication.shared.currentEvent,
              let action = MenuBarStatusItemActionPolicy.action(
                  eventType: event.type,
                  modifiers: event.modifierFlags
              ) else { return }
        switch action {
        case .showMenu:
            showMenu()
        case .quickToggle:
            controller.toggle()
            refresh()
        }
    }

    private func showMenu() {
        let menu = NSMenu()

        let status = NSMenuItem(
            title: "\(controller.phaseTitle) · \(controller.formattedTime)",
            action: nil,
            keyEquivalent: ""
        )
        status.isEnabled = false
        menu.addItem(status)
        menu.addItem(item(
            controller.engine.state.isRunning ? "暂停" : "开始",
            systemImage: controller.engine.state.isRunning ? "pause" : "play",
            action: #selector(toggleTimer)
        ))
        menu.addItem(item(
            AppWindowActivation.timerWindow?.isVisible == true ? "隐藏计时器" : "显示计时器",
            systemImage: "timer",
            action: #selector(toggleTimerWindow)
        ))
        menu.addItem(item("显示统计", systemImage: "chart.bar", action: #selector(showStatistics)))
        menu.addItem(.separator())
        menu.addItem(item(
            controller.engine.state.phase == .focus ? "跳到休息" : "跳到专注",
            systemImage: "chevron.right",
            action: #selector(skip)
        ))
        menu.addItem(item("重新开始", systemImage: "arrow.counterclockwise", action: #selector(resetCycle)))
        menu.addItem(.separator())
        menu.addItem(item("计时设置…", systemImage: "timer", action: #selector(showTimerSettings)))
        menu.addItem(item("设置…", systemImage: "gearshape", action: #selector(showSettings)))
        menu.addItem(item("关于 NanaFlow", systemImage: "info.circle", action: #selector(showAbout)))
        menu.addItem(.separator())
        menu.addItem(item("退出 NanaFlow", systemImage: "power", action: #selector(quit)))

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    private func item(_ title: String, systemImage: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: String(localized: String.LocalizationValue(title)), action: action, keyEquivalent: "")
        item.target = self
        item.image = NSImage(systemSymbolName: systemImage, accessibilityDescription: title)
        return item
    }

    @objc private func toggleTimer() {
        controller.toggle()
        refresh()
    }

    @objc private func toggleTimerWindow() {
        if AppWindowActivation.timerWindow?.isVisible == true {
            AppWindowActivation.hideTimerWindow()
        } else {
            showTimer()
        }
    }

    @objc private func skip() {
        controller.skip()
        refresh()
    }

    @objc private func resetCycle() {
        controller.resetCycle()
        refresh()
    }

    @objc private func showSettings() {
        showTimer()
        NotificationCenter.default.post(name: .showSettings, object: nil)
    }

    @objc private func showTimerSettings() {
        showTimer()
        NotificationCenter.default.post(name: .showCustomDurations, object: nil)
    }

    @objc private func showStatistics() {
        showTimer()
        NotificationCenter.default.post(name: .showStatistics, object: nil)
    }

    @objc private func showAbout() {
        showTimer()
        NotificationCenter.default.post(name: .showAbout, object: nil)
    }

    private func showTimer() {
        AppWindowActivation.timerWindow?.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    @objc private func refresh() {
        let now = Date()
        if controller.engine.state.isRunning {
            controller.tick(at: now)
        }
        refreshHotkeysIfNeeded()
        hostingView?.appearance = statusItem.button?.effectiveAppearance
        statusItem.button?.toolTip = "\(controller.phaseTitle) · \(controller.formattedTime)"
        statusItem.button?.setAccessibilityLabel(menuBarAccessibilityLabel(controller))
        statusItem.length = max(22, ceil(hostingView?.fittingSize.width ?? 22))
    }

    private func refreshHotkeysIfNeeded() {
        let configuration = (
            enabled: controller.preferences.globalHotkeysEnabled,
            shortcuts: controller.preferences.globalShortcuts
        )
        guard hotkeyConfiguration?.enabled != configuration.enabled
            || hotkeyConfiguration?.shortcuts != configuration.shortcuts else { return }
        hotkeyConfiguration = configuration
        GlobalHotkeyMonitor.shared.configure(enabled: configuration.enabled, controller: controller)
    }
}
