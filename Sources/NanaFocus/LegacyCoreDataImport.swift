import Foundation

/// The key/value operations the legacy importer needs from the controller's own
/// preferences domain. Tests supply an in-memory store instead of `.standard`.
protocol LegacyCoreDataStoring: AnyObject {
    func object(forKey key: String) -> Any?
    func set(_ value: Any?, forKey key: String)
}

extension UserDefaults: LegacyCoreDataStoring {}

enum LegacyCoreDataImportOutcome: Equatable, Sendable {
    case imported(writtenKeys: [String])
    case alreadyPresent
}

enum LegacyCoreDataImportError: Error, Equatable, Sendable {
    case unreadableFile
    case incompleteData
    case undecodableData
    case sourceTimerRunning
    case unsafeLaunchSettings
    case targetTimerRunning
    case conflictingData
    case writeVerificationFailed

    /// Generic, localized copy only: never echoes file contents or raw errors.
    var localizedMessage: String {
        switch self {
        case .unreadableFile:
            String(localized: "无法读取所选文件。未做任何更改。")
        case .incompleteData:
            String(localized: "所选文件不包含完整的 NanaFlow 旧版数据。未做任何更改。")
        case .undecodableData:
            String(localized: "当前版本无法读取所选旧版数据。未做任何更改。")
        case .sourceTimerRunning:
            String(localized: "旧版数据中的计时器仍在运行。请先在旧版中暂停后再导入。未做任何更改。")
        case .unsafeLaunchSettings:
            String(localized: "旧版设置开启了启动时开始计时、启动时重置周期或定时器同步。请先在旧版中关闭后再导入。未做任何更改。")
        case .targetTimerRunning:
            String(localized: "请先暂停当前计时再导入。未做任何更改。")
        case .conflictingData:
            String(localized: "当前已有不同的数据或会话记录。为避免覆盖，未做任何更改。")
        case .writeVerificationFailed:
            String(localized: "导入后的校验未通过。请退出 NanaFlow 后再检查数据。")
        }
    }
}

/// Validates a user-selected legacy NanaFlow preferences file and plans an
/// import of only the four existing core keys. Nothing here writes; the plan
/// keeps the original `Data` bytes so the controller can store them verbatim.
@MainActor
struct LegacyCoreDataImportPlan {
    static let maximumFileSize = 16 * 1024 * 1024
    static let requiredKeys = [
        TimerPersistence.storageKey,
        TimerPreferencesPersistence.storageKey,
        SessionHistoryPersistence.storageKey,
    ]
    static let optionalKeys = [SessionTagPersistence.storageKey]

    let engine: TimerEngine
    let preferences: TimerPreferences
    let sessions: [FocusSession]
    let tags: SessionTagSettings?
    /// Keys absent from the target, with the source bytes to store unchanged.
    let writes: [(key: String, data: Data)]

    static func readPropertyList(at url: URL) throws -> [String: Any] {
        guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              size > 0, size <= maximumFileSize,
              let data = try? Data(contentsOf: url) else { throw LegacyCoreDataImportError.unreadableFile }
        return try propertyList(from: data)
    }

    static func propertyList(from data: Data) throws -> [String: Any] {
        guard !data.isEmpty, data.count <= maximumFileSize,
              let dictionary = (try? PropertyListSerialization.propertyList(from: data, options: [], format: nil))
                as? [String: Any] else { throw LegacyCoreDataImportError.unreadableFile }
        return dictionary
    }

    /// Every rule is checked before the caller writes anything: the three
    /// required values must be present, be `Data`, and decode with the current
    /// models; the target may only lack a key or already hold identical bytes.
    static func make(
        source: [String: Any],
        target: any LegacyCoreDataStoring,
        targetTimerRunning: Bool,
        targetHasHistory: Bool
    ) throws -> LegacyCoreDataImportPlan {
        var sourceData: [String: Data] = [:]
        for key in requiredKeys {
            guard let data = source[key] as? Data else { throw LegacyCoreDataImportError.incompleteData }
            sourceData[key] = data
        }
        for key in optionalKeys where source[key] != nil {
            guard let data = source[key] as? Data else { throw LegacyCoreDataImportError.incompleteData }
            sourceData[key] = data
        }

        let decoder = JSONDecoder()
        guard let engine = try? decoder.decode(TimerEngine.self, from: sourceData[TimerPersistence.storageKey]!),
              let preferences = try? decoder.decode(
                TimerPreferences.self, from: sourceData[TimerPreferencesPersistence.storageKey]!
              ),
              let sessions = try? decoder.decode(
                [FocusSession].self, from: sourceData[SessionHistoryPersistence.storageKey]!
              ) else { throw LegacyCoreDataImportError.undecodableData }
        var tags: SessionTagSettings?
        if let tagData = sourceData[SessionTagPersistence.storageKey] {
            guard let decoded = try? decoder.decode(SessionTagSettings.self, from: tagData) else {
                throw LegacyCoreDataImportError.undecodableData
            }
            tags = decoded
        }

        guard !engine.state.isRunning else { throw LegacyCoreDataImportError.sourceTimerRunning }
        guard !preferences.startTimerOnLaunch,
              !preferences.resetCycleOnLaunch,
              !preferences.timerSyncEnabled else { throw LegacyCoreDataImportError.unsafeLaunchSettings }
        guard !targetTimerRunning else { throw LegacyCoreDataImportError.targetTimerRunning }

        var writes: [(key: String, data: Data)] = []
        for key in requiredKeys + optionalKeys {
            guard let data = sourceData[key] else { continue }
            switch target.object(forKey: key) {
            case nil:
                writes.append((key: key, data: data))
            case let existing as Data where existing == data:
                continue
            default:
                throw LegacyCoreDataImportError.conflictingData
            }
        }
        // Existing history is never merged or replaced: only a no-op where
        // every core value is already byte-identical is accepted.
        if targetHasHistory, !writes.isEmpty { throw LegacyCoreDataImportError.conflictingData }

        return LegacyCoreDataImportPlan(
            engine: engine,
            preferences: preferences,
            sessions: sessions,
            tags: tags,
            writes: writes
        )
    }
}
