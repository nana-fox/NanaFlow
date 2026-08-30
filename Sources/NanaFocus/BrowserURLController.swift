import AppKit

@MainActor
protocol BrowserURLControlling {
    func blockURLs(bundleIdentifier: String, patterns: [String], mode: BlockerMode)
}

@MainActor
struct BrowserURLController: BrowserURLControlling {
    func blockURLs(bundleIdentifier: String, patterns: [String], mode: BlockerMode) {
        guard let browser = WebBlockerBrowser.allCases.first(where: {
            $0.bundleIdentifier == bundleIdentifier
        }),
        let blockedPageURL = Bundle.main.url(forResource: "Blocked", withExtension: "html")?.absoluteString,
        let source = Self.blockingScript(
            browser: browser,
            patterns: patterns,
            mode: mode,
            blockedPageURL: blockedPageURL
        ) else { return }
        run(source)
    }

    static func blockingScript(
        browser: WebBlockerBrowser,
        patterns: [String],
        mode: BlockerMode,
        blockedPageURL: String
    ) -> String? {
        let descriptor = BrowserDescriptor(browser: browser)
        let normalized = patterns
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let blockedPage = appleScriptQuoted(blockedPageURL)
        let commands: [String]

        switch mode {
        case .block:
            guard !normalized.isEmpty else { return nil }
            let containsPatterns = normalized.filter { !$0.hasPrefix("*") }
            let exactPatterns = normalized.compactMap { pattern -> String? in
                guard pattern.hasPrefix("*") else { return nil }
                return String(pattern.dropFirst())
            }
            var result: [String] = []
            if !containsPatterns.isEmpty {
                let urlList = containsPatterns.map(appleScriptQuoted).joined(separator: ", ")
                result.append("set urlList to {\(urlList)}")
                result.append("repeat with someUrl in urlList")
                result.append("    set (URL of every tab of every window where URL contains someUrl and URL is not \(blockedPage)) to \(blockedPage)")
                result.append("end repeat")
            }
            for pattern in exactPatterns where !pattern.isEmpty {
                result.append("set (URL of every tab of every window where URL is \(appleScriptQuoted(pattern)) and URL is not \(blockedPage)) to \(blockedPage)")
            }
            commands = result

        case .allow:
            var conditions = normalized.map { pattern in
                if pattern.hasPrefix("*") {
                    return "URL is not \(appleScriptQuoted(String(pattern.dropFirst())))"
                }
                return "URL does not contain \(appleScriptQuoted(pattern))"
            }
            conditions.append("URL is not \(blockedPage)")
            commands = [
                "set (URL of every tab of every window where \(conditions.joined(separator: " and "))) to \(blockedPage)"
            ]
        }

        guard !commands.isEmpty else { return nil }
        return """
        try
            if application \(appleScriptQuoted(descriptor.applicationName)) is running then
                tell application \(appleScriptQuoted(descriptor.applicationName))
        \(commands.map { "            \($0)" }.joined(separator: "\n"))
                end tell
            end if
        end try
        """
    }

    private static func appleScriptQuoted(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    @discardableResult
    private func run(_ source: String) -> String? {
        var error: NSDictionary?
        let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
        guard error == nil else { return nil }
        return result?.stringValue
    }
}

private struct BrowserDescriptor {
    let applicationName: String

    init(browser: WebBlockerBrowser) {
        applicationName = switch browser {
        case .safari: "Safari"
        case .chrome: "Google Chrome"
        case .edge: "Microsoft Edge"
        case .brave: "Brave Browser"
        case .vivaldi: "Vivaldi"
        case .opera: "Opera"
        case .sidekick: "Sidekick"
        }
    }
}
