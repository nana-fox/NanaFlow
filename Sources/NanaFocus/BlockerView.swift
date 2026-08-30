import AppKit
import Observation
import SwiftUI

@MainActor
@Observable
final class BlockerController {
    static let shared = BlockerController()

    private(set) var configuration: BlockerConfiguration
    private(set) var errorMessage: String?

    @ObservationIgnored private let persistence: any BlockerConfigurationPersisting
    @ObservationIgnored private let browserController: any BrowserURLControlling
    @ObservationIgnored private let blockedAppNotifications: any BlockedAppNotificationScheduling
    @ObservationIgnored private var activationObserver: NSObjectProtocol?
    @ObservationIgnored private weak var timer: TimerController?
    @ObservationIgnored private var lastBrowserInspection = Date.distantPast

    init(
        persistence: any BlockerConfigurationPersisting = BlockerConfigurationPersistence(),
        browserController: any BrowserURLControlling = BrowserURLController(),
        blockedAppNotifications: any BlockedAppNotificationScheduling = BlockedAppNotificationScheduler()
    ) {
        self.persistence = persistence
        self.browserController = browserController
        self.blockedAppNotifications = blockedAppNotifications
        self.configuration = persistence.load() ?? .standard
    }

    func setMode(_ mode: BlockerMode) {
        configuration.mode = mode
        persist()
    }

    func setWebBrowser(_ browser: WebBlockerBrowser) {
        configuration.webBrowser = browser
        persist()
    }

    func addApplication(at url: URL) {
        guard let bundleIdentifier = Bundle(url: url)?.bundleIdentifier else {
            errorMessage = String(localized: "无法读取所选应用。")
            return
        }
        guard !configuration.appBundleIdentifiers.contains(bundleIdentifier) else { return }
        configuration.appBundleIdentifiers.append(bundleIdentifier)
        persist()
    }

    func removeApplication(bundleIdentifier: String) {
        configuration.appBundleIdentifiers.removeAll { $0 == bundleIdentifier }
        persist()
    }

    func addWebsite(_ pattern: String) {
        let trimmed = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !configuration.websitePatterns.contains(trimmed) else { return }
        configuration.websitePatterns.append(trimmed)
        persist()
    }

    func removeWebsite(_ pattern: String) {
        configuration.websitePatterns.removeAll { $0 == pattern }
        persist()
    }

    func dismissError() {
        errorMessage = nil
    }

    func startMonitoring(timer: TimerController) {
        self.timer = timer
        guard activationObserver == nil else { return }
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let processIdentifier = (
                notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            )?.processIdentifier else { return }
            Task { @MainActor [weak self] in
                self?.handleActivation(processIdentifier: processIdentifier)
            }
        }
    }

    func stopMonitoring() {
        guard let activationObserver else { return }
        NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
        self.activationObserver = nil
    }

    func inspectActiveBrowser(at date: Date = Date()) {
        guard date.timeIntervalSince(lastBrowserInspection) >= 0.75,
              let bundleIdentifier = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else { return }
        lastBrowserInspection = date
        inspectBrowser(bundleIdentifier: bundleIdentifier)
    }

    func inspectBrowser(bundleIdentifier: String) {
        guard let timer,
              timer.engine.state.isRunning,
              timer.engine.state.phase == .focus,
              bundleIdentifier == configuration.webBrowser.bundleIdentifier else { return }
        browserController.blockURLs(
            bundleIdentifier: bundleIdentifier,
            patterns: configuration.websitePatterns,
            mode: configuration.mode
        )
    }

    func handleBlockedApplicationActivation(
        applicationName: String,
        bundleIdentifier: String
    ) -> Bool {
        guard configuration.shouldBlockApp(bundleIdentifier: bundleIdentifier) else { return false }
        blockedAppNotifications.scheduleBlockedApplication(applicationName: applicationName)
        return true
    }

    private func handleActivation(processIdentifier: pid_t) {
        guard let timer,
              timer.engine.state.isRunning,
              timer.engine.state.phase == .focus,
              let application = NSRunningApplication(processIdentifier: processIdentifier),
              let bundleIdentifier = application.bundleIdentifier,
              bundleIdentifier != Bundle.main.bundleIdentifier else { return }
        inspectBrowser(bundleIdentifier: bundleIdentifier)
        guard handleBlockedApplicationActivation(
            applicationName: application.localizedName ?? bundleIdentifier,
            bundleIdentifier: bundleIdentifier
        ) else { return }
        application.hide()
        NSApplication.shared.activate()
    }

    private func persist() {
        do {
            try persistence.save(configuration)
            errorMessage = nil
        } catch {
            errorMessage = String(
                format: String(localized: "无法保存阻断规则：%@"),
                error.localizedDescription
            )
        }
    }
}

