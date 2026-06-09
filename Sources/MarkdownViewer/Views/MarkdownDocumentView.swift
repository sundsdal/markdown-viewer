import SwiftUI

struct MarkdownDocumentView: View {
    @AppStorage("fontSize") private var fontSize: Double = 16
    @AppStorage("rendererMode") private var defaultRendererRaw: String = RendererMode.textual.rawValue
    @AppStorage("showRendererComparison") private var showRendererComparison = false
    @AppStorage("textualColorSwatches") private var textualColorSwatches = false
    @AppStorage("textualInferLanguage") private var textualInfersLanguageHints = false
    @AppStorage("markdownTheme") private var markdownThemeRaw = MarkdownTheme.system.rawValue
    @SceneStorage("rendererModeLeft")  private var leftRaw:  String = ""
    @SceneStorage("rendererModeRight") private var rightRaw: String = ""
    @StateObject private var autoReloadingDocument: AutoReloadingMarkdownDocument
    @StateObject private var scrollPosition = RendererScrollPosition()
    @State private var isShowingSearch = false
    @State private var searchQuery = ""
    @State private var searchIsCaseSensitive = false
    @State private var selectedSearchHitIndex = 0
    @State private var htmlRendererHitCount: Int = 0
    @FocusState private var searchFieldIsFocused: Bool

