import AppKit

private func scriptOnMain(_ body: @escaping @MainActor @Sendable () -> String) -> String {
    if Thread.isMainThread {
        return MainActor.assumeIsolated(body)
    }
    return DispatchQueue.main.sync { MainActor.assumeIsolated(body) }
}

private func runScriptCommand(_ command: TimerAutomationCommand) -> String {
    scriptOnMain {
        TimerController.shared.perform(command)
        return TimerController.shared.phaseTitle
    }
}

final class StartScriptCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? { runScriptCommand(.start) }
}

final class StopScriptCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? { runScriptCommand(.pause) }
}

final class SkipScriptCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? { runScriptCommand(.skip) }
}

final class PreviousScriptCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? { runScriptCommand(.previous) }
}

final class ResetScriptCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? { runScriptCommand(.reset) }
}

final class ShowScriptCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? { runScriptCommand(.show) }
}

final class HideScriptCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? { runScriptCommand(.hide) }
}

final class GetCurrentPhaseScriptCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        scriptOnMain { TimerController.shared.phaseTitle }
    }
}

final class GetRemainingTimeScriptCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        scriptOnMain { TimerController.shared.formattedTime }
    }
}

final class SetSessionTitleScriptCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        guard let title = evaluatedArguments?["titleParameter"] as? String else { return nil }
        return scriptOnMain {
            TimerController.shared.updateSessionTitle(title)
            return TimerController.shared.preferences.sessionTitle
        }
    }
}

final class GetSessionTitleScriptCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        scriptOnMain { TimerController.shared.preferences.sessionTitle }
    }
}
