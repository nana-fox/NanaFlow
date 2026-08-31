import AppKit
import SwiftUI

struct TimerView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @AppStorage("welcome.hasBeenShown") private var hasBeenShown = false
    @AppStorage("welcome.showAtLaunch") private var showWelcomeAtLaunch = false
    @State private var page: TimerPage = .timer
    @State private var showsCelebration = false
    @State private var menuIsHovered = false
    let controller: TimerController

    init(
        controller: TimerController,
        initiallyShowsToolbar: Bool = false
    ) {
        self.controller = controller
        _ = initiallyShowsToolbar
    }

    var body: some View {
        Group {
            switch page {
            case .timer:
                ZStack {
                    backgroundColor
                    timerContent
                    if showsCelebration {
                        CycleCelebrationView(isPresented: $showsCelebration)
                    }
                }
            case .settings:
                TimerSettingsView(controller: controller) {
                    page = .timer
                }
            case .statistics:
                StatisticsView(controller: controller) {
                    page = .timer
                }
            case .durations:
                CustomDurationView(controller: controller) {
                    page = .timer
                }
            case .about:
                AboutNanaFlowView {
                    page = .timer
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: TimerVisualMetrics.windowCornerRadius, style: .continuous))
        .frame(width: 380, height: TimerVisualMetrics.windowContentHeight, alignment: .top)
        .ignoresSafeArea()
        .background(MainWindowConfigurator())
        .onAppear {
            NSApplication.shared.activate()
            configureInitialWindows()
            updateFullscreenBreak(for: controller.engine.state.phase)
        }
        .onReceive(NotificationCenter.default.publisher(for: .showCustomDurations)) { _ in
            page = .durations
        }
        .onReceive(NotificationCenter.default.publisher(for: .showSettings)) { _ in
            page = .settings
        }
        .onReceive(NotificationCenter.default.publisher(for: .showStatistics)) { _ in
            page = .statistics
        }
        .onReceive(NotificationCenter.default.publisher(for: .showAbout)) { _ in
            page = .about
        }
        .preferredColorScheme(controller.preferences.appearance.colorScheme)
        .onChange(of: controller.engine.state.phase) { _, phase in
            updateFullscreenBreak(for: phase)
        }
        .onChange(of: controller.preferences.fullscreenBreaks) { _, _ in
            updateFullscreenBreak(for: controller.engine.state.phase)
        }
        .onChange(of: controller.celebrationSequence) { previous, current in
            if current > previous {
                showsCelebration = true
            }
        }
        .alert(
            "无法保存",
            isPresented: Binding(
                get: { controller.errorMessage != nil },
                set: { if !$0 { controller.dismissError() } }
            )
        ) {
            Button("好") { controller.dismissError() }
        } message: {
            Text(controller.errorMessage ?? String(localized: "未知错误"))
        }
    }

    private var timerContent: some View {
        ZStack(alignment: .topLeading) {
            Text(controller.phaseTitle)
                .font(.system(size: TimerVisualMetrics.titleFontSize, weight: .regular, design: .rounded))
                .accessibilityIdentifier("phase-title")
                .position(x: 190, y: TimerVisualMetrics.titleCenterY)

            Text(controller.formattedTime)
                .font(.system(size: TimerVisualMetrics.timerFontSize, weight: .regular, design: .default))
                .monospacedDigit()
                .kerning(TimerVisualMetrics.timerKerning)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .accessibilityIdentifier("timer-value")
                .position(x: 190, y: TimerVisualMetrics.timerCenterY)

            cycleDots
                .position(x: 190, y: TimerVisualMetrics.cycleCenterY)

            Button {
                controller.toggle()
            } label: {
                Image(controller.engine.state.isRunning ? "phosphor-pause" : "phosphor-play-fill")
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .foregroundStyle(primaryButtonForeground)
                    .offset(x: controller.engine.state.isRunning ? 0 : 1)
                    .frame(
                        width: controller.engine.state.isRunning
                            ? TimerVisualMetrics.pauseSymbolSize
                            : TimerVisualMetrics.playSymbolSize,
                        height: controller.engine.state.isRunning
                            ? TimerVisualMetrics.pauseSymbolSize
                            : TimerVisualMetrics.playSymbolSize
                    )
                    .frame(
                        width: TimerVisualMetrics.primaryButtonDiameter,
                        height: TimerVisualMetrics.primaryButtonDiameter
                    )
                    .background(primaryButtonBackground, in: Circle())
            }
            .buttonStyle(TimerPrimaryButtonStyle())
            .keyboardShortcut(.space, modifiers: [])
            .disabled(controller.isCommittedFocus)
            .accessibilityLabel(controller.engine.state.isRunning ? "停止" : "开始")
            .accessibilityIdentifier("primary-timer-button")
            .position(x: 190, y: TimerVisualMetrics.primaryButtonCenterY)

            topControls
        }
        .frame(width: 380, height: TimerVisualMetrics.windowFrameHeight)
        .foregroundStyle(foregroundColor)
    }

    private var topControls: some View {
        ZStack(alignment: .topLeading) {
            Group {
                Button { NSApplication.shared.keyWindow?.close() } label: {
                    Image("phosphor-x-circle-fill")
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .foregroundStyle(closeButtonColor)
                        .frame(
                            width: TimerVisualMetrics.closeSymbolSize,
                            height: TimerVisualMetrics.closeSymbolSize
                        )
                        .frame(
                            width: TimerVisualMetrics.toolbarControlDiameter,
                            height: TimerVisualMetrics.toolbarControlDiameter
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("关闭")
                .position(x: TimerVisualMetrics.closeControlX, y: TimerVisualMetrics.toolbarCenterY)

                if TimerVisualMetrics.showsSkipButton(for: controller.engine.state.phase) {
                    Button { controller.skip() } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: TimerVisualMetrics.skipSymbolSize, weight: .light))
                            .symbolRenderingMode(.monochrome)
                            .offset(x: -1, y: -0.5)
                            .frame(
                                width: TimerVisualMetrics.toolbarControlDiameter,
                                height: TimerVisualMetrics.toolbarControlDiameter
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(controller.isCommittedFocus)
                    .accessibilityLabel("跳过休息时间")
                    .position(x: 248, y: TimerVisualMetrics.toolbarCenterY)
                }

                Button { controller.resetCycle() } label: {
                    Image("phosphor-arrow-counter-clockwise")
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .frame(
                            width: TimerVisualMetrics.resetSymbolSize,
                            height: TimerVisualMetrics.resetSymbolSize
                        )
                        .frame(
                            width: TimerVisualMetrics.toolbarControlDiameter,
                            height: TimerVisualMetrics.toolbarControlDiameter
                        )
                }
                .buttonStyle(TimerToolbarButtonStyle(background: toolbarHoverBackground))
                .disabled(controller.isCommittedFocus)
                .accessibilityLabel("重新开始周期")
                .position(x: TimerVisualMetrics.resetControlX, y: TimerVisualMetrics.toolbarCenterY)

                Button {
                    page = .statistics
                } label: {
                    Image("phosphor-chart-bar")
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .frame(
                            width: TimerVisualMetrics.statisticsSymbolSize,
                            height: TimerVisualMetrics.statisticsSymbolSize
                        )
                        .frame(
                            width: TimerVisualMetrics.toolbarControlDiameter,
                            height: TimerVisualMetrics.toolbarControlDiameter
                        )
                }
                .buttonStyle(TimerToolbarButtonStyle(background: toolbarHoverBackground))
                .accessibilityLabel("统计")
                .position(x: TimerVisualMetrics.statisticsControlX, y: TimerVisualMetrics.toolbarCenterY)
            }

            ZStack {
                Circle()
                    .fill(menuIsHovered ? toolbarHoverBackground : .clear)

                TimerMenuIcon(foregroundColor: toolbarForegroundColor)
                    .allowsHitTesting(false)

                Menu {
                    TimerOptionsMenuContent(
                        controller: controller,
                        onTimerSettings: { page = .durations },
                        onStatistics: { page = .statistics },
                        onSettings: { page = .settings },
                        onAbout: { page = .about }
                    )
                } label: {
                    Color.clear
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .buttonStyle(.plain)
                .accessibilityLabel("菜单")
                .help("菜单")
            }
            .frame(
                width: TimerVisualMetrics.toolbarControlDiameter,
                height: TimerVisualMetrics.toolbarControlDiameter
            )
            .onHover { menuIsHovered = $0 }
            .position(x: TimerVisualMetrics.menuControlX, y: TimerVisualMetrics.toolbarCenterY)
        }
        .frame(width: 380, height: 50)
        .foregroundStyle(toolbarForegroundColor)
        .contentShape(Rectangle())
    }

    private var cycleDots: some View {
        HStack(spacing: TimerVisualMetrics.indicatorSpacing) {
            ForEach(0 ..< controller.engine.configuration.sessionsPerCycle, id: \.self) { index in
                cycleIndicator(at: index)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(controller.cycleAccessibilityLabel)
    }

    @ViewBuilder
    private func cycleIndicator(at index: Int) -> some View {
        if index == controller.engine.state.cycleIndex,
           controller.engine.state.phase == .focus {
            Capsule()
                .fill(indicatorColor)
                .frame(
                    width: TimerVisualMetrics.activeIndicatorWidth,
                    height: TimerVisualMetrics.indicatorDiameter
                )
        } else {
            Circle()
                .fill(
                    index <= controller.engine.state.cycleIndex
                        ? indicatorColor
                        : indicatorColor.opacity(TimerVisualMetrics.inactiveIndicatorOpacity)
                )
                .frame(
                    width: TimerVisualMetrics.indicatorDiameter,
                    height: TimerVisualMetrics.indicatorDiameter
                )
        }
    }

    private var backgroundColor: Color {
        switch controller.engine.state.phase {
        case .focus:
            FlowPalette.window
        case .shortBreak:
            FlowPalette.breakBackground
        case .longBreak:
            FlowPalette.breakBackground
        }
    }

    private var foregroundColor: Color {
        controller.engine.state.phase == .focus
            ? Color(red: 0.13, green: 0.15, blue: 0.14)
            : .white
    }

    private var indicatorColor: Color {
        controller.engine.state.phase == .focus ? FlowPalette.focus : .white
    }

    private var primaryButtonBackground: Color {
        controller.engine.state.phase == .focus
            ? FlowPalette.primaryButtonBackground
            : .white.opacity(0.2)
    }

    private var primaryButtonForeground: Color {
        controller.engine.state.phase == .focus ? FlowPalette.compactAccent : .white
    }

    private var toolbarForegroundColor: Color {
        controller.engine.state.phase == .focus
            ? foregroundColor.opacity(TimerVisualMetrics.toolbarFocusOpacity)
            : .white
    }

    private var closeButtonColor: Color {
        controller.engine.state.phase == .focus
            ? foregroundColor.opacity(TimerVisualMetrics.closeFocusOpacity)
            : .white.opacity(0.55)
    }

    private var toolbarHoverBackground: Color {
        controller.engine.state.phase == .focus
            ? foregroundColor.opacity(0.07)
            : .white.opacity(0.12)
    }

    private func updateFullscreenBreak(for phase: SessionPhase) {
        if phase != .focus, controller.preferences.fullscreenBreaks {
            FullscreenBreakWindowController.shared.show(controller: controller)
        } else {
            FullscreenBreakWindowController.shared.closeIfAutomaticallyPresented()
        }
    }

    private func configureInitialWindows() {
        guard let appDelegate = NSApplication.shared.delegate as? NanaFlowAppDelegate,
              appDelegate.claimInitialWindowConfiguration() else { return }

        DispatchQueue.main.async {
            if WelcomeDisplayPolicy.shouldPresent(
                hasBeenShown: hasBeenShown,
                showAtLaunch: showWelcomeAtLaunch
            ) {
                hasBeenShown = true
                dismissWindow(id: "timer")
                openWindow(id: "welcome")
                AppWindowActivation.bringToFront(title: "Welcome")
            } else if controller.didStartTimerAtLaunch,
                      controller.preferences.hideWindowWhenTimerStarts {
                dismissWindow(id: "timer")
            } else if controller.preferences.showWindowOnLaunch {
                openWindow(id: "timer")
                AppWindowActivation.bringToFront(title: "NanaFlow")
            } else {
                dismissWindow(id: "timer")
            }
        }
    }
}

struct CycleCelebrationView: View {
    static let particleCount = 119
    static let animationDuration = 1.5
    static let particleSizeRange = 3.0 ... 6.0
    static let particleOpacityRange = 0.1 ... 0.3
    static let particleDistanceRange = 20.0 ... 220.0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var isPresented: Bool
    @State private var animationProgress = 0.0
    @State private var animationScale = 0.0

    var body: some View {
        ZStack {
            ForEach(1 ... Self.particleCount, id: \.self) { index in
                let distance = value(in: Self.particleDistanceRange, index: index, salt: 3)
                let direction = value(in: -Double.pi ... Double.pi, index: index, salt: 4)

                Circle()
                    .fill(.white.opacity(value(in: Self.particleOpacityRange, index: index, salt: 1)))
                    .frame(
                        width: value(in: Self.particleSizeRange, index: index, salt: 2),
                        height: value(in: Self.particleSizeRange, index: index, salt: 2)
                    )
                    .rotationEffect(.degrees(animationProgress * 120))
                    .scaleEffect(animationScale)
                    .offset(
                        x: cos(direction) * distance * normalizedProgress,
                        y: sin(direction) * distance * normalizedProgress
                    )
                    .opacity(max(0, (Self.animationDuration - animationScale) / Self.animationDuration))
            }
        }
        .frame(width: 380, height: TimerVisualMetrics.windowContentHeight)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else {
                isPresented = false
                return
            }
            withAnimation(.easeOut(duration: Self.animationDuration)) {
                animationProgress = Self.animationDuration
                animationScale = Double.random(in: 1 ... 1.5)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.animationDuration) {
                isPresented = false
            }
        }
    }

    private var normalizedProgress: Double {
        animationProgress / Self.animationDuration
    }

    private func value(in range: ClosedRange<Double>, index: Int, salt: Int) -> Double {
        var hash = UInt64(index) &+ UInt64(salt) &* 0x9e37_79b9_7f4a_7c15
        hash = (hash ^ (hash >> 30)) &* 0xbf58_476d_1ce4_e5b9
        hash = (hash ^ (hash >> 27)) &* 0x94d0_49bb_1331_11eb
        let unit = Double((hash ^ (hash >> 31)) >> 11) / Double(1 << 53)
        return range.lowerBound + unit * (range.upperBound - range.lowerBound)
    }
}

struct TimerMenuIcon: View {
    static let assetName = "phosphor-dots-three-vertical-bold"
    static let symbolSize: CGFloat = 20

    let foregroundColor: Color

    var body: some View {
        Image(Self.assetName)
            .resizable()
            .renderingMode(.template)
            .scaledToFit()
            .foregroundStyle(foregroundColor)
            .frame(width: Self.symbolSize, height: Self.symbolSize)
            .frame(
                width: TimerVisualMetrics.toolbarControlDiameter,
                height: TimerVisualMetrics.toolbarControlDiameter
            )
            .contentShape(Rectangle())
            .accessibilityHidden(true)
    }
}

private struct TimerToolbarButtonStyle: ButtonStyle {
    let background: Color

    func makeBody(configuration: Configuration) -> some View {
        TimerToolbarButtonStyleBody(configuration: configuration, background: background)
    }

    private struct TimerToolbarButtonStyleBody: View {
        let configuration: ButtonStyleConfiguration
        let background: Color
        @State private var isHovered = false

        var body: some View {
            configuration.label
                .background(isHovered || configuration.isPressed ? background : .clear, in: Circle())
                .scaleEffect(configuration.isPressed ? 0.96 : 1)
                .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
                .onHover { isHovered = $0 }
        }
    }
}

private struct TimerPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        TimerPrimaryButtonStyleBody(configuration: configuration)
    }

    private struct TimerPrimaryButtonStyleBody: View {
        let configuration: ButtonStyleConfiguration
        @State private var isHovered = false

        var body: some View {
            configuration.label
                .brightness(isHovered ? -0.03 : 0)
                .scaleEffect(configuration.isPressed ? 0.96 : 1)
                .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
                .onHover { isHovered = $0 }
        }
    }
}

enum TimerVisualMetrics {
    static let windowFrameHeight: CGFloat = 272
    static let windowContentHeight: CGFloat = 240
    static let windowCornerRadius: CGFloat = 26
    static let titleFontSize: CGFloat = 20
    static let timerFontSize: CGFloat = 70
    static let timerKerning: CGFloat = -1.5
    static let titleCenterY: CGFloat = 60.5
    static let timerCenterY: CGFloat = 120
    static let cycleCenterY: CGFloat = 168.5
    static let primaryButtonCenterY: CGFloat = 220
    static let primaryButtonDiameter: CGFloat = 42
    static let closeSymbolSize: CGFloat = 17
    static let toolbarControlDiameter: CGFloat = 29
    static let skipSymbolSize: CGFloat = 20.5
    static let resetSymbolSize: CGFloat = 19
    static let statisticsSymbolSize: CGFloat = 20
    static let menuSymbolSize: CGFloat = 20
    static let playSymbolSize: CGFloat = 25
    static let pauseSymbolSize: CGFloat = 22
    static let closeControlX: CGFloat = 28.5
    static let resetControlX: CGFloat = 286
    static let statisticsControlX: CGFloat = 318.5
    static let menuControlX: CGFloat = 351.5
    static let toolbarCenterY: CGFloat = 26
    static let activeIndicatorWidth: CGFloat = 27
    static let indicatorDiameter: CGFloat = 12
    static let indicatorSpacing: CGFloat = 5
    static let inactiveIndicatorOpacity = 0.23
    static let toolbarFocusOpacity = 1.0
    static let closeFocusOpacity = 0.42

    static func showsSkipButton(for phase: SessionPhase) -> Bool {
        phase != .focus
    }
}

private enum TimerPage {
    case timer
    case settings
    case statistics
    case durations
    case about
}

extension Notification.Name {
    static let showSettings = Notification.Name("NanaFlow.showSettings")
    static let showStatistics = Notification.Name("NanaFlow.showStatistics")
    static let showCustomDurations = Notification.Name("NanaFlow.showCustomDurations")
    static let showAbout = Notification.Name("NanaFlow.showAbout")
}

private struct MainWindowConfigurator: NSViewRepresentable {
    func makeNSView(context _: Context) -> NSView {
        ConfiguringView()
    }

    func updateNSView(_: NSView, context _: Context) {}

    private final class ConfiguringView: NSView {
        private static let configuredWindows = NSHashTable<NSWindow>.weakObjects()

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            guard !Self.configuredWindows.contains(window) else { return }
            Self.configuredWindows.add(window)
            DispatchQueue.main.async { [weak window] in
                guard let window else { return }
                let frame = window.frame
                window.styleMask = window.styleMask.union([.titled, .resizable, .fullSizeContentView])
                window.titleVisibility = .hidden
                window.titlebarAppearsTransparent = true
                window.titlebarSeparatorStyle = .none
                window.setFrame(frame, display: false)
                window.setAccessibilitySubrole(.standardWindow)
                window.isMovableByWindowBackground = true
                window.isOpaque = false
                window.backgroundColor = .clear
                window.standardWindowButton(.closeButton)?.isHidden = true
                window.standardWindowButton(.miniaturizeButton)?.isHidden = true
                window.standardWindowButton(.zoomButton)?.isHidden = true
                window.standardWindowButton(.zoomButton)?.isEnabled = false
            }
        }
    }
}
