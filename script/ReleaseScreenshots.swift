// Isolated, deterministic rendering harness. Not compiled into the shipping app.
// All interface pixels are the shipping SwiftUI views or the shipping native NSMenu.
import AppKit
import SwiftUI

@MainActor private final class RenderWindow: NSWindow {
    override var backingScaleFactor: CGFloat { 4 }
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    override var isKeyWindow: Bool { true }
    override var isMainWindow: Bool { true }
}

@MainActor private struct DemoTimerStore: TimerPersisting {
    let engine: TimerEngine
    func load() -> TimerEngine? { engine }
    func save(_: TimerEngine) throws {}
}
@MainActor private struct DemoPreferences: TimerPreferencesPersisting {
    func load() -> TimerPreferences? {
        var p = TimerPreferences.standard
        p.appearance = .light
        p.showTodayCompletedCount = true
        p.focusCompletionSound = .chime
        p.breakCompletionSound = .bowl
        p.notificationVolume = 1
        p.notificationsEnabled = true
        return p
    }
    func save(_: TimerPreferences) throws {}
}
@MainActor private struct DemoHistory: SessionHistoryPersisting {
    let sessions: [FocusSession]
    func load() -> [FocusSession] { sessions }
    func save(_: [FocusSession]) throws {}
}
@MainActor private struct DemoNotifications: SessionNotificationScheduling {
    func scheduleCompletion(at _: Date, nextPhase _: SessionPhase, sound _: CompletionSound, volume _: Double, quote _: String?) {}
    func cancelCompletion() {}
}
@MainActor private struct DemoTick: TimerTickSoundPlaying {
    func playTick(volume _: Double) {}
}

@MainActor final class ScreenshotDelegate: NSObject, NSApplicationDelegate {
    let output = URL(fileURLWithPath: ProcessInfo.processInfo.arguments[1])
    let chinese = Locale.preferredLanguages.first?.hasPrefix("zh") == true
    var controller: TimerController!
    var service: AppStatusItemService!
    var timerWindow: NSWindow!
    var menuCaptureTimer: Timer?
    var activeMenu: NSMenu?
    let calendar = Calendar(identifier: .gregorian)

    func applicationDidFinishLaunching(_: Notification) {
        NSApp.activate(ignoringOtherApps: true)
        // Activation/key-window events are delivered after launch completes.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.runScreenshots() }
    }

