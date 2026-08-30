import AppKit
import XCTest
@testable import NanaFlow

@MainActor
final class BlockerConfigurationTests: XCTestCase {
    func testBlockListMatchesSelectedAppsAndWebsiteKeywords() {
        let configuration = BlockerConfiguration(
            mode: .block,
            appBundleIdentifiers: ["com.example.Chat"],
            websitePatterns: ["youtube", "*https://news.example.com"]
        )

        XCTAssertTrue(configuration.shouldBlockApp(bundleIdentifier: "com.example.Chat"))
        XCTAssertFalse(configuration.shouldBlockApp(bundleIdentifier: "com.example.Editor"))
        XCTAssertTrue(configuration.shouldBlockURL("https://www.youtube.com/watch?v=1"))
        XCTAssertTrue(configuration.shouldBlockURL("https://news.example.com"))
        XCTAssertFalse(configuration.shouldBlockURL("https://business.example.com"))
        XCTAssertEqual(BlockerMode.allCases.map(\.id), [.block, .allow])
        XCTAssertEqual(
            WebBlockerBrowser.allCases,
            [.safari, .chrome, .edge, .brave, .vivaldi, .opera, .sidekick]
        )
    }

    func testAppBlockerStaysABlockListWhileWebAllowListBlocksUnlistedSites() {
        let configuration = BlockerConfiguration(
            mode: .allow,
            appBundleIdentifiers: ["com.example.Editor"],
            websitePatterns: ["docs.example.com"]
        )

        XCTAssertTrue(configuration.shouldBlockApp(bundleIdentifier: "com.example.Editor"))
        XCTAssertFalse(configuration.shouldBlockApp(bundleIdentifier: "com.example.Chat"))
        XCTAssertFalse(configuration.shouldBlockURL("https://docs.example.com/guide"))
        XCTAssertTrue(configuration.shouldBlockURL("https://social.example.com"))
    }

    func testLegacyConfigurationDefaultsToSafariWithoutLosingWebListMode() throws {
        let data = try XCTUnwrap(
            #"{"mode":"allow","appBundleIdentifiers":[],"websitePatterns":["docs"]}"#
                .data(using: .utf8)
        )

        let configuration = try JSONDecoder().decode(BlockerConfiguration.self, from: data)

        XCTAssertEqual(configuration.mode, .allow)
        XCTAssertEqual(configuration.webBrowser, .safari)
    }

    func testBlockerConfigurationRoundTrips() throws {
        let suiteName = "BlockerConfigurationTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let persistence = BlockerConfigurationPersistence(defaults: defaults)
        let configuration = BlockerConfiguration(
            mode: .block,
            appBundleIdentifiers: ["com.example.Chat"],
            websitePatterns: ["social"]
        )

        try persistence.save(configuration)

        XCTAssertEqual(persistence.load(), configuration)
    }

    func testControllerPersistsWebsiteModeAndBrowserEdits() {
        let persistence = BlockerPersistenceSpy()
        let controller = BlockerController(persistence: persistence)

        controller.addWebsite("  youtube  ")
        controller.addWebsite("youtube")
        controller.setMode(.allow)
        controller.setWebBrowser(.chrome)

        XCTAssertEqual(controller.configuration.websitePatterns, ["youtube"])
        XCTAssertEqual(controller.configuration.mode, .allow)
        XCTAssertEqual(controller.configuration.webBrowser, .chrome)
        XCTAssertEqual(persistence.saved.count, 3)

        controller.removeWebsite("youtube")
        XCTAssertTrue(controller.configuration.websitePatterns.isEmpty)
    }

    func testControllerExposesPersistenceFailure() {
        let controller = BlockerController(persistence: BlockerPersistenceSpy(saveError: BlockerTestError.failed))

        controller.addWebsite("social")

        XCTAssertNotNil(controller.errorMessage)
        controller.dismissError()
        XCTAssertNil(controller.errorMessage)
    }

    func testControllerAddsAndRemovesApplicationBundle() throws {
        let persistence = BlockerPersistenceSpy()
        let controller = BlockerController(persistence: persistence)
        let bundleIdentifier = try XCTUnwrap(Bundle.main.bundleIdentifier)

        controller.addApplication(at: Bundle.main.bundleURL)

        XCTAssertEqual(controller.configuration.appBundleIdentifiers, [bundleIdentifier])
        controller.removeApplication(bundleIdentifier: bundleIdentifier)
        XCTAssertTrue(controller.configuration.appBundleIdentifiers.isEmpty)
    }

    func testControllerRejectsNonBundleApplicationURL() {
        let controller = BlockerController(persistence: BlockerPersistenceSpy())

        controller.addApplication(at: URL(fileURLWithPath: "/tmp"))

        XCTAssertNotNil(controller.errorMessage)
    }

