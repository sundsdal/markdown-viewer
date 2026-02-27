import SwiftUI
import AppKit

@main
struct MarkdownViewerApp: App {
    init() {
        // SPM bundles the .icns as a module resource; Xcode uses CFBundleIconFile from Info.plist.
        #if SWIFT_PACKAGE
        if let url = Bundle.module.url(forResource: "AppIcon", withExtension: "icns"),
           let image = NSImage(contentsOf: url) {
            NSApplication.shared.applicationIconImage = image
        }
        #endif
    }

    var body: some Scene {
        DocumentGroup(viewing: MarkdownDocument.self) { file in
            MarkdownDocumentView(document: file.document)
        }
        .defaultSize(width: 860, height: 700)
        .commands {
            DebugCommands()
        }

        Window("Debug Logs", id: "debug-logs") {
            DebugLogView()
        }
        .defaultSize(width: 800, height: 500)
    }
}

private struct DebugCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandMenu("Debug") {
            Button("Show Logs") {
                openWindow(id: "debug-logs")
            }
            .keyboardShortcut("d", modifiers: [.command, .shift])
        }
    }
}
