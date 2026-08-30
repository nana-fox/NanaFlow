import AppKit
import SwiftUI

enum WelcomeDisplayPolicy {
    static func shouldPresent(hasBeenShown: Bool, showAtLaunch: Bool) -> Bool {
        !hasBeenShown || showAtLaunch
    }
}

struct NanaFlowWelcomeView: View {
    @Binding var showAtLaunch: Bool
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Image(nsImage: appIcon)
                .resizable()
                .frame(
                    width: WelcomeVisualMetrics.iconImageSize,
                    height: WelcomeVisualMetrics.iconImageSize
                )
                .frame(width: 142, height: 142)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                .shadow(color: .black.opacity(0.20), radius: 9, y: 7)
                .padding(.top, WelcomeVisualMetrics.iconTopPadding)

            Text("欢迎来到NanaFlow")
                .font(.system(size: 25, weight: .bold))
                .foregroundStyle(Color(nsColor: .darkGray))
                .padding(.top, 38)

            Text("NanaFlow将您的工作流划分为具有已定义中断的部分，使您可以轻松保持专注。")
                .font(.system(size: 14))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color(nsColor: .darkGray))
                .lineSpacing(3)
                .frame(width: 260)
                .padding(.top, 20)

            Button("好的", action: onDone)
                .buttonStyle(WelcomeButtonStyle())
                .frame(width: 160)
                .padding(.top, 21)

            Spacer()

            Toggle("在启动时显示此窗口", isOn: $showAtLaunch)
                .toggleStyle(.checkbox)
                .font(.system(size: 13))
                .padding(.bottom, 15)
        }
        .frame(width: 420, height: 460)
        .background {
            Image(nsImage: welcomeBackground)
                .resizable()
                .scaledToFill()
                .frame(width: 420, height: 540)
                .offset(y: WelcomeVisualMetrics.backgroundOffsetY)
        }
        .background(WelcomeWindowConfigurator())
        .clipped()
        .preferredColorScheme(.light)
    }

    private var welcomeBackground: NSImage {
        Bundle.main.url(forResource: "NanaFlowWelcomeBackground", withExtension: "png")
            .flatMap(NSImage.init(contentsOf:)) ?? NSImage()
    }

    private var appIcon: NSImage {
        NSImage(named: "NanaFlowIcon") ?? NSApplication.shared.applicationIconImage
    }
}

enum WelcomeVisualMetrics {
    static let iconImageSize: CGFloat = 155
    static let iconTopPadding: CGFloat = 48
    static let backgroundOffsetY: CGFloat = -80
}

struct WelcomeWindowConfigurator: NSViewRepresentable {
    func makeNSView(context _: Context) -> NSView {
        ConfiguringView()
    }

    func updateNSView(_: NSView, context _: Context) {}

    private final class ConfiguringView: NSView {
        private static let configuredWindows = NSHashTable<NSWindow>.weakObjects()

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window, !Self.configuredWindows.contains(window) else { return }
            Self.configuredWindows.add(window)
            DispatchQueue.main.async { [weak window] in
                guard let window else { return }
                let frame = window.frame
                window.titleVisibility = .hidden
                window.titlebarAppearsTransparent = true
                window.titlebarSeparatorStyle = .none
                let titlebarColor = NSColor(
                    srgbRed: 90.0 / 255.0,
                    green: 150.0 / 255.0,
                    blue: 144.0 / 255.0,
                    alpha: 1
                )
                let titlebarView = window.standardWindowButton(.closeButton)?.superview
                titlebarView?.wantsLayer = true
                titlebarView?.layer?.backgroundColor = titlebarColor.cgColor
                window.isMovableByWindowBackground = true
                window.setFrame(frame, display: false)
            }
        }
    }
}

private struct WelcomeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(FlowPalette.focus.opacity(configuration.isPressed ? 0.78 : 1), in: Capsule())
    }
}

struct NanaFlowWelcomeWindow: View {
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.openWindow) private var openWindow
    @AppStorage("welcome.showAtLaunch") private var showAtLaunch = false

    var body: some View {
        NanaFlowWelcomeView(showAtLaunch: $showAtLaunch) {
            dismissWindow(id: "welcome")
            openWindow(id: "timer")
            AppWindowActivation.bringToFront(title: "NanaFlow")
        }
    }
}
