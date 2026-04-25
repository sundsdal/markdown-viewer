import SwiftUI

struct MarkdownDocumentView: View {
    let document: MarkdownDocument
    @AppStorage("fontSize") private var fontSize: Double = 16
    @AppStorage("rendererMode") private var defaultRendererRaw: String = RendererMode.html.rawValue
    @AppStorage("showRendererComparison") private var showRendererComparison = false
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
        RendererMode(rawValue: defaultRendererRaw) ?? .html
    }
    private var leftMode: RendererMode {
        RendererMode(rawValue: leftRaw) ?? seededDefault
    }
    private var rightMode: RendererMode {
        RendererMode(rawValue: rightRaw) ?? .markdownUI
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
            ToolbarItemGroup {
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
            }
        }
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
            HStack(spacing: 10) {
                if showRendererComparison {
                    Text(label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 12)
                rendererMenu(label, selection: selection)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(nsColor: .windowBackgroundColor))
            .overlay(alignment: .bottom) {
                Divider()
            }

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

    @ViewBuilder
    private func renderer(_ mode: RendererMode, source: String) -> some View {
        switch mode {
        case .html:
            MarkdownWebView(
                markdown: renderableText,
                fontSize: fontSize,
                scrollPosition: scrollPosition,
                scrollApplyToken: scrollPosition.applyToken,
                source: source
            )
        case .markdownUI:
            NativeMarkdownDocumentView(
                document: document,
                fontSize: fontSize,
                scrollPosition: scrollPosition,
                scrollApplyToken: scrollPosition.applyToken,
                source: source
            )
        case .textual:
            TextualMarkdownView(
                markdown: renderableText,
                fontSize: fontSize,
                scrollPosition: scrollPosition,
                scrollApplyToken: scrollPosition.applyToken,
                source: source
            )
        case .swiftUIMarkdown:
            SwiftUIMarkdownView(
                markdown: renderableText,
                fontSize: fontSize,
                scrollPosition: scrollPosition,
                scrollApplyToken: scrollPosition.applyToken,
                source: source
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