struct BlockerView: View {
    @Environment(\.dismissWindow) private var dismissWindow
    let controller: BlockerController
    let onBack: (() -> Void)?

    @State private var tab: BlockerTab
    @State private var selectedApp: String?
    @State private var selectedWebsite: String?
    @State private var websiteInput = ""
    @State private var showsHelp = false
    @State private var showsApplicationPicker = false

    init(
        controller: BlockerController,
        initialTab: BlockerTab = .apps,
        onBack: (() -> Void)? = nil
    ) {
        self.controller = controller
        self.onBack = onBack
        _tab = State(initialValue: initialTab)
    }

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                BlockerSegmentedControl(selection: $tab)

                HStack {
                Button {
                    if let onBack {
                        onBack()
                    } else {
                        dismissWindow(id: "blocker")
                    }
                } label: {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 17, weight: .medium))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("返回")

                Spacer()
                }
            }
            .offset(y: BlockerVisualMetrics.headerOffsetY)

            Group {
                if tab == .apps {
                    applicationList
                } else {
                    websiteList
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.white.opacity(0.62), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .padding(.horizontal, 15)
            .contextMenu {
                if tab == .websites {
                    ForEach(WebBlockerBrowser.allCases) { browser in
                        Toggle(browser.title, isOn: selectionBinding(controller.configuration.webBrowser == browser) {
                            controller.setWebBrowser(browser)
                        })
                    }
                    Divider()
                    Toggle("阻止", isOn: selectionBinding(controller.configuration.mode == .block) {
                        controller.setMode(.block)
                    })
                    Toggle("允许", isOn: selectionBinding(controller.configuration.mode == .allow) {
                        controller.setMode(.allow)
                    })
                }
            }

            HStack(spacing: 12) {
                Button { addItem() } label: { Image(systemName: "plus") }
                    .disabled(tab == .websites && websiteInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityLabel("添加")
                Button { removeSelectedItem() } label: { Image(systemName: "minus") }
                    .disabled(tab == .apps ? selectedApp == nil : selectedWebsite == nil)
                    .accessibilityLabel("移除")

                Spacer()

                Button { showsHelp.toggle() } label: { Image(systemName: "questionmark.circle") }
                    .accessibilityLabel("帮助")
                    .popover(isPresented: $showsHelp, arrowEdge: .bottom) {
                        BlockerHelpView(tab: tab)
                    }
            }
            .buttonStyle(.plain)
            .font(.system(size: 18))
            .padding(.horizontal, 15)
        }
        .padding(14)
        .frame(width: 380, height: 272)
        .background(FlowPalette.window)
        .fileImporter(
            isPresented: $showsApplicationPicker,
            allowedContentTypes: [.application],
            allowsMultipleSelection: false
        ) { result in
            guard case let .success(urls) = result, let url = urls.first else { return }
            controller.addApplication(at: url)
        }
        .fileDialogDefaultDirectory(URL(fileURLWithPath: "/Applications", isDirectory: true))
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

    private var applicationList: some View {
        List(controller.configuration.appBundleIdentifiers, id: \.self, selection: $selectedApp) { bundleIdentifier in
            HStack(spacing: 8) {
                if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                        .resizable()
                        .frame(width: 24, height: 24)
                    Text(Bundle(url: url)?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? url.deletingPathExtension().lastPathComponent)
                } else {
                    Image(systemName: "app.dashed")
                    Text(bundleIdentifier)
                }
            }
            .tag(bundleIdentifier)
        }
        .scrollContentBackground(.hidden)
    }

    private var websiteList: some View {
        VStack(spacing: 0) {
            TextField("输入网站名称", text: $websiteInput)
                .textFieldStyle(.plain)
                .onSubmit(addWebsite)
                .padding(.horizontal, 12)
                .frame(height: 36)

            Divider()

            List(controller.configuration.websitePatterns, id: \.self, selection: $selectedWebsite) { pattern in
                Text(pattern)
                    .tag(pattern)
            }
            .scrollContentBackground(.hidden)
        }
    }

    private func addItem() {
        if tab == .websites {
            addWebsite()
            return
        }

        showsApplicationPicker = true
    }

    private func addWebsite() {
        controller.addWebsite(websiteInput)
        websiteInput = ""
    }

    private func removeSelectedItem() {
        if let selectedApp, tab == .apps {
            controller.removeApplication(bundleIdentifier: selectedApp)
            self.selectedApp = nil
        } else if let selectedWebsite, tab == .websites {
            controller.removeWebsite(selectedWebsite)
            self.selectedWebsite = nil
        }
    }

    private func selectionBinding(_ selected: Bool, select: @escaping () -> Void) -> Binding<Bool> {
        Binding(
            get: { selected },
            set: { enabled in
                if enabled { select() }
            }
        )
    }

}

