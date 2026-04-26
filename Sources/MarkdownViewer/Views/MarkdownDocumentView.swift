import SwiftUI

struct MarkdownDocumentView: View {
    let document: MarkdownDocument
    @AppStorage("fontSize") private var fontSize: Double = 16
    @AppStorage("rendererMode") private var defaultRendererRaw: String = RendererMode.textual.rawValue
    @AppStorage("showRendererComparison") private var showRendererComparison = false
    @AppStorage("textualColorSwatches") private var textualColorSwatches = false
    @AppStorage("textualInferLanguage") private var textualInfersLanguageHints = false
    @AppStorage("markdownTheme") private var markdownThemeRaw = MarkdownTheme.system.rawValue
    @SceneStorage("rendererModeLeft")  private var leftRaw:  String = ""
    @SceneStorage("rendererModeRight") private var rightRaw: String = ""
    @StateObject private var scrollPosition = RendererScrollPosition()

    private enum RendererMode: String, CaseIterable, Identifiable {
        case html             = "html"
        case markdownUI       = "native"           // raw value preserved for back-compat with existing AppStorage value
        case textual          = "textual"
        case swiftUIMarkdown  = "swiftUIMarkdown"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .html:             "HTML"
            case .markdownUI:       "MarkdownUI"
            case .textual:          "Textual"
            case .swiftUIMarkdown:  "SwiftUI-Markdown"
            }
        }
    }

    private enum PaneSource {
        static let left  = "left"
        static let right = "right"
    }

    private var seededDefault: RendererMode {
        RendererMode(rawValue: defaultRendererRaw) ?? .textual
    }
    private var leftMode: RendererMode {
        RendererMode(rawValue: leftRaw) ?? seededDefault
    }
    private var rightMode: RendererMode {
        RendererMode(rawValue: rightRaw) ?? .markdownUI
    }
    private var textualRendererIsVisible: Bool {
        leftMode == .textual || (showRendererComparison && rightMode == .textual)
    }
    private var selectedTheme: MarkdownTheme {
        MarkdownTheme(rawValue: markdownThemeRaw) ?? .system
    }

    private func setLeft(_ mode: RendererMode) {
        leftRaw = mode.rawValue
        if !showRendererComparison {
            // Single-mode: the left picker is "the" picker — sticky default for new windows.
            // Compare-mode: do NOT touch the global default; the user is comparing, not setting a preference.
            defaultRendererRaw = mode.rawValue
        }
        LogStore.shared.log("Left renderer → \(mode.title)", level: .debug, category: "ui")
    }

    private func setRight(_ mode: RendererMode) {
        rightRaw = mode.rawValue
        LogStore.shared.log("Right renderer → \(mode.title)", level: .debug, category: "ui")
    }

    private var leftBinding: Binding<RendererMode> {
        Binding(get: { leftMode },  set: { setLeft($0)  })
    }
    private var rightBinding: Binding<RendererMode> {
        Binding(get: { rightMode }, set: { setRight($0) })
    }

    var body: some View {
        Group {
            if showRendererComparison {
                HSplitView {
                    rendererPane(
                        leftMode,
                        selection: leftBinding,
                        label: "Left",
                        source: PaneSource.left
                    )
                        .frame(minWidth: 320)
                    rendererPane(
                        rightMode,
                        selection: rightBinding,
                        label: "Right",
                        source: PaneSource.right
                    )
                        .frame(minWidth: 320)
                }
            } else {
                rendererPane(
                    leftMode,
                    selection: leftBinding,
                    label: "Renderer",
                    source: PaneSource.left
                )
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                if showRendererComparison {
                    rendererMenu("Left", selection: leftBinding)
                }
            }
            ToolbarItemGroup {
                if showRendererComparison {
                    rendererMenu("Right", selection: rightBinding)
                } else {
                    rendererMenu("Renderer", selection: leftBinding)
                }
                Button(action: copyAll) {
                    Label("Copy All", systemImage: "doc.on.doc")
                }
                .help("Copy entire document to clipboard")
                Button(action: decreaseFontSize) {
                    Label("Decrease font", systemImage: "textformat.size.smaller")
                }
                Button(action: increaseFontSize) {
                    Label("Increase font", systemImage: "textformat.size.larger")
                }
                themeMenu
            }
        }
        .focusedSceneValue(\.textualRendererIsVisible, textualRendererIsVisible)
        .onChange(of: leftRaw)  { _, _ in scrollPosition.requestApply() }
        .onChange(of: rightRaw) { _, _ in scrollPosition.requestApply() }
        .onChange(of: fontSize) { _, _ in scrollPosition.requestApply() }
        .onChange(of: showRendererComparison) { _, _ in scrollPosition.requestApply() }
    }

    @ViewBuilder
    private func rendererPane(
        _ mode: RendererMode,
        selection: Binding<RendererMode>,
        label: String,
        source: String
    ) -> some View {
        VStack(spacing: 0) {
            renderer(mode, source: source)
        }
    }

    @ViewBuilder
    private func rendererMenu(_ label: String, selection: Binding<RendererMode>) -> some View {
        let selectedMode = selection.wrappedValue

        Menu {
            ForEach(RendererMode.allCases) { mode in
                Button {
                    selection.wrappedValue = mode
                } label: {
                    if mode == selectedMode {
                        Label(mode.title, systemImage: "checkmark")
                    } else {
                        Text(mode.title)
                    }
                }
            }
        } label: {
            Label(selectedMode.title, systemImage: "doc.richtext")
                .labelStyle(.titleAndIcon)
        }
        .help(showRendererComparison ? "\(label) panel renderer: \(selectedMode.title)" : "Renderer: \(selectedMode.title)")
    }

    private var themeMenu: some View {
        Menu {
            ForEach(MarkdownTheme.allCases) { theme in
                Button {
                    markdownThemeRaw = theme.rawValue
                    LogStore.shared.log("Theme → \(theme.title)", level: .debug, category: "ui")
                } label: {
                    if theme == selectedTheme {
                        Label(theme.title, systemImage: "checkmark")
                    } else {
                        Text(theme.title)
                    }
                }
            }
        } label: {
            Label(selectedTheme.title, systemImage: "paintpalette")
                .labelStyle(.iconOnly)
        }
        .help("Document theme: \(selectedTheme.title)")
    }

    @ViewBuilder
    private func renderer(_ mode: RendererMode, source: String) -> some View {
        switch mode {
        case .html:
            MarkdownWebView(
                markdown: renderableText,
                fontSize: fontSize,
                theme: selectedTheme,
                scrollPosition: scrollPosition,
                scrollApplyToken: scrollPosition.applyToken,
                source: source,
                synchronizesScroll: showRendererComparison
            )
        case .markdownUI:
            NativeMarkdownDocumentView(
                document: document,
                fontSize: fontSize,
                theme: selectedTheme,
                scrollPosition: scrollPosition,
                scrollApplyToken: scrollPosition.applyToken,
                source: source,
                synchronizesScroll: showRendererComparison
            )
        case .textual:
            TextualMarkdownView(
                markdown: renderableText,
                fontSize: fontSize,
                showsColorSwatches: textualColorSwatches,
                infersLanguageHints: textualInfersLanguageHints,
                theme: selectedTheme,
                scrollPosition: scrollPosition,
                scrollApplyToken: scrollPosition.applyToken,
                source: source,
                synchronizesScroll: showRendererComparison
            )
        case .swiftUIMarkdown:
            SwiftUIMarkdownView(
                markdown: renderableText,
                fontSize: fontSize,
                theme: selectedTheme,
                scrollPosition: scrollPosition,
                scrollApplyToken: scrollPosition.applyToken,
                source: source,
                synchronizesScroll: showRendererComparison
            )
        }
    }

    private var renderableText: String {
        switch document.fileType {
        case .json:
            return "```json\n\(document.text)\n```"
        case .yaml:
            return "```yaml\n\(document.text)\n```"
        case .markdown, .plainText:
            return document.text
        }
    }

    private func copyAll() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(document.text, forType: .string)
        LogStore.shared.log("Copied document to clipboard", level: .debug, category: "ui")
    }

    private func decreaseFontSize() {
        if fontSize > 10 {
            fontSize -= 2
            LogStore.shared.log("Font size → \(Int(fontSize))pt", level: .debug, category: "ui")
        }
    }

    private func increaseFontSize() {
        if fontSize < 28 {
            fontSize += 2
            LogStore.shared.log("Font size → \(Int(fontSize))pt", level: .debug, category: "ui")
        }
    }
}

struct TextualRendererVisibleFocusedValueKey: FocusedValueKey {
    typealias Value = Bool
}

extension FocusedValues {
    var textualRendererIsVisible: Bool? {
        get { self[TextualRendererVisibleFocusedValueKey.self] }
        set { self[TextualRendererVisibleFocusedValueKey.self] = newValue }
    }
}

#Preview {
    MarkdownDocumentView(document: MarkdownDocument(text: """
    ---
    title: "Security Review Notes"
    author: Sverre Sundsdal
    date: 2026-04-25
    tags: [security, markdown, review]
    draft: false
    summary: >
      Focused notes for renderer behavior, table support,
      and code block presentation.
    ---

    # Hello, Markdown

    This is a **preview** of the markdown renderer.

    ## Table Example

    | Vector | Mitigated? |
    |--------|------------|
    | SQL injection | Yes — parameterized queries |
    | XSS | Yes — output encoding |
    | CSRF | Yes — token validation |

    ## Features
    - Syntax highlighting
    - Tables
    - Code blocks

    ```swift
    let greeting = "Hello, world!"
    print(greeting)
    ```
    """))
    .frame(width: 700, height: 500)
}
