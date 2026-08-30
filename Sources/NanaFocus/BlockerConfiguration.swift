import Foundation

enum BlockerMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case block
    case allow

    var id: Self { self }
}

enum WebBlockerBrowser: String, Codable, CaseIterable, Identifiable, Sendable {
    case safari
    case chrome
    case edge
    case brave
    case vivaldi
    case opera
    case sidekick

    var id: Self { self }

    var title: String {
        switch self {
        case .safari: "Safari"
        case .chrome: "Chrome"
        case .edge: "Edge"
        case .brave: "Brave"
        case .vivaldi: "Vivaldi"
        case .opera: "Opera"
        case .sidekick: "Sidekick"
        }
    }

    var bundleIdentifier: String {
        switch self {
        case .safari: "com.apple.Safari"
        case .chrome: "com.google.Chrome"
        case .edge: "com.microsoft.edgemac"
        case .brave: "com.brave.Browser"
        case .vivaldi: "com.vivaldi.Vivaldi"
        case .opera: "com.operasoftware.Opera"
        case .sidekick: "com.pushplaylabs.sidekick"
        }
    }
}

struct BlockerConfiguration: Codable, Equatable, Sendable {
    static let standard = BlockerConfiguration(
        mode: .block,
        webBrowser: .safari,
        appBundleIdentifiers: [],
        websitePatterns: []
    )

    var mode: BlockerMode
    var webBrowser: WebBlockerBrowser
    var appBundleIdentifiers: [String]
    var websitePatterns: [String]

    init(
        mode: BlockerMode,
        webBrowser: WebBlockerBrowser = .safari,
        appBundleIdentifiers: [String],
        websitePatterns: [String]
    ) {
        self.mode = mode
        self.webBrowser = webBrowser
        self.appBundleIdentifiers = appBundleIdentifiers
        self.websitePatterns = websitePatterns
    }

    private enum CodingKeys: String, CodingKey {
        case mode
        case webBrowser
        case appBundleIdentifiers
        case websitePatterns
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mode = try container.decode(BlockerMode.self, forKey: .mode)
        webBrowser = try container.decodeIfPresent(WebBlockerBrowser.self, forKey: .webBrowser) ?? .safari
        appBundleIdentifiers = try container.decode([String].self, forKey: .appBundleIdentifiers)
        websitePatterns = try container.decode([String].self, forKey: .websitePatterns)
    }

    func shouldBlockApp(bundleIdentifier: String) -> Bool {
        appBundleIdentifiers.contains(bundleIdentifier)
    }

    func shouldBlockURL(_ url: String) -> Bool {
        let value = url.lowercased()
        let listed = websitePatterns.contains { pattern in
            let normalized = pattern.lowercased()
            if normalized.hasPrefix("*") {
                return value == String(normalized.dropFirst())
            }
            return value.contains(normalized)
        }
        return mode == .block ? listed : !listed
    }
}

@MainActor
protocol BlockerConfigurationPersisting {
    func load() -> BlockerConfiguration?
    func save(_ configuration: BlockerConfiguration) throws
}

struct BlockerConfigurationPersistence: BlockerConfigurationPersisting {
    static let storageKey = "blockerConfiguration.v1"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> BlockerConfiguration? {
        guard let data = defaults.data(forKey: Self.storageKey) else { return nil }
        return try? JSONDecoder().decode(BlockerConfiguration.self, from: data)
    }

    func save(_ configuration: BlockerConfiguration) throws {
        defaults.set(try JSONEncoder().encode(configuration), forKey: Self.storageKey)
    }
}
