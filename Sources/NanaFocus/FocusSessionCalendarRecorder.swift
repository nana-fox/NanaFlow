import EventKit

enum CalendarRecordingError: Error, Equatable, Sendable {
    case targetUnavailable
    case accessDenied
    case saveFailed

    var message: String {
        switch self {
        case .targetUnavailable:
            String(localized: "无法写入日历。请在设置中重新选择可写入的日历。")
        case .accessDenied:
            String(localized: "无法写入日历。请允许完整的日历访问权限后重试。")
        case .saveFailed:
            String(localized: "无法保存日历事件。请检查所选日历后重试。")
        }
    }
}

@MainActor
protocol FocusSessionCalendarRecording {
    func record(
        _ session: FocusSession,
        calendarIdentifier: String?,
        completion: @escaping @MainActor (Result<Void, CalendarRecordingError>) -> Void
    )
}

@MainActor
final class FocusSessionCalendarRecorder: FocusSessionCalendarRecording {
    struct Destination {
        let allowsContentModifications: Bool
        let save: @MainActor (FocusSession) throws -> Void
    }

    private let requestAuthorization: @MainActor () async throws -> Bool
    private let destination: @MainActor (String) -> Destination?

    convenience init() {
        let store = EKEventStore()
        self.init(
            requestAuthorization: { try await store.requestFullAccessToEvents() },
            destination: { identifier in
                guard let calendar = store.calendar(withIdentifier: identifier) else { return nil }
                return Destination(allowsContentModifications: calendar.allowsContentModifications) { session in
                    let event = EKEvent(eventStore: store)
                    event.calendar = calendar
                    event.title = session.tag.map { "NanaFlow · \($0)" } ?? "NanaFlow"
                    event.startDate = session.startedAt
                    event.endDate = session.endedAt
                    event.notes = session.completed
                        ? String(localized: "已完成的专注会话")
                        : String(localized: "未完成的专注会话")
                    try store.save(event, span: .thisEvent)
                }
            }
        )
    }

    init(
        requestAuthorization: @escaping @MainActor () async throws -> Bool,
        destination: @escaping @MainActor (String) -> Destination?
    ) {
        self.requestAuthorization = requestAuthorization
        self.destination = destination
    }

    func record(
        _ session: FocusSession,
        calendarIdentifier: String?,
        completion: @escaping @MainActor (Result<Void, CalendarRecordingError>) -> Void
    ) {
        guard let calendarIdentifier,
              !calendarIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            completion(.failure(.targetUnavailable))
            return
        }
        Task { @MainActor in
            guard (try? await requestAuthorization()) == true else {
                completion(.failure(.accessDenied))
                return
            }
            guard let destination = destination(calendarIdentifier), destination.allowsContentModifications else {
                completion(.failure(.targetUnavailable))
                return
            }
            do {
                try destination.save(session)
                completion(.success(()))
            } catch {
                completion(.failure(.saveFailed))
            }
        }
    }
}
