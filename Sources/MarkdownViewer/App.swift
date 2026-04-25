import SwiftUI
import AppKit
import CoreServices
import UniformTypeIdentifiers

@main
struct MarkdownViewerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        RendererLaunchPreferences.apply()

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
            DefaultMarkdownOpenerCommands()
        }

        Window("Debug Logs", id: "debug-logs") {
            DebugLogView()
        }
        .defaultSize(width: 800, height: 500)
    }
}

private enum RendererLaunchPreferences {
    private static let rendererModeKey = "rendererMode"
    private static let rendererComparisonKey = "showRendererComparison"
    private static let seededTextualDefaultKey = "seededTextualDefaultRenderer"

    static func apply() {
        let defaults = UserDefaults.standard

        defaults.register(defaults: [
            rendererModeKey: "textual",
            rendererComparisonKey: false
        ])
        defaults.set(false, forKey: rendererComparisonKey)

        guard !defaults.bool(forKey: seededTextualDefaultKey) else {
            return
        }

        defaults.set("textual", forKey: rendererModeKey)
        defaults.set(true, forKey: seededTextualDefaultKey)
    }
}

private final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            DefaultMarkdownOpenerPrompt.showIfNeeded()
        }
    }
}

private enum DefaultMarkdownOpenerPrompt {
    fileprivate static let sampleMarkdownURL = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("MarkdownDefaultCheck.md")
    private static let neverRemindAgainKey = "neverRemindAboutDefaultMarkdownOpener"

    @MainActor
    static func showIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: neverRemindAgainKey) else {
            return
        }

        guard !DefaultMarkdownOpener.isDefaultOpenerForMarkdownFiles() else {
            return
        }

        showOfferAlert(autoDismissAfter: 60)
    }

    @MainActor
    static func showManualCheck() {
        if DefaultMarkdownOpener.isDefaultOpenerForMarkdownFiles() {
            let alert = NSAlert()
            alert.messageText = "Markdown is already the default app for .md files."
            alert.informativeText = "Opening Markdown files from Finder will use this app."
            alert.addButton(withTitle: "OK")
            alert.runModal()
        } else {
            showOfferAlert(autoDismissAfter: nil)
        }
    }

    @MainActor
    private static func showOfferAlert(autoDismissAfter timeout: TimeInterval?) {
        let alert = NSAlert()
        alert.messageText = "Markdown is not the default app for .md files."
        alert.informativeText = "You can ignore this and keep using the app as usual. If you want Finder to open .md files here by default, choose Make Default."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Make Default")
        alert.addButton(withTitle: "Not Now")
        alert.addButton(withTitle: "Never Remind Me Again")

        var isShowingAlert = true
        if let timeout {
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
                guard isShowingAlert else {
                    return
                }

                NSApplication.shared.stopModal(withCode: .alertSecondButtonReturn)
                alert.window.close()
            }
        }

        let response = alert.runModal()
        isShowingAlert = false

        if response == .alertThirdButtonReturn {
            UserDefaults.standard.set(true, forKey: neverRemindAgainKey)
            return
        }

        guard response == .alertFirstButtonReturn else {
            return
        }

        let status = DefaultMarkdownOpener.makeDefaultOpenerForMarkdownFiles()
        guard status == noErr else {
            showFailureAlert(status: status)
            return
        }
    }

    @MainActor
    private static func showFailureAlert(status: OSStatus) {
        let alert = NSAlert()
        alert.messageText = "Markdown could not be set as the default app."
        alert.informativeText = "macOS returned error \(status). You can still change the default app from Finder with Get Info."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

private enum DefaultMarkdownOpener {
    private static let markdownContentTypeIdentifiers = [
        "net.daringfireball.markdown",
        "public.markdown"
    ]

    static func isDefaultOpenerForMarkdownFiles() -> Bool {
        guard
            let bundleIdentifier = Bundle.main.bundleIdentifier,
            let defaultApplicationURL = NSWorkspace.shared.urlForApplication(toOpen: DefaultMarkdownOpenerPrompt.sampleMarkdownURL),
            let defaultBundleIdentifier = Bundle(url: defaultApplicationURL)?.bundleIdentifier
        else {
            return false
        }

        return defaultBundleIdentifier == bundleIdentifier
    }

    static func makeDefaultOpenerForMarkdownFiles() -> OSStatus {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            return OSStatus(coreFoundationUnknownErr)
        }

        let contentTypeIdentifiers = allMarkdownContentTypeIdentifiers()
        return contentTypeIdentifiers.reduce(noErr) { currentStatus, contentTypeIdentifier in
            guard currentStatus == noErr else {
                return currentStatus
            }

            return LSSetDefaultRoleHandlerForContentType(
                contentTypeIdentifier as CFString,
                .viewer,
                bundleIdentifier as CFString
            )
        }
    }

    private static func allMarkdownContentTypeIdentifiers() -> [String] {
        var identifiers = markdownContentTypeIdentifiers
        if let filenameContentType = UTType(filenameExtension: "md")?.identifier,
           !identifiers.contains(filenameContentType),
           filenameContentType != UTType.plainText.identifier {
            identifiers.append(filenameContentType)
        }
        return identifiers
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

private struct DefaultMarkdownOpenerCommands: Commands {
    var body: some Commands {
        CommandGroup(after: .appInfo) {
            Button("Check Default .md App") {
                Task { @MainActor in
                    DefaultMarkdownOpenerPrompt.showManualCheck()
                }
            }
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