    func testBlockedApplicationFeedbackRunsOnlyForConfiguredApp() {
        let notifications = BlockedAppNotificationSpy()
        let controller = BlockerController(
            persistence: BlockerPersistenceSpy(
                loaded: BlockerConfiguration(
                    mode: .block,
                    appBundleIdentifiers: ["com.example.Chat"],
                    websitePatterns: []
                )
            ),
            blockedAppNotifications: notifications
        )

        XCTAssertFalse(controller.handleBlockedApplicationActivation(
            applicationName: "Notes",
            bundleIdentifier: "com.example.Notes"
        ))
        XCTAssertTrue(controller.handleBlockedApplicationActivation(
            applicationName: "Chat",
            bundleIdentifier: "com.example.Chat"
        ))
        XCTAssertEqual(notifications.applicationNames, ["Chat"])
    }

    func testMonitoringCanStartOnlyOnceAndStopSafely() {
        let controller = BlockerController(persistence: BlockerPersistenceSpy())
        let timer = TimerController(
            persistence: BlockerTimerPersistence(),
            preferencesPersistence: BlockerPreferencesPersistence(),
            historyPersistence: BlockerHistoryPersistence(),
            notifications: BlockerNotifications(),
            now: Date(timeIntervalSince1970: 100)
        )

        controller.startMonitoring(timer: timer)
        controller.startMonitoring(timer: timer)
        controller.stopMonitoring()
        controller.stopMonitoring()

        XCTAssertFalse(timer.engine.state.isRunning)
    }

    func testWebsiteBlockingInspectsOnlyFlowsSelectedBrowserDuringFocus() {
        let browser = BrowserControllerSpy()
        let controller = BlockerController(
            persistence: BlockerPersistenceSpy(
                loaded: BlockerConfiguration(
                    mode: .block,
                    appBundleIdentifiers: [],
                    websitePatterns: ["youtube"]
                )
            ),
            browserController: browser
        )
        let timer = TimerController(
            persistence: BlockerTimerPersistence(),
            preferencesPersistence: BlockerPreferencesPersistence(),
            historyPersistence: BlockerHistoryPersistence(),
            notifications: BlockerNotifications(),
            now: Date(timeIntervalSince1970: 100)
        )
        controller.startMonitoring(timer: timer)

        controller.inspectBrowser(bundleIdentifier: "com.google.Chrome")
        XCTAssertTrue(browser.requests.isEmpty)

        timer.toggle(at: Date(timeIntervalSince1970: 100))
        controller.inspectBrowser(bundleIdentifier: "com.google.Chrome")
        XCTAssertTrue(browser.requests.isEmpty)

        controller.inspectBrowser(bundleIdentifier: "com.apple.Safari")

        XCTAssertEqual(browser.requests, [
            .init(bundleIdentifier: "com.apple.Safari", patterns: ["youtube"], mode: .block)
        ])
    }

    func testBrowserBlockingScriptMatchesFlowsAllTabsContract() throws {
        let blockedPage = "file:///Applications/NanaFlow.app/Contents/Resources/Blocked.html"
        let blockScript = try XCTUnwrap(BrowserURLController.blockingScript(
            browser: .chrome,
            patterns: ["youtube", "reddit"],
            mode: .block,
            blockedPageURL: blockedPage
        ))
        XCTAssertTrue(blockScript.contains("URL of every tab of every window"))
        XCTAssertTrue(blockScript.contains("repeat with someUrl in urlList"))
        XCTAssertTrue(blockScript.contains("URL contains someUrl"))
        XCTAssertTrue(blockScript.contains("tell application \"Google Chrome\""))
        XCTAssertFalse(blockScript.contains("active tab"))

        let allowScript = try XCTUnwrap(BrowserURLController.blockingScript(
            browser: .safari,
            patterns: ["docs.example.com", "calendar.example.com"],
            mode: .allow,
            blockedPageURL: blockedPage
        ))
        XCTAssertTrue(allowScript.contains("URL does not contain \"docs.example.com\""))
        XCTAssertTrue(allowScript.contains("URL does not contain \"calendar.example.com\""))
        XCTAssertTrue(allowScript.contains("URL of every tab of every window"))
        XCTAssertFalse(allowScript.contains("active tab"))

        for source in [blockScript, allowScript] {
            var error: NSDictionary?
            XCTAssertTrue(NSAppleScript(source: source)?.compileAndReturnError(&error) == true, "\(error ?? [:])")
        }

        let escapedScript = try XCTUnwrap(BrowserURLController.blockingScript(
            browser: .safari,
            patterns: [#"quote\"\\test"#],
            mode: .block,
            blockedPageURL: blockedPage
        ))
        var escapingError: NSDictionary?
        XCTAssertTrue(
            NSAppleScript(source: escapedScript)?.compileAndReturnError(&escapingError) == true,
            "\(escapingError ?? [:])"
        )
    }

    func testBlockerWebUIUsesFlowsInlineEntryAndBrowserSelection() throws {
        let repositoryURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFocus/BlockerView.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(source.contains("TextField(\"输入网站名称\", text: $websiteInput)"))
        XCTAssertTrue(source.contains("controller.setWebBrowser"))
        XCTAssertFalse(source.contains("✓"))
        XCTAssertTrue(source.contains("Toggle(browser.title, isOn:"))
        XCTAssertTrue(source.contains("Toggle(\"阻止\", isOn:"))
        XCTAssertTrue(source.contains("Toggle(\"允许\", isOn:"))
        XCTAssertFalse(source.contains(".alert(\"添加网页\""))
    }

    func testBlockerAppPickerUsesNonblockingNativeImporter() throws {
        let repositoryURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryURL.appendingPathComponent("Sources/NanaFocus/BlockerView.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(source.contains("@State private var showsApplicationPicker = false"))
        XCTAssertTrue(source.contains(".fileImporter("))
        XCTAssertTrue(source.contains("allowedContentTypes: [.application]"))
        XCTAssertTrue(source.contains("allowsMultipleSelection: false"))
        XCTAssertTrue(source.contains(
            ".fileDialogDefaultDirectory(URL(fileURLWithPath: \"/Applications\", isDirectory: true))"
        ))
        XCTAssertTrue(source.contains("controller.addApplication(at: url)"))
        XCTAssertFalse(source.contains("panel.runModal()"))
    }

    func testBlockerHelpIsLocalAndMatchesFlowBehaviorContract() {
        XCTAssertEqual(
            BlockerHelpContract.applicationBody,
            "黑名单上的应用只会在正在运行的NanaFlow中被阻止。"
        )
        XCTAssertTrue(BlockerHelpContract.body.contains("列表中的 URL 将在 NanaFlow 会话期间被阻止"))
        XCTAssertTrue(BlockerHelpContract.body.contains("允许列表"))
        XCTAssertTrue(BlockerHelpContract.body.contains("'facebook'"))
        XCTAssertTrue(BlockerHelpContract.body.contains("*https://www.facebook.com"))
        XCTAssertTrue(BlockerHelpContract.body.contains("https://business.facebook.com"))
    }

    func testBlockedPageUsesNanaFlowAssetAndFlowsVisibleCopy() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "Blocked", withExtension: "html"))
        let html = try String(contentsOf: url, encoding: .utf8)

