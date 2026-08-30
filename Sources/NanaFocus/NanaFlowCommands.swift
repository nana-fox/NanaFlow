import AppKit
import SwiftUI

struct NanaFlowCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("新Fullscreen窗口") {
                FullscreenBreakWindowController.shared.show(
                    controller: TimerController.shared,
                    manuallyTriggered: true
                )
            }
        }

        CommandGroup(replacing: .singleWindowList) {
            windowButton("Welcome", id: "welcome", windowTitle: "Welcome")
            windowButton(
                "Notification Alert",
                id: PermissionAlertKind.notification.windowID,
                windowTitle: "Notification Alert"
            )
            windowButton(
                "Calendar Alert",
                id: PermissionAlertKind.calendar.windowID,
                windowTitle: "Calendar Alert"
            )
            windowButton("Calendar Chooser", id: "calendar-chooser", windowTitle: "Calendar Chooser")
        }

        CommandGroup(after: .windowList) {
            windowButton("NanaFlow", id: "timer", windowTitle: "NanaFlow")
        }

    }

    private func windowButton(
        _ title: String,
        id: String,
        windowTitle: String,
        miniaturizable: Bool? = nil
    ) -> some View {
        Button(LocalizedStringKey(title)) {
            openWindow(id: id)
            AppWindowActivation.bringToFront(
                title: windowTitle,
                miniaturizable: miniaturizable
            )
        }
    }
}
