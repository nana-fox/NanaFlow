import Foundation

enum AppAppearance: String, Codable, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    var id: Self { self }
}

enum MenuBarIconStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case `default`
    case circle
    case list
    case progress

    static let allCases: [MenuBarIconStyle] = [.default, .circle, .progress]

    var id: Self { self }
}

enum CompletionSound: String, Codable, CaseIterable, Identifiable, Sendable {
    case none
    case alarmClock
    case bell
    case bells
    case bowl
    case chime
    case chord
    case harp
    case milestone
    case pulse
    case ripple
    case whistle

    static let menuOrder: [CompletionSound] = [
        .bell, .bowl, .alarmClock, .bells, .chime, .chord,
        .harp, .milestone, .pulse, .ripple, .whistle
    ]

    var id: Self { self }

    var fileName: String? {
        self == .none ? nil : "NanaFlow-\(rawValue).aiff"
    }

    func fileName(volume: Double) -> String? {
        guard self != .none else { return nil }
        let level = Int((min(max(volume, 0), 2) * 2).rounded())
        guard level > 0 else { return nil }
        return level == 4 ? fileName : "NanaFlow-\(rawValue)-v\(level).aiff"
    }
}

struct TimerPreferences: Codable, Equatable, Sendable {
    static let standard = TimerPreferences(
        autoStartFocus: false,
        autoStartBreaks: false,
        notificationSoundEnabled: true,
        commitmentModeEnabled: false,
        showWindowOnLaunch: false,
        resetCycleOnLaunch: false,
        startTimerOnLaunch: false,
        hideWindowWhenTimerStarts: true,
        fullscreenBreaks: false,
        tickingSoundEnabled: false,
        tickingVolume: 1,
        calendarSyncEnabled: false,
        timerSyncEnabled: false,
        notificationsEnabled: true,
        motivationalQuotesEnabled: true,
        appearance: .system,
        menuBarIconStyle: .default,
        showMenuBarTitle: false,
        coloredMenuBarIconDuringBreak: true,
        globalHotkeysEnabled: false,
        globalShortcuts: .flowDefault,
        focusCompletionSound: .bell,
        breakCompletionSound: .bell,
        notificationVolume: 1,
        sessionTitle: "NanaFlow"
    )

    var autoStartFocus: Bool
    var autoStartBreaks: Bool
    var notificationSoundEnabled: Bool
    var commitmentModeEnabled: Bool = false
    var showWindowOnLaunch: Bool
    var resetCycleOnLaunch: Bool
    var startTimerOnLaunch: Bool
    var hideWindowWhenTimerStarts: Bool
    var fullscreenBreaks: Bool
    var tickingSoundEnabled: Bool
    var tickingVolume: Double
    var calendarSyncEnabled: Bool
    var calendarIdentifier: String?
    var timerSyncEnabled: Bool
    var notificationsEnabled: Bool
    var motivationalQuotesEnabled: Bool
    var appearance: AppAppearance
    var menuBarIconStyle: MenuBarIconStyle
    var showMenuBarTitle: Bool
    var coloredMenuBarIconDuringBreak: Bool
    var globalHotkeysEnabled: Bool
    var globalShortcuts: GlobalShortcutSet
    var focusCompletionSound: CompletionSound
    var breakCompletionSound: CompletionSound
    var notificationVolume: Double
    var sessionTitle: String

    private enum CodingKeys: String, CodingKey {
        case autoStartFocus
        case autoStartBreaks
        case notificationSoundEnabled
        case commitmentModeEnabled
        case showWindowOnLaunch
        case resetCycleOnLaunch
        case startTimerOnLaunch
        case hideWindowWhenTimerStarts
        case fullscreenBreaks
        case tickingSoundEnabled
        case tickingVolume
        case calendarSyncEnabled
        case calendarIdentifier
        case timerSyncEnabled
        case notificationsEnabled
        case motivationalQuotesEnabled
        case appearance
        case menuBarIconStyle
        case showMenuBarTitle
        case coloredMenuBarIconDuringBreak
        case globalHotkeysEnabled
        case globalShortcuts
        case focusCompletionSound
        case breakCompletionSound
        case notificationVolume
        case sessionTitle
    }

