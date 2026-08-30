import EventKit

@MainActor
protocol FocusSessionCalendarRecording {
    func record(_ session: FocusSession, calendarIdentifier: String?)
}

@MainActor
final class FocusSessionCalendarRecorder: FocusSessionCalendarRecording {
    private let store = EKEventStore()

    func record(_ session: FocusSession, calendarIdentifier: String?) {
        Task { @MainActor in
            guard (try? await store.requestFullAccessToEvents()) == true,
                  let calendar = calendarIdentifier.flatMap(store.calendar(withIdentifier:))
                    ?? store.defaultCalendarForNewEvents else { return }
            let event = EKEvent(eventStore: store)
            event.calendar = calendar
            event.title = session.tag.map { "NanaFlow · \($0)" } ?? "NanaFlow"
            event.startDate = session.startedAt
            event.endDate = session.endedAt
            event.notes = session.completed
                ? String(localized: "已完成的专注会话")
                : String(localized: "未完成的专注会话")
            try? store.save(event, span: .thisEvent)
        }
    }
}
