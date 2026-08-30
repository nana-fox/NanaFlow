import Foundation

enum SessionExporter {
    static func csv(
        sessions: [FocusSession],
        timeZone: TimeZone = .current,
        locale: Locale = .current
    ) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = locale
        dateFormatter.timeZone = timeZone
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        let durationFormatter = DateComponentsFormatter()
        durationFormatter.unitsStyle = .abbreviated
        durationFormatter.allowedUnits = [.hour, .minute, .second]
        durationFormatter.zeroFormattingBehavior = .pad
        var calendar = Calendar.current
        calendar.locale = locale
        durationFormatter.calendar = calendar

        let rows = sessions.map { session in
            let interruptionDuration = session.interruptions.reduce(0) { total, interruption in
                guard let resumedAt = interruption.resumedAt else { return total }
                return total + max(0, resumedAt.timeIntervalSince(interruption.stoppedAt))
            }
            let totalTime = session.completed
                ? max(0, session.endedAt.timeIntervalSince(session.startedAt) - interruptionDuration)
                : 0
            return [
                quotedCSVField(session.title.isEmpty ? sessionName(for: session.type) : session.title),
                dateFormatter.string(from: session.startedAt),
                session.completed ? dateFormatter.string(from: session.endedAt) : "---",
                quotedCSVField(session.tag ?? ""),
                durationFormatter.string(from: interruptionDuration) ?? "0s",
                durationFormatter.string(from: totalTime) ?? "0s"
            ]
            .joined(separator: ",")
        }
        return "Session,Started,Completed,Tag,Interruptions,Total Time\n" + rows.joined(separator: "\n")
    }

    static func plainText(
        sessions: [FocusSession],
        timeZone: TimeZone = .current,
        locale: Locale = .current
    ) -> String {
        guard !sessions.isEmpty else { return "0 NanaFlows" }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium

        return sessions.map { session in
            let name = session.title.isEmpty ? sessionName(for: session.type) : session.title
            let tag = session.tag.map { " [\($0)]" } ?? ""
            let completedAt = session.completed ? formatter.string(from: session.endedAt) : "---"
            return "\(name)\(tag): \(formatter.string(from: session.startedAt)) - \(completedAt)"
        }
        .joined(separator: "\n\n")
    }

    private static func quotedCSVField(_ value: String) -> String {
        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    private static func sessionName(for type: RecordedSessionType) -> String {
        switch type {
        case .focus: "NanaFlow"
        case .shortBreak: "休息"
        case .longBreak: "长时间停顿"
        }
    }
}