    init(document: MarkdownDocument, fileURL: URL? = nil) {
        _autoReloadingDocument = StateObject(
            wrappedValue: AutoReloadingMarkdownDocument(document: document, fileURL: fileURL)
        )
    }

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
    private var document: MarkdownDocument {
        autoReloadingDocument.document
    }
    private var activeSearchQuery: String {
        isShowingSearch ? searchQuery : ""
    }
    private var searchHits: [DocumentSearchHit] {
        DocumentSearchHit.matches(
            query: searchQuery,
            in: document.text,
            isCaseSensitive: searchIsCaseSensitive
        )
    }
    private var selectedSearchHit: DocumentSearchHit? {
        guard !searchHits.isEmpty else {
            return nil
        }
        return searchHits[min(max(selectedSearchHitIndex, 0), searchHits.count - 1)]
    }
    private var activeRendererSupportsHighlight: Bool {
        leftMode == .html
    }
    private var displayedSearchHitCount: Int {
        activeRendererSupportsHighlight ? htmlRendererHitCount : searchHits.count
    }
    private var documentSearchActions: DocumentSearchActions {
        DocumentSearchActions(
            show: showSearch,
            next: goToNextSearchHit,
            previous: goToPreviousSearchHit
        )
    }
    private var documentReloadAction: DocumentReloadAction {
        let reload = autoReloadingDocument.reload
        return DocumentReloadAction(reload: reload)
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
        .safeAreaInset(edge: .top, spacing: 0) {
            if isShowingSearch {
                DocumentSearchBar(
                    query: $searchQuery,
                    isCaseSensitive: $searchIsCaseSensitive,
                    isFieldFocused: $searchFieldIsFocused,
                    selectedIndex: selectedSearchHitIndex,
                    hitCount: displayedSearchHitCount,
                    rendererSupportsHighlight: activeRendererSupportsHighlight,
                    onPrevious: goToPreviousSearchHit,
                    onNext: goToNextSearchHit,
                    onClose: hideSearch,
                    onSwitchToHTML: { setLeft(.html) }
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
                Menu {
                    Button(action: copyAsMarkdown) {
                        Label("Copy as Markdown", systemImage: "doc.plaintext")
                    }
                    Button(action: copyAsRichText) {
                        Label("Copy as Rich Text", systemImage: "doc.richtext")
                    }
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                } primaryAction: {
                    copyAsMarkdown()
                }
                .menuStyle(.borderlessButton)
                .help("Copy document (click for Markdown, hold for options)")
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
        .focusedSceneValue(\.documentSearchActions, documentSearchActions)
        .focusedSceneValue(\.documentReloadAction, documentReloadAction)
        .onChange(of: leftRaw)  { _, _ in
            scrollPosition.requestApply()
            htmlRendererHitCount = 0
        }
        .onChange(of: rightRaw) { _, _ in scrollPosition.requestApply() }
        .onChange(of: fontSize) { _, _ in scrollPosition.requestApply() }
        .onChange(of: showRendererComparison) { _, _ in scrollPosition.requestApply() }
        .onChange(of: autoReloadingDocument.document.text) { _, _ in
            scrollPosition.requestApply()
            synchronizeSearchSelection()
        }
        .onChange(of: searchQuery) { _, _ in
            resetAndApplySearchSelection()
        }
        .onChange(of: searchIsCaseSensitive) { _, _ in
            resetAndApplySearchSelection()
        }
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
                synchronizesScroll: showRendererComparison,
                searchQuery: activeSearchQuery,
                searchIsCaseSensitive: searchIsCaseSensitive,
                selectedSearchHitIndex: selectedSearchHitIndex,
                onSearchHitCountChange: { count in
                    htmlRendererHitCount = count
                    if count == 0 {
                        selectedSearchHitIndex = 0
                    } else if selectedSearchHitIndex >= count {
                        selectedSearchHitIndex = count - 1
                    }
                }
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

    private func copyAsMarkdown() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(document.text, forType: .string)
        LogStore.shared.log("Copied document as Markdown", level: .debug, category: "ui")
    }

    private func copyAsRichText() {
        let html = MarkdownHTMLRenderer.buildFullHTML(
            markdown: renderableText,
            fontSize: fontSize,
            theme: selectedTheme
        )

        guard let htmlData = html.data(using: .utf8),
              let attributed = try? NSAttributedString(
                  data: htmlData,
                  options: [
                      .documentType: NSAttributedString.DocumentType.html,
                      .characterEncoding: String.Encoding.utf8.rawValue
                  ],
                  documentAttributes: nil
              )
        else {
            LogStore.shared.log("Rich text copy failed; falling back to Markdown", level: .warning, category: "ui")
            copyAsMarkdown()
            return
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let fullRange = NSRange(location: 0, length: attributed.length)

        if let rtfData = try? attributed.data(
            from: fullRange,
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        ) {
            pasteboard.setData(rtfData, forType: .rtf)
        }

        if let exportedHTMLData = try? attributed.data(
            from: fullRange,
            documentAttributes: [.documentType: NSAttributedString.DocumentType.html]
        ) {
            pasteboard.setData(exportedHTMLData, forType: .html)
        }

        pasteboard.setString(attributed.string, forType: .string)

        LogStore.shared.log("Copied document as Rich Text", level: .debug, category: "ui")
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

    private func showSearch() {
        withAnimation(.easeOut(duration: 0.12)) {
            isShowingSearch = true
        }
        DispatchQueue.main.async {
            searchFieldIsFocused = true
        }
        if !searchQuery.isEmpty {
            applySelectedSearchHit()
        }
    }

    private func hideSearch() {
        withAnimation(.easeOut(duration: 0.12)) {
            isShowingSearch = false
        }
        searchFieldIsFocused = false
    }

    private func goToNextSearchHit() {
        showSearch()
        let count = displayedSearchHitCount
        guard count > 0 else {
            selectedSearchHitIndex = 0
            return
        }
        selectedSearchHitIndex = (selectedSearchHitIndex + 1) % count
        applySelectedSearchHit()
    }

    private func goToPreviousSearchHit() {
        showSearch()
        let count = displayedSearchHitCount
        guard count > 0 else {
            selectedSearchHitIndex = 0
            return
        }
        selectedSearchHitIndex = (selectedSearchHitIndex - 1 + count) % count
        applySelectedSearchHit()
    }

    private func resetAndApplySearchSelection() {
        selectedSearchHitIndex = 0
        applySelectedSearchHit()
    }

    private func synchronizeSearchSelection() {
        let count = displayedSearchHitCount
        if selectedSearchHitIndex >= count {
            selectedSearchHitIndex = max(count - 1, 0)
        }
        applySelectedSearchHit()
    }

    private func applySelectedSearchHit() {
        guard !activeRendererSupportsHighlight else {
            // HTML renderer scrolls to the highlighted match itself via JS.
            return
        }
        guard let selectedSearchHit else {
            return
        }

        scrollPosition.update(
            fraction: selectedSearchHit.scrollFraction,
            source: "search",
            broadcast: true
        )
        scrollPosition.requestApply()
    }
}

private struct DocumentSearchHit {
    let scrollFraction: CGFloat

    static func matches(query: String, in text: String, isCaseSensitive: Bool) -> [DocumentSearchHit] {
        guard !query.isEmpty, !text.isEmpty else {
            return []
        }

        let options: String.CompareOptions = isCaseSensitive ? [] : [.caseInsensitive, .diacriticInsensitive]
        let totalLength = max(text.utf16.count, 1)
        var hits: [DocumentSearchHit] = []
        var searchRange = text.startIndex..<text.endIndex

        while let range = text.range(of: query, options: options, range: searchRange, locale: .current) {
            let offset = text.utf16.distance(
                from: text.utf16.startIndex,
                to: range.lowerBound.samePosition(in: text.utf16) ?? text.utf16.startIndex
            )
            let fraction = CGFloat(offset) / CGFloat(totalLength)
            hits.append(DocumentSearchHit(scrollFraction: min(max(fraction, 0), 1)))

            if range.lowerBound == range.upperBound {
                break
            }
            searchRange = range.upperBound..<text.endIndex
        }

        return hits
    }
}

private struct DocumentSearchBar: View {
    @Binding var query: String
    @Binding var isCaseSensitive: Bool
    var isFieldFocused: FocusState<Bool>.Binding
    let selectedIndex: Int
    let hitCount: Int
    let rendererSupportsHighlight: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onClose: () -> Void
    let onSwitchToHTML: () -> Void

    private var hitSummary: String {
        guard !query.isEmpty else {
            return "No search"
        }
        guard hitCount > 0 else {
            return "0 hits"
        }
        return "\(min(selectedIndex + 1, hitCount)) of \(hitCount)"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Search", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .focused(isFieldFocused)
                    .frame(minWidth: 220, idealWidth: 320, maxWidth: 420)
                    .onSubmit(onNext)

                Text(hitSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .frame(minWidth: 58, alignment: .trailing)

                Button(action: onPrevious) {
                    Label("Previous Hit", systemImage: "chevron.up")
                        .labelStyle(.iconOnly)
                }
                .disabled(hitCount == 0)
                .help("Previous hit")

                Button(action: onNext) {
                    Label("Next Hit", systemImage: "chevron.down")
                        .labelStyle(.iconOnly)
                }
                .disabled(hitCount == 0)
                .help("Next hit")

                Toggle(isOn: $isCaseSensitive) {
                    Text("Aa")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 22)
                }
                .toggleStyle(.button)
                .help("Case sensitive")

                Button(action: onClose) {
                    Label("Close Search", systemImage: "xmark")
                        .labelStyle(.iconOnly)
                }
                .keyboardShortcut(.cancelAction)
                .help("Close search")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            if !rendererSupportsHighlight && !query.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                    Text("Match highlighting is only available in the HTML renderer.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Switch to HTML", action: onSwitchToHTML)
                        .buttonStyle(.link)
                        .font(.caption)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}

struct DocumentSearchActions {
    let show: () -> Void
    let next: () -> Void
    let previous: () -> Void
}

struct DocumentReloadAction {
    let reload: () -> Void
}

struct TextualRendererVisibleFocusedValueKey: FocusedValueKey {
    typealias Value = Bool
}

struct DocumentSearchActionsFocusedValueKey: FocusedValueKey {
    typealias Value = DocumentSearchActions
}

struct DocumentReloadActionFocusedValueKey: FocusedValueKey {
    typealias Value = DocumentReloadAction
}

extension FocusedValues {
    var textualRendererIsVisible: Bool? {
        get { self[TextualRendererVisibleFocusedValueKey.self] }
        set { self[TextualRendererVisibleFocusedValueKey.self] = newValue }
    }

    var documentSearchActions: DocumentSearchActions? {
        get { self[DocumentSearchActionsFocusedValueKey.self] }
        set { self[DocumentSearchActionsFocusedValueKey.self] = newValue }
    }

    var documentReloadAction: DocumentReloadAction? {
        get { self[DocumentReloadActionFocusedValueKey.self] }
        set { self[DocumentReloadActionFocusedValueKey.self] = newValue }
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
