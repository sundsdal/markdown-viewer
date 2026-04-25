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
            RendererCommands()
            DebugCommands()
        }

        Window("Debug Logs", id: "debug-logs") {
            DebugLogView()
        }
        .defaultSize(width: 800, height: 500)
    }
}

private struct RendererCommands: Commands {
    @AppStorage("showRendererComparison") private var showRendererComparison = false

    var body: some Commands {
        CommandGroup(after: .toolbar) {
            Toggle("Compare Renderers Side by Side", isOn: $showRendererComparison)
                .keyboardShortcut("r", modifiers: [.command, .shift])
        }
    }
}

private struct DebugCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .windowList) {
            Divider()
            Button("Show Logs") {
                openWindow(id: "debug-logs")
            }
            .keyboardShortcut("d", modifiers: [.command, .shift])
        }
    }
}