        XCTAssertTrue(html.contains(#"<img src="NanaFlowBlockedIcon.png""#))
        XCTAssertNotNil(Bundle.main.url(forResource: "NanaFlowBlockedIcon", withExtension: "png"))
        XCTAssertTrue(html.contains("width=\"150\""))
        XCTAssertTrue(html.contains("<h1>封锁</h1>"))
        XCTAssertTrue(html.contains("该网站在您的黑名单中。 NanaFlow 为您屏蔽了它，因此您可以专注于您的任务。"))
        XCTAssertTrue(html.contains("transform: translateX(-50%) translateY(-50%)"))
        XCTAssertTrue(html.contains("white-space: nowrap"))
        XCTAssertTrue(html.contains("#C8E1D7"))
        XCTAssertTrue(html.contains("#194E42"))
    }
}

@MainActor
private final class BlockerPersistenceSpy: BlockerConfigurationPersisting {
    private let saveError: Error?
    private let loaded: BlockerConfiguration
    private(set) var saved: [BlockerConfiguration] = []

    init(loaded: BlockerConfiguration = .standard, saveError: Error? = nil) {
        self.loaded = loaded
        self.saveError = saveError
    }

    func load() -> BlockerConfiguration? { loaded }

    func save(_ configuration: BlockerConfiguration) throws {
        if let saveError { throw saveError }
        saved.append(configuration)
    }
}

private enum BlockerTestError: Error {
    case failed
}

@MainActor
private struct BlockerTimerPersistence: TimerPersisting {
    func load() -> TimerEngine? { nil }
    func save(_: TimerEngine) throws {}
}

@MainActor
private struct BlockerPreferencesPersistence: TimerPreferencesPersisting {
    func load() -> TimerPreferences? { nil }
    func save(_: TimerPreferences) throws {}
}

@MainActor
private struct BlockerHistoryPersistence: SessionHistoryPersisting {
    func load() -> [FocusSession] { [] }
    func save(_: [FocusSession]) throws {}
}

@MainActor
private struct BlockerNotifications: SessionNotificationScheduling {
    func scheduleCompletion(at _: Date, nextPhase _: SessionPhase, sound _: CompletionSound, volume _: Double, quote _: String?) {}
    func cancelCompletion() {}
}

@MainActor
private final class BrowserControllerSpy: BrowserURLControlling {
    struct Request: Equatable {
        let bundleIdentifier: String
        let patterns: [String]
        let mode: BlockerMode
    }

    private(set) var requests: [Request] = []

    func blockURLs(bundleIdentifier: String, patterns: [String], mode: BlockerMode) {
        requests.append(.init(bundleIdentifier: bundleIdentifier, patterns: patterns, mode: mode))
    }
}

@MainActor
private final class BlockedAppNotificationSpy: BlockedAppNotificationScheduling {
    private(set) var applicationNames: [String] = []

    func scheduleBlockedApplication(applicationName: String) {
        applicationNames.append(applicationName)
    }
}