    func runScreenshots() {
        do {
            try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
            NSApp.appearance = NSAppearance(named: .aqua)
            let now = Date()
            let anchor = calendar.date(from: DateComponents(year: 2026, month: 10, day: 21, hour: 12))!
            var sessions: [FocusSession] = []
            for day in 1...31 {
                for index in 0..<((day * 7 + 3) % 8) {
                    let end = calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: 9 + index))!
                    let minutes = [25, 40, 25, 50, 30][(day + index) % 5]
                    sessions.append(FocusSession(id: UUID(), startedAt: end.addingTimeInterval(-Double(minutes * 60)), endedAt: end, duration: Double(minutes * 60), completed: true, title: ""))
                }
            }
            for index in 1...3 {
                let end = now.addingTimeInterval(-Double(index * 3600))
                sessions.append(FocusSession(id: UUID(), startedAt: end.addingTimeInterval(-1500), endedAt: end, duration: 1500, completed: true, title: ""))
            }
            let engine = TimerEngine(configuration: .standard, state: TimerState(phase: .focus, cycleIndex: 2, remainingWhenPaused: 1087, endDate: now.addingTimeInterval(1087), startedAt: now.addingTimeInterval(-413)))
            controller = TimerController(persistence: DemoTimerStore(engine: engine), preferencesPersistence: DemoPreferences(), historyPersistence: DemoHistory(sessions: sessions), notifications: DemoNotifications(), tickSound: DemoTick(), now: now)
            print("identity=\(Bundle.main.bundleIdentifier!), languages=\(Locale.preferredLanguages), locale=\(Locale.current.identifier)")
            try render(TimerView(controller: controller, rendersPlatformSurfaces: false), name: "timer", width: 380, height: 272)
            try render(MenuBarStatusContent(controller: controller).padding(.horizontal, 12).background(.regularMaterial), name: "status", width: 124, height: 28)
            try render(StatisticsView(controller: controller, initialPeriod: .week, initialAnchor: anchor), name: "week", width: 380, height: 272)
            let hover = calendar.date(from: DateComponents(year: 2026, month: 10, day: 22))!
            try render(StatisticsView(controller: controller, initialPeriod: .month, initialAnchor: anchor, initialMetric: .duration, initialHoveredBucketID: hover), name: "month", width: 380, height: 272)
            let permission = PermissionSystemClient(notificationStatus: { .authorized }, requestNotificationAuthorization: { false })
            try renderHosted(TimerSettingsView(controller: controller, onBack: {}, permissionClient: permission, initialScrollAnchor: .bottom), name: "settings")
            try renderHosted(CustomDurationView(controller: controller), name: "durations")
            // Display only this identity's native windows to capture the actual
            // macOS menus; no screen or other application's pixels are read.
            timerWindow = NSWindow(contentRect: NSRect(x: 200, y: 300, width: 380, height: 272), styleMask: [.titled, .fullSizeContentView], backing: .buffered, defer: false)
            timerWindow.title = "NanaFlow Screenshot Fixture"
            timerWindow.identifier = NSUserInterfaceItemIdentifier("timer")
            timerWindow.contentView = NSHostingView(rootView: TimerView(controller: controller))
            timerWindow.makeKeyAndOrderFront(nil)
            service = AppStatusItemService(controller: controller)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.captureStatusMenu() }
        } catch { fail(error) }
    }

    func renderHosted<V: View>(_ view: V, name: String) throws {
        let window = RenderWindow(contentRect: NSRect(x: 150, y: 300, width: 380, height: 272), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let host = NSHostingView(rootView: view.environment(\.locale, Locale.current).environment(\.colorScheme, .light).environment(\.displayScale, 4).environment(\.controlActiveState, .key))
        window.contentView = host
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        // ScrollView and NSViewRepresentable must be laid out in a real window.
        RunLoop.current.run(until: Date().addingTimeInterval(0.15))
        host.layoutSubtreeIfNeeded()
        print("Hosted \(name): forced key appearance, applicationActive=\(NSApp.isActive), appearance=\(window.effectiveAppearance.name.rawValue)")
        var notificationControlTop: CGFloat?
        func inspectControls(_ view: NSView) {
            if let control = view as? NSSwitch {
                let rect = host.convert(control.bounds, from: control)
                if name == "settings", control.state == .on, rect.minY >= 42, rect.maxY < 180 {
                    notificationControlTop = rect.minY
                    print("Notification ON control: \(rect)")
                }
            }
            view.subviews.forEach(inspectControls)
        }
        inspectControls(host)

        func configureScale(_ layer: CALayer) {
            layer.contentsScale = 4
            layer.rasterizationScale = 4
            layer.sublayers?.forEach(configureScale)
        }
        if let layer = host.layer { configureScale(layer) }
        host.displayIfNeeded()
        let bounds = host.bounds
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1520, pixelsHigh: 1088, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { throw NSError(domain: "Screenshot", code: 3) }
        bitmap.size = bounds.size
        host.cacheDisplay(in: bounds, to: bitmap)
        if name == "settings" {
            try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("settings-full.png"))
            // A contiguous crop aligned to the same real notification control
            // in each locale: headers excluded, all sound/volume rows retained.
            guard let notificationControlTop else { throw NSError(domain: "NotificationControl", code: 1) }
            let cropY = ((notificationControlTop - 3) * 4).rounded()
            print("Settings crop: x=0, y=\(cropY), width=1520, height=700")
            try png(bitmap.cgImage!.cropping(to: CGRect(x: 0, y: cropY, width: 1520, height: 700))!, name: name)
        } else {
            try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(name + ".png"))
        }
        window.close()
    }


    func render<V: View>(_ view: V, name: String, width: CGFloat, height: CGFloat) throws {
        let renderer = ImageRenderer(content: view.environment(\.locale, Locale.current).environment(\.colorScheme, .light))
        renderer.proposedSize = ProposedViewSize(width: width, height: height)
        renderer.scale = 4
        guard let image = renderer.cgImage else { throw NSError(domain: "Screenshot", code: 1) }
        try png(image, name: name)
    }

    func png(_ image: CGImage, name: String) throws {
        let rep = NSBitmapImageRep(cgImage: image)
        guard let data = rep.representation(using: .png, properties: [:]) else { throw NSError(domain: "Screenshot", code: 2) }
        try data.write(to: output.appendingPathComponent(name + ".png"))
        print("\(name): \(rep.pixelsWide)x\(rep.pixelsHigh)")
    }

    func compose() throws {
        let titles = chinese
            ? ["专注，节奏尽在眼前", "一周专注，一眼看清", "让每一段专注都有分量", "专注与休息，各有声音"]
            : ["Focus. Keep your rhythm.", "See your week at a glance.", "Make your focus time count.", "A sound for focus. A sound for rest."]
        for (index, source) in ["timer", "week", "month", "settings"].enumerated() {
            let view = MarketingCanvas(
                title: titles[index],
                primary: NSImage(contentsOf: output.appendingPathComponent(source + ".png"))!,
                menu: index == 0 ? NSImage(contentsOf: output.appendingPathComponent("menu-1.png")) : nil,
                status: index == 0 ? NSImage(contentsOf: output.appendingPathComponent("status.png")) : nil
            )
            let renderer = ImageRenderer(content: view)
            renderer.proposedSize = ProposedViewSize(width: 1440, height: 900)
            renderer.scale = 2
            renderer.isOpaque = true
            try png(renderer.cgImage!, name: String(format: "%02d-%@", index + 1, ["focus-menu", "week-count", "month-duration", "completion-sounds"][index]))
        }
        if !chinese {
            let view = MarketingCanvas(title: "Your timer controls, close at hand.", primary: NSImage(contentsOf: output.appendingPathComponent("timer.png"))!, menu: NSImage(contentsOf: output.appendingPathComponent("options-1.png")), status: nil)
            let renderer = ImageRenderer(content: view)
            renderer.proposedSize = ProposedViewSize(width: 1440, height: 900)
            renderer.scale = 2
            renderer.isOpaque = true
            try png(renderer.cgImage!, name: "A-en-timer-options")
        }
    }

    func captureStatusMenu() {
        let menu = service.makeMenu()
        print("Menu symbol images attached: \(menu.items.filter { $0.image != nil }.count); native visibility policy unchanged")
        activeMenu = menu
        menuCaptureTimer = Timer(timeInterval: 0.5, repeats: false) { _ in
            MainActor.assumeIsolated {
                self.captureMenuWindows(name: "menu")
                self.activeMenu?.cancelTracking()
            }
        }
        RunLoop.main.add(menuCaptureTimer!, forMode: .common)
        menu.popUp(positioning: nil, at: NSPoint(x: 680, y: 650), in: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.captureOptionsMenu() }
    }

    func captureMenuWindows(name: String) {
        let windows = NSApp.windows.filter { $0.isVisible && $0 != timerWindow }
        print("Menu windows:", windows.map { "\(type(of: $0)) \($0.frame)" })
        for (index, window) in windows.enumerated() {
            guard let view = window.contentView, view.bounds.width > 80, view.bounds.height > 80 else { continue }
            let bounds = view.bounds
            guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(bounds.width * 4), pixelsHigh: Int(bounds.height * 4), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { continue }
            bitmap.size = bounds.size
            view.cacheDisplay(in: bounds, to: bitmap)
            if let data = bitmap.representation(using: .png, properties: [:]) {
                try? data.write(to: output.appendingPathComponent("\(name)-\(index).png"))
            }
        }
    }

    func captureOptionsMenu() {
        let capture = Timer(timeInterval: 0.7, repeats: false) { _ in
            MainActor.assumeIsolated {
                self.captureMenuWindows(name: "options")
                self.service.stop()
                do { try self.compose() } catch { self.fail(error) }
                print("Screenshots complete; no production stores used.")
                NSApp.terminate(nil)
            }
        }
        RunLoop.main.add(capture, forMode: .common)
        if let button = findMenuButton(timerWindow.contentView!) {
            print("Native menu button:", type(of: button))
            button.performClick(nil)
            return
        }
        // Click the More button in our own known timer window.
        let screenHeight = NSScreen.screens[0].frame.height
        let content = timerWindow.convertToScreen(NSRect(x: 0, y: 0, width: 380, height: 272))
        let point = CGPoint(x: content.minX + TimerVisualMetrics.menuControlX, y: screenHeight - content.maxY + TimerVisualMetrics.toolbarCenterY)
        CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
        CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
    }

    func findMenuButton(_ view: NSView) -> NSButton? {
        if let button = view as? NSPopUpButton { return button }
        for child in view.subviews { if let found = findMenuButton(child) { return found } }
        return nil
    }

    func fail(_ error: Error) { print("ERROR:", error); exit(1) }
}

