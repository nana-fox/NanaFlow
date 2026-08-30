import AppKit
import SwiftUI

private final class FullscreenBreakWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

enum FullscreenBreakContract {
    static let windowTitle = "Fullscreen"
    static let usesDedicatedWindow = true
    static let coversCurrentScreen = true
}

struct FullscreenBreakView: View {
    let controller: TimerController
    let onClose: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let shortEdge = min(proxy.size.width, proxy.size.height)

            ZStack {
                backgroundColor
                    .ignoresSafeArea()

                VStack(spacing: max(14, shortEdge * 0.025)) {
                    Text(controller.phaseTitle)
                        .font(.system(
                            size: min(max(shortEdge * 0.07, 28), 58),
                            weight: .regular,
                            design: .rounded
                        ))

                    Text(controller.formattedTime)
                        .font(.system(
                            size: min(max(shortEdge * 0.25, 104), 230),
                            weight: .regular,
                            design: .rounded
                        ))
                        .monospacedDigit()
                        .lineLimit(1)

                    cycleDots(diameter: min(max(shortEdge * 0.022, 12), 22))

                    HStack(spacing: max(18, shortEdge * 0.035)) {
                        if controller.engine.state.phase != .focus {
                            actionButton(
                                systemName: "chevron.right",
                                label: String(localized: "跳过休息时间"),
                                diameter: min(max(shortEdge * 0.09, 50), 86),
                                action: { controller.skip() }
                            )
                        }
                        actionButton(
                            systemName: controller.engine.state.isRunning ? "pause" : "play",
                            label: controller.engine.state.isRunning
                                ? String(localized: "暂停")
                                : String(localized: "开始"),
                            diameter: min(max(shortEdge * 0.12, 66), 112),
                            action: { controller.toggle() }
                        )
                    }
                }
                .foregroundStyle(foregroundColor)

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: min(max(shortEdge * 0.027, 16), 26), weight: .medium))
                        .frame(width: 44, height: 44)
                        .background(controlBackground.opacity(0.82), in: Circle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(foregroundColor)
                .keyboardShortcut(.cancelAction)
                .accessibilityLabel("关闭全屏休息")
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(max(22, shortEdge * 0.045))
            }
        }
    }

    private func cycleDots(diameter: CGFloat) -> some View {
        HStack(spacing: diameter * 0.4) {
            ForEach(0 ..< controller.engine.configuration.sessionsPerCycle, id: \.self) { index in
                Circle()
                    .fill(indicatorColor.opacity(index <= controller.engine.state.cycleIndex ? 1 : 0.3))
                    .frame(width: diameter, height: diameter)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(controller.cycleAccessibilityLabel)
    }

    private func actionButton(
        systemName: String,
        label: String,
        diameter: CGFloat,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: diameter * 0.38, weight: .regular))
                .offset(x: systemName == "play" ? diameter * 0.025 : 0)
                .frame(width: diameter, height: diameter)
                .background(controlBackground, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var isFocus: Bool {
        controller.engine.state.phase == .focus
    }

    private var backgroundColor: Color {
        isFocus ? FlowPalette.window : FlowPalette.breakBackground
    }

    private var foregroundColor: Color {
        isFocus ? Color(red: 0.13, green: 0.15, blue: 0.14) : .white
    }

    private var indicatorColor: Color {
        isFocus ? FlowPalette.focus : .white
    }

    private var controlBackground: Color {
        isFocus ? FlowPalette.focus.opacity(0.12) : .white.opacity(0.22)
    }
}

@MainActor
final class FullscreenBreakWindowController: NSWindowController {
    static let shared = FullscreenBreakWindowController()
    private(set) var manuallyTriggered = false

    private init() {
        super.init(window: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(controller: TimerController, manuallyTriggered: Bool = false) {
        let targetScreen = NSApplication.shared.keyWindow?.screen ?? NSScreen.main
        guard let targetScreen else { return }

        if window?.isVisible != true {
            self.manuallyTriggered = manuallyTriggered
        } else if manuallyTriggered {
            self.manuallyTriggered = true
        }

        if window == nil {
            let breakWindow = FullscreenBreakWindow(
                contentRect: targetScreen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false,
                screen: targetScreen
            )
            breakWindow.title = FullscreenBreakContract.windowTitle
            breakWindow.backgroundColor = NSColor(
                red: FlowPalette.breakRed,
                green: FlowPalette.breakGreen,
                blue: FlowPalette.breakBlue,
                alpha: 1
            )
            breakWindow.isOpaque = true
            breakWindow.isReleasedWhenClosed = false
            breakWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            breakWindow.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 1)
            breakWindow.contentViewController = NSHostingController(rootView:
                FullscreenBreakView(
                    controller: controller,
                    onClose: { [weak self] in self?.close() }
                )
                .ignoresSafeArea()
            )
            window = breakWindow
        }

        window?.setFrame(targetScreen.frame, display: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        if let window { NSApplication.shared.removeWindowsItem(window) }
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    override func close() {
        manuallyTriggered = false
        window?.orderOut(nil)
    }

    func closeIfAutomaticallyPresented() {
        guard !manuallyTriggered else { return }
        close()
    }
}