enum BlockerHelpContract {
    static var applicationBody: String {
        String(localized: "黑名单上的应用只会在正在运行的NanaFlow中被阻止。")
    }
    static var body: String {
        String(localized: """
        列表中的 URL 将在 NanaFlow 会话期间被阻止，而不是在休息时间或计时器暂停期间。

        您可以将列表转换为允许列表，即除列表中的 URL 外的所有 URL 将被阻止。

        您可以使用简单的关键字，例如 'facebook'，以阻止所有包含单词 'facebook' 的 URL，即您不需要 'www' 或 'http'。

        但是，如果您想要阻止特定域而不阻止站点的其他部分或某些子域，则可以使用前缀 '*'。

        例如：如果您将 *https://www.facebook.com 添加到列表中，则该确切 URL 将被阻止，但 https://business.facebook.com 将被允许。
        """)
    }
}

private struct BlockerHelpView: View {
    let tab: BlockerTab

    @ViewBuilder
    var body: some View {
        if tab == .apps {
            Text(BlockerHelpContract.applicationBody)
                .font(.system(size: 13))
                .padding(12)
                .fixedSize()
        } else {
            ScrollView {
                Text(BlockerHelpContract.body)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
            }
            .frame(width: 380, height: 390)
        }
    }
}

enum BlockerVisualMetrics {
    static let segmentWidth: CGFloat = 260
    static let segmentHeight: CGFloat = 28
    static let headerOffsetY: CGFloat = -5
}

private struct BlockerSegmentedControl: View {
    @Binding var selection: BlockerTab

    var body: some View {
        HStack(spacing: 0) {
            segment("应用", tab: .apps)
            segment("网页", tab: .websites)
        }
        .padding(2)
        .frame(
            width: BlockerVisualMetrics.segmentWidth,
            height: BlockerVisualMetrics.segmentHeight
        )
        .background(Color.primary.opacity(0.045), in: Capsule())
    }

    private func segment(_ title: String, tab: BlockerTab) -> some View {
        Button { selection = tab } label: {
            Text(LocalizedStringKey(title))
                .font(.system(size: 12, weight: .semibold))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    selection == tab ? Color.white.opacity(0.82) : Color.clear,
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
    }
}

enum BlockerTab {
    case apps
    case websites
}
