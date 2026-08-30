import Foundation

struct SessionTagSettings: Codable, Equatable, Sendable {
    static let palette = ["#FF5B8CC0", "#FFE2B658", "#FFD96D5A"]
    static var standard: SessionTagSettings {
        SessionTagSettings(
            tags: [
                String(localized: "工作"),
                String(localized: "个人"),
                String(localized: "学习"),
            ],
            selectedTag: nil
        )
    }

    var tags: [String]
    var selectedTag: String?
    var colors: [String: String]

    init(tags: [String], selectedTag: String?, colors: [String: String] = [:]) {
        self.tags = tags
        self.selectedTag = selectedTag
        self.colors = colors
        for (index, tag) in tags.enumerated() where self.colors[tag] == nil {
            self.colors[tag] = Self.palette[index % Self.palette.count]
        }
    }

    func colorHex(for tag: String?) -> String {
        guard let tag else { return "#FF267866" }
        return colors[tag] ?? "#FF267866"
    }

    private enum CodingKeys: String, CodingKey {
        case tags
        case selectedTag
        case colors
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            tags: try container.decode([String].self, forKey: .tags),
            selectedTag: try container.decodeIfPresent(String.self, forKey: .selectedTag),
            colors: try container.decodeIfPresent([String: String].self, forKey: .colors) ?? [:]
        )
    }
}

@MainActor
protocol SessionTagPersisting {
    func load() -> SessionTagSettings?
    func save(_ settings: SessionTagSettings) throws
}

struct SessionTagPersistence: SessionTagPersisting {
    static let storageKey = "sessionTags.v1"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> SessionTagSettings? {
        guard let data = defaults.data(forKey: Self.storageKey) else { return nil }
        return try? JSONDecoder().decode(SessionTagSettings.self, from: data)
    }

    func save(_ settings: SessionTagSettings) throws {
        defaults.set(try JSONEncoder().encode(settings), forKey: Self.storageKey)
    }
}
