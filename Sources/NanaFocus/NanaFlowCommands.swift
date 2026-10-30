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

        CommandGroup(replacing: .singleWindowList) {}

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
