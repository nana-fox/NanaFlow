import AppKit
import SwiftUI

enum ProWindowMetrics {
    static let width: CGFloat = 650
    static let height: CGFloat = 552
    static let windowContentHeight: CGFloat = height - 32
    static let leftPaneWidth: CGFloat = 315
    static let rightPaneWidth = width - leftPaneWidth
    static let rightContentWidth: CGFloat = 295
    static let optionHeight: CGFloat = 50
    static let primaryButtonHeight: CGFloat = 36
    static let featureMinimumScaleFactor = 0.88
    static let featureLineLimit = 2
    static let usesFullSizeContent = true
    static let usesFixedWindowFrame = true
}

enum ProUnlockedContract {
    static let windowID = "pro-unlocked"
    static let menuTitle = String(localized: "升级")
    static let headline = String(localized: "NanaFlow Pro 已解锁")
    static let message = String(localized: "所有高级功能已在 NanaFlow 中全部解锁，无需订阅或购买。")
    static let features = [
        String(localized: "解锁所有功能"),
        String(localized: "自定义会话标题和持续时间"),
        String(localized: "网页阻止和日历同步"),
        String(localized: "跨设备计时器同步"),
    ]
    static let requiresPurchase = false
}

private enum ProWindowPalette {
    static let left = Color(red: 204 / 255, green: 225 / 255, blue: 216 / 255)
    static let right = Color(red: 247 / 255, green: 247 / 255, blue: 247 / 255)
}

private enum ProAccessOption: String, CaseIterable, Identifiable {
    case complete
    case sync
    case lifetime

    var id: String { rawValue }

    var title: String {
        switch self {
        case .complete: "NanaFlow Pro"
        case .sync: String(localized: "跨设备同步")
        case .lifetime: String(localized: "终身使用")
        }
    }

    var detail: String {
        switch self {
        case .complete: String(localized: "所有高级功能已解锁")
        case .sync: String(localized: "可通过 iCloud 同步")
        case .lifetime: String(localized: "无需订阅或恢复购买")
        }
    }
}

struct ProUnlockedView: View {
    @State private var selectedOption: ProAccessOption = .sync
    let onDone: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            proPane
            detailsPane
        }
        .frame(width: ProWindowMetrics.width, height: ProWindowMetrics.height)
        .background(ProWindowPalette.right)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .preferredColorScheme(.light)
    }

    private var proPane: some View {
        ZStack {
            ProWindowPalette.left

            Text("PRO")
                .font(.system(size: 96, weight: .heavy, design: .rounded))
                .foregroundStyle(LinearGradient(
                    colors: [Color(red: 0.12, green: 0.47, blue: 0.39), FlowPalette.focus],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .shadow(color: FlowPalette.focus.opacity(0.24), radius: 18, y: 7)
                .position(x: ProWindowMetrics.leftPaneWidth / 2, y: 286)
        }
        .frame(width: ProWindowMetrics.leftPaneWidth, height: ProWindowMetrics.height)
    }

    private var detailsPane: some View {
        ZStack(alignment: .topLeading) {
            ProWindowPalette.right

            Text(ProUnlockedContract.headline)
                .font(.system(size: 27, weight: .bold))
                .frame(width: ProWindowMetrics.rightContentWidth, alignment: .leading)
                .position(x: 167.5, y: 41)

            Text(ProUnlockedContract.message)
                .font(.system(size: 13))
                .foregroundStyle(.primary.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: ProWindowMetrics.rightContentWidth, alignment: .leading)
                .position(x: 167.5, y: 91)

            featureList
                .position(x: 167.5, y: 170)

            optionList
                .position(x: 167.5, y: 318)

            Text("无需购买  ·  不设付费墙")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.primary.opacity(0.72))
                .frame(width: ProWindowMetrics.rightContentWidth)
                .position(x: 167.5, y: 420)

            Button("已全部解锁", action: onDone)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(
                    width: ProWindowMetrics.rightContentWidth,
                    height: ProWindowMetrics.primaryButtonHeight
                )
                .background(FlowPalette.focus, in: Capsule())
                .buttonStyle(.plain)
                .position(x: 167.5, y: 464)
        }
        .frame(width: ProWindowMetrics.rightPaneWidth, height: ProWindowMetrics.height)
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(ProUnlockedContract.features, id: \.self) { feature in
                HStack(spacing: 9) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(FlowPalette.focus)
                        .frame(width: 14)
                    Text(feature)
                        .font(.system(size: 13))
                        .lineLimit(ProWindowMetrics.featureLineLimit)
                        .minimumScaleFactor(ProWindowMetrics.featureMinimumScaleFactor)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(minHeight: 16)
            }
        }
        .frame(width: ProWindowMetrics.rightContentWidth, alignment: .leading)
    }

    private var optionList: some View {
        VStack(spacing: 10) {
            ForEach(ProAccessOption.allCases) { option in
                Button {
                    selectedOption = option
                } label: {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .stroke(selectedOption == option ? .white : FlowPalette.focus.opacity(0.24), lineWidth: 1.5)
                                .frame(width: 14, height: 14)
                            if selectedOption == option {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 8, weight: .bold))
                            }
                        }

                        VStack(alignment: .leading, spacing: 1) {
                            Text(option.title)
                                .font(.system(size: 13, weight: .semibold))
                            Text(option.detail)
                                .font(.system(size: 11))
                                .opacity(0.78)
                        }
                        Spacer()
                        if option == .sync {
                            Text("已启用")
                                .font(.system(size: 10, weight: .semibold))
                        }
                    }
                    .foregroundStyle(selectedOption == option ? Color.white : FlowPalette.focus.opacity(0.78))
                    .padding(.horizontal, 10)
                    .frame(
                        width: ProWindowMetrics.rightContentWidth,
                        height: ProWindowMetrics.optionHeight
                    )
                    .background(
                        selectedOption == option
                            ? FlowPalette.focus
                            : FlowPalette.focus.opacity(0.055),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

@MainActor
final class ProUnlockedWindowController: NSWindowController {
    static let shared = ProUnlockedWindowController()

    private init() {
        let size = NSSize(width: ProWindowMetrics.width, height: ProWindowMetrics.height)
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = NSHostingController(rootView:
            ProUnlockedView { [weak window] in
                window?.close()
            }
            .ignoresSafeArea()
            .frame(
                width: ProWindowMetrics.width,
                height: ProWindowMetrics.windowContentHeight,
                alignment: .top
            )
        )
        window.setFrame(NSRect(origin: .zero, size: size), display: false)
        window.title = "NanaFlow Pro"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.standardWindowButton(.zoomButton)?.isEnabled = false
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        guard let window else { return }
        let target = NSSize(width: ProWindowMetrics.width, height: ProWindowMetrics.height)
        var frame = window.frame
        frame.size = target
        window.setFrame(frame, display: true)
        window.center()
        showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}