private struct MarketingCanvas: View {
    let title: String
    let primary: NSImage
    let menu: NSImage?
    let status: NSImage?

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [Color(red: 0.94, green: 0.97, blue: 0.95), Color(red: 0.78, green: 0.87, blue: 0.82)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Text("NanaFlow")
                .font(.system(size: 24, weight: .medium, design: .rounded))
                .tracking(3)
                .foregroundStyle(Color(red: 0.20, green: 0.43, blue: 0.36))
                .position(x: 720, y: 63)
            Text(title)
                .font(.system(size: 49, weight: .semibold))
                .foregroundStyle(Color(red: 0.08, green: 0.25, blue: 0.20))
                .lineLimit(1)
                .position(x: 720, y: 143)
            Image(nsImage: primary)
                .resizable()
                .frame(width: 760, height: CGFloat(primary.representations[0].pixelsHigh) / 2)
                .clipShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
                .shadow(color: .black.opacity(0.16), radius: 25, y: 18)
                .position(x: menu == nil ? 720 : 520, y: menu == nil ? 555 : 585)
            if let menu {
                Image(nsImage: menu)
                    .resizable()
                    .frame(width: CGFloat(menu.representations[0].pixelsWide) / 2, height: CGFloat(menu.representations[0].pixelsHigh) / 2)
                    .shadow(color: .black.opacity(0.15), radius: 16, y: 9)
                    .position(x: 1130, y: 545)
            }
            if let status {
                Image(nsImage: status)
                    .resizable()
                    .frame(width: CGFloat(status.representations[0].pixelsWide) / 2, height: CGFloat(status.representations[0].pixelsHigh) / 2)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.84), in: Capsule())
                    .position(x: 1130, y: 225)
            }
        }
        .frame(width: 1440, height: 900)
        .environment(\.colorScheme, .light)
    }
}

@main struct ReleaseScreenshots {
    @MainActor static func main() {
        precondition(Bundle.main.bundleIdentifier == "com.nanafox.NanaFlow.Screenshots")
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let delegate = ScreenshotDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