    init(
        autoStartFocus: Bool,
        autoStartBreaks: Bool,
        notificationSoundEnabled: Bool,
        commitmentModeEnabled: Bool = false,
        showWindowOnLaunch: Bool = false,
        resetCycleOnLaunch: Bool = false,
        startTimerOnLaunch: Bool = false,
        hideWindowWhenTimerStarts: Bool = true,
        fullscreenBreaks: Bool = false,
        tickingSoundEnabled: Bool = false,
        tickingVolume: Double = 1,
        calendarSyncEnabled: Bool = false,
        calendarIdentifier: String? = nil,
        timerSyncEnabled: Bool = false,
        notificationsEnabled: Bool = true,
        motivationalQuotesEnabled: Bool = true,
        appearance: AppAppearance = .system,
        menuBarIconStyle: MenuBarIconStyle = .default,
        showMenuBarTitle: Bool = false,
        coloredMenuBarIconDuringBreak: Bool = true,
        globalHotkeysEnabled: Bool = false,
        globalShortcuts: GlobalShortcutSet = .flowDefault,
        focusCompletionSound: CompletionSound? = nil,
        breakCompletionSound: CompletionSound? = nil,
        notificationVolume: Double = 1,
        sessionTitle: String = "NanaFlow"
    ) {
        self.autoStartFocus = autoStartFocus
        self.autoStartBreaks = autoStartBreaks
        self.notificationSoundEnabled = notificationSoundEnabled
        self.commitmentModeEnabled = commitmentModeEnabled
        self.showWindowOnLaunch = showWindowOnLaunch
        self.resetCycleOnLaunch = resetCycleOnLaunch
        self.startTimerOnLaunch = startTimerOnLaunch
        self.hideWindowWhenTimerStarts = hideWindowWhenTimerStarts
        self.fullscreenBreaks = fullscreenBreaks
        self.tickingSoundEnabled = tickingSoundEnabled
        self.tickingVolume = min(max(tickingVolume, 0), 2)
        self.calendarSyncEnabled = calendarSyncEnabled
        self.calendarIdentifier = calendarIdentifier
        self.timerSyncEnabled = timerSyncEnabled
        self.notificationsEnabled = notificationsEnabled
        self.motivationalQuotesEnabled = motivationalQuotesEnabled
        self.appearance = appearance
        self.menuBarIconStyle = menuBarIconStyle
        self.showMenuBarTitle = showMenuBarTitle
        self.coloredMenuBarIconDuringBreak = coloredMenuBarIconDuringBreak
        self.globalHotkeysEnabled = globalHotkeysEnabled
        self.globalShortcuts = globalShortcuts
        let legacySound: CompletionSound = notificationSoundEnabled ? .bell : .none
        self.focusCompletionSound = focusCompletionSound ?? legacySound
        self.breakCompletionSound = breakCompletionSound ?? legacySound
        self.notificationVolume = min(max(notificationVolume, 0), 2)
        self.sessionTitle = sessionTitle
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        autoStartFocus = try container.decode(Bool.self, forKey: .autoStartFocus)
        autoStartBreaks = try container.decode(Bool.self, forKey: .autoStartBreaks)
        notificationSoundEnabled = try container.decode(Bool.self, forKey: .notificationSoundEnabled)
        commitmentModeEnabled = try container.decodeIfPresent(Bool.self, forKey: .commitmentModeEnabled) ?? false
        showWindowOnLaunch = try container.decodeIfPresent(Bool.self, forKey: .showWindowOnLaunch) ?? false
        resetCycleOnLaunch = try container.decodeIfPresent(Bool.self, forKey: .resetCycleOnLaunch) ?? false
        startTimerOnLaunch = try container.decodeIfPresent(Bool.self, forKey: .startTimerOnLaunch) ?? false
        hideWindowWhenTimerStarts = try container.decodeIfPresent(Bool.self, forKey: .hideWindowWhenTimerStarts) ?? true
        fullscreenBreaks = try container.decodeIfPresent(Bool.self, forKey: .fullscreenBreaks) ?? false
        tickingSoundEnabled = try container.decodeIfPresent(Bool.self, forKey: .tickingSoundEnabled) ?? false
        tickingVolume = min(max(try container.decodeIfPresent(Double.self, forKey: .tickingVolume) ?? 1, 0), 2)
        calendarSyncEnabled = try container.decodeIfPresent(Bool.self, forKey: .calendarSyncEnabled) ?? false
        calendarIdentifier = try container.decodeIfPresent(String.self, forKey: .calendarIdentifier)
        timerSyncEnabled = try container.decodeIfPresent(Bool.self, forKey: .timerSyncEnabled) ?? false
        notificationsEnabled = try container.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? true
        motivationalQuotesEnabled = try container.decodeIfPresent(Bool.self, forKey: .motivationalQuotesEnabled) ?? true
        appearance = try container.decodeIfPresent(AppAppearance.self, forKey: .appearance) ?? .system
        menuBarIconStyle = try container.decodeIfPresent(MenuBarIconStyle.self, forKey: .menuBarIconStyle) ?? .default
        showMenuBarTitle = try container.decodeIfPresent(Bool.self, forKey: .showMenuBarTitle) ?? false
        coloredMenuBarIconDuringBreak = try container.decodeIfPresent(Bool.self, forKey: .coloredMenuBarIconDuringBreak) ?? true
        globalHotkeysEnabled = try container.decodeIfPresent(Bool.self, forKey: .globalHotkeysEnabled) ?? false
        globalShortcuts = try container.decodeIfPresent(GlobalShortcutSet.self, forKey: .globalShortcuts) ?? .flowDefault
        let legacySound: CompletionSound = notificationSoundEnabled ? .bell : .none
        focusCompletionSound = try container.decodeIfPresent(CompletionSound.self, forKey: .focusCompletionSound) ?? legacySound
        breakCompletionSound = try container.decodeIfPresent(CompletionSound.self, forKey: .breakCompletionSound) ?? legacySound
        notificationVolume = min(max(try container.decodeIfPresent(Double.self, forKey: .notificationVolume) ?? 1, 0), 2)
        sessionTitle = try container.decodeIfPresent(String.self, forKey: .sessionTitle) ?? "NanaFlow"
    }
}

@MainActor
protocol TimerPreferencesPersisting {
    func load() -> TimerPreferences?
    func save(_ preferences: TimerPreferences) throws
}

struct TimerPreferencesPersistence: TimerPreferencesPersisting {
    static let storageKey = "timerPreferences.v1"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> TimerPreferences? {
        guard let data = defaults.data(forKey: Self.storageKey) else { return nil }
        return try? JSONDecoder().decode(TimerPreferences.self, from: data)
    }

    func save(_ preferences: TimerPreferences) throws {
        defaults.set(try JSONEncoder().encode(preferences), forKey: Self.storageKey)
    }
}
