import SwiftUI
import WebKit

struct MarkdownWebView: NSViewRepresentable {
    let markdown: String
    let fontSize: Double
    let theme: MarkdownTheme
    let scrollPosition: RendererScrollPosition
    let scrollApplyToken: UUID
    let source: String
    let synchronizesScroll: Bool

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.suppressesIncrementalRendering = true
        config.userContentController.add(context.coordinator, name: "scrollPosition")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        context.coordinator.webView = webView
        loadHTML(in: webView, context: context)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.scrollPosition = scrollPosition
        context.coordinator.source = source
        context.coordinator.synchronizesScroll = synchronizesScroll
        let signature = documentSignature(markdown: markdown, fontSize: fontSize)

        if context.coordinator.loadedDocumentSignature != signature {
            context.coordinator.loadedDocumentSignature = signature
            context.coordinator.lastTheme = theme
            webView.loadHTMLString(buildFullHTML(markdown: markdown, fontSize: fontSize, theme: theme), baseURL: nil)
        } else {
            context.coordinator.applyThemeIfNeeded(theme)
        }

        if context.coordinator.lastApplyToken != scrollApplyToken {
            context.coordinator.lastApplyToken = scrollApplyToken
            context.coordinator.applyScrollPositionIfNeeded()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            scrollPosition: scrollPosition,
            source: source,
            synchronizesScroll: synchronizesScroll
        )
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        weak var webView: WKWebView?
        var scrollPosition: RendererScrollPosition
        var source: String
        var synchronizesScroll: Bool
        var loadedDocumentSignature: String?
        var lastApplyToken: UUID?
        var lastTheme: MarkdownTheme?
        private var isApplyingScroll = false

        init(scrollPosition: RendererScrollPosition, source: String, synchronizesScroll: Bool) {
            self.scrollPosition = scrollPosition
            self.source = source
            self.synchronizesScroll = synchronizesScroll
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            applyScrollPositionIfNeeded()
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "scrollPosition",
                  !isApplyingScroll,
                  let body = message.body as? [String: Any],
                  let fraction = body["fraction"] as? Double else {
                return
            }
            scrollPosition.update(
                fraction: CGFloat(fraction),
                source: source,
                broadcast: synchronizesScroll
            )
        }

        func applyScrollPositionIfNeeded() {
            guard scrollPosition.activeSource != source else { return }
            guard let webView else { return }
            isApplyingScroll = true
            let fraction = min(max(scrollPosition.fraction, 0), 1)
            let script = """
            (() => {
              const maxY = Math.max(0, document.documentElement.scrollHeight - window.innerHeight);
              window.scrollTo(0, maxY * \(fraction));
            })();
            """
            webView.evaluateJavaScript(script) { [weak self] _, _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    self?.isApplyingScroll = false
                }
            }
        }

        func applyThemeIfNeeded(_ theme: MarkdownTheme) {
            guard lastTheme != theme else { return }
            lastTheme = theme
            guard let webView else { return }
            let script = """
            (() => {
              const id = '__markdown_theme_variables__';
              let style = document.getElementById(id);
              if (!style) {
                style = document.createElement('style');
                style.id = id;
                (document.head || document.documentElement).prepend(style);
              }
              style.textContent = '\(theme.escapedCSSVariableRuleForJavaScript)';
            })();
            """
            webView.evaluateJavaScript(script)
        }
    }

    private func loadHTML(in webView: WKWebView, context: Context) {
        let html = buildFullHTML(markdown: markdown, fontSize: fontSize, theme: theme)
        context.coordinator.loadedDocumentSignature = documentSignature(markdown: markdown, fontSize: fontSize)
        context.coordinator.lastApplyToken = scrollApplyToken
        context.coordinator.lastTheme = theme
        webView.loadHTMLString(html, baseURL: nil)
    }

    private func documentSignature(markdown: String, fontSize: Double) -> String {
        "\(fontSize)\u{0}\(markdown)"
    }

    // MARK: - Full HTML document

    private func buildFullHTML(markdown: String, fontSize: Double, theme: MarkdownTheme) -> String {
        let body = renderMarkdownDocument(markdown)
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <script>
            (() => {
                let pending = false;

                function maximumScrollY() {
                    return Math.max(0, document.documentElement.scrollHeight - window.innerHeight);
                }

                function reportScrollPosition() {
                    const maxY = maximumScrollY();
                    const fraction = maxY === 0 ? 0 : window.scrollY / maxY;
                    window.webkit.messageHandlers.scrollPosition.postMessage({ fraction });
                }

                window.addEventListener("scroll", () => {
                    if (pending) return;
                    pending = true;
                    requestAnimationFrame(() => {
                        pending = false;
                        reportScrollPosition();
                    });
                }, { passive: true });

                window.addEventListener("load", reportScrollPosition);
            })();
        </script>
        <style id="__markdown_theme_variables__">
        \(theme.cssVariableRule)
        </style>
        <style>
            body {
                font-family: -apple-system, BlinkMacSystemFont, "Helvetica Neue", sans-serif;
                font-size: \(fontSize)px;
                line-height: 1.65;
                color: var(--md-fg);
                background: var(--md-bg);
                max-width: 720px;
                margin: 0 auto;
                padding: 40px;
                -webkit-font-smoothing: antialiased;
            }
            h1 { font-size: \(fontSize * 2.0)px; font-weight: 700; margin: 1em 0 0.4em; }
            h2 { font-size: \(fontSize * 1.5)px; font-weight: 600; margin: 0.9em 0 0.4em; }
            h3 { font-size: \(fontSize * 1.25)px; font-weight: 600; margin: 0.7em 0 0.3em; }
            h4 { font-size: \(fontSize * 1.1)px; font-weight: 600; margin: 0.6em 0 0.2em; }
            p { margin: 0.6em 0; }
            a { color: var(--md-link); }
            code {
                font-family: Menlo, Monaco, "SF Mono", monospace;
                font-size: 0.875em;
                background: var(--md-inline-code-bg);
                color: var(--md-inline-code-fg);
                padding: 2px 5px;
                border-radius: 3px;
            }
            pre {
                background: var(--md-code-bg);
                border: 1px solid var(--md-border);
                border-radius: 6px;
                padding: 12px 16px;
                overflow-x: auto;
                margin: 0.8em 0;
            }
            pre code {
                background: none;
                color: inherit;
                padding: 0;
            }
            blockquote {
                border-left: 3px solid var(--md-border);
                margin: 0.6em 0;
                padding: 0.2em 0 0.2em 16px;
                color: var(--md-secondary);
            }
            table {
                border-collapse: collapse;
                margin: 0.8em 0;
                width: auto;
                overflow-x: auto;
                display: block;
            }
            th, td {
                border: 1px solid var(--md-border);
                padding: 8px 14px;
                text-align: left;
            }
            th {
                font-weight: 600;
                background: var(--md-table-header-bg);
            }
            tr:nth-child(even) td {
                background: var(--md-table-stripe-bg);
            }
            ul, ol { padding-left: 1.5em; margin: 0.4em 0; }
            li { margin: 0.2em 0; }
            hr { border: none; border-top: 1px solid var(--md-border); margin: 1.2em 0; }
            img { max-width: 100%; border-radius: 4px; }
            .frontmatter {
                margin: 0 0 36px;
                padding: 0;
                border: 1px solid var(--md-frontmatter-border);
                border-radius: 8px;
                background:
                    linear-gradient(90deg, var(--md-frontmatter-gutter) 0 42px, transparent 42px),
                    var(--md-frontmatter-bg);
                color: var(--md-frontmatter-value);
                box-shadow: inset 0 1px 0 var(--md-frontmatter-shadow);
                overflow: hidden;
            }
            .frontmatter-header {
                display: flex;
                align-items: center;
                justify-content: space-between;
                gap: 14px;
                min-height: 34px;
                padding: 0 13px 0 54px;
                border-bottom: 1px solid var(--md-frontmatter-block-border);
                background: var(--md-frontmatter-header-bg);
            }
            .frontmatter-title {
                font-family: Menlo, Monaco, "SF Mono", monospace;
                font-size: 0.72em;
                font-weight: 650;
                letter-spacing: 0;
                color: var(--md-frontmatter-title);
            }
            .frontmatter-delimiter {
                font-family: Menlo, Monaco, "SF Mono", monospace;
                font-size: 0.76em;
                color: var(--md-frontmatter-delimiter);
            }
            .frontmatter-grid {
                display: grid;
                grid-template-columns: minmax(136px, max-content) minmax(0, 1fr);
                column-gap: 10px;
                row-gap: 0;
                margin: 0;
                padding: 12px 16px 14px 54px;
                font-family: Menlo, Monaco, "SF Mono", monospace;
                font-size: 0.86em;
                line-height: 1.7;
            }
            .frontmatter-code {
                margin: 0;
                padding: 18px 18px 18px 54px;
                border: 0;
                border-radius: 0;
                background: transparent;
                overflow-x: auto;
                white-space: pre-wrap;
            }
            .frontmatter-code code {
                display: block;
                font-family: Menlo, Monaco, "SF Mono", monospace;
                font-size: 0.9em;
                line-height: 1.7;
                background: transparent;
                color: var(--md-frontmatter-code-fg);
                padding: 0;
            }
            .frontmatter-key {
                margin: 0;
                color: var(--md-frontmatter-key);
                overflow-wrap: anywhere;
            }
            .frontmatter-key::after {
                content: ":";
                color: var(--md-frontmatter-punctuation);
            }
            .frontmatter-value {
                margin: 0;
                min-width: 0;
                color: var(--md-frontmatter-value);
            }
            .frontmatter-scalar,
            .frontmatter-string,
            .frontmatter-date,
            .frontmatter-number {
                overflow-wrap: anywhere;
            }
            .frontmatter-string {
                color: var(--md-frontmatter-string);
            }
            .frontmatter-date,
            .frontmatter-number {
                font-variant-numeric: tabular-nums;
                color: var(--md-frontmatter-number);
            }
            .frontmatter-boolean {
                font-variant-numeric: tabular-nums;
                color: var(--md-frontmatter-boolean);
            }
            .frontmatter-null {
                color: var(--md-frontmatter-null);
            }
            .frontmatter-punctuation {
                color: var(--md-frontmatter-punctuation);
            }
            .frontmatter-array {
                overflow-wrap: anywhere;
            }
            .frontmatter-block {
                margin: 3px 0 5px;
                padding: 9px 11px;
                border-radius: 6px;
                border: 1px solid var(--md-frontmatter-block-border);
                background: var(--md-frontmatter-block-bg);
                white-space: pre-wrap;
            }
            .frontmatter-block code {
                font-size: 1em;
                line-height: 1.55;
            }
            .frontmatter-footer {
                padding: 0 16px 13px 54px;
                font-family: Menlo, Monaco, "SF Mono", monospace;
                font-size: 0.86em;
                line-height: 1;
                color: var(--md-frontmatter-delimiter);
            }
            .sy-comment { color: var(--md-syntax-comment); font-style: italic; }
            .sy-key { color: var(--md-syntax-key); }
            .sy-string { color: var(--md-syntax-string); }
            .sy-number { color: var(--md-syntax-number); }
            .sy-keyword { color: var(--md-syntax-keyword); }
            .sy-boolean { color: var(--md-syntax-boolean); }
            .sy-punctuation { color: var(--md-syntax-punctuation); }
        </style>
        </head>
        <body>
        \(body)
        </body>
        </html>
        """
    }

    // MARK: - Document sections

    private func renderMarkdownDocument(_ text: String) -> String {
        guard let frontMatter = splitFrontMatter(from: text) else {
            return markdownToHTML(text)
        }

        let frontMatterHTML = renderFrontMatter(frontMatter.yaml)
        let markdownHTML = markdownToHTML(frontMatter.body)
        if markdownHTML.isEmpty {
            return frontMatterHTML
        }
        return [frontMatterHTML, markdownHTML].joined(separator: "\n")
    }

    private func splitFrontMatter(from text: String) -> (yaml: String, body: String)? {
        let textWithoutBOM = text.hasPrefix("\u{feff}") ? String(text.dropFirst()) : text
        let lines = textWithoutBOM.components(separatedBy: "\n")

        guard lines.first?.trimmingCharacters(in: .whitespacesAndNewlines) == "---" else {
            return nil
        }

        for index in lines.indices.dropFirst() {
            let trimmed = lines[index].trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed == "---" || trimmed == "..." {
                let yaml = lines[1..<index].joined(separator: "\n")
                let body = index + 1 < lines.count ? lines[(index + 1)...].joined(separator: "\n") : ""
                return (yaml, body)
            }
        }

        return nil
    }

    // MARK: - Frontmatter rendering

    private struct FrontMatterEntry {
        let key: String
        let value: FrontMatterValue
    }

    private enum FrontMatterValue {
        case scalar(String, FrontMatterScalarKind)
        case list([String])
        case textBlock(String)
        case yamlBlock(String)
        case empty
    }

    private enum FrontMatterScalarKind {
        case string
        case number
        case boolean
        case null
        case date
    }

    private func renderFrontMatter(_ yaml: String) -> String {
        return """
        <section class="frontmatter" aria-label="Frontmatter">
        <div class="frontmatter-header">
        <span class="frontmatter-title">frontmatter</span>
        <span class="frontmatter-delimiter">---</span>
        </div>
        <pre class="frontmatter-code"><code>\(highlightCode(yaml, language: "yaml"))</code></pre>
        <div class="frontmatter-footer">---</div>
        </section>
        """
    }

    private func renderFrontMatterValue(_ value: FrontMatterValue) -> String {
        switch value {
        case .scalar(let text, .string):
            return renderYAMLStringToken(text)
        case .scalar(let text, .number):
            return "<span class=\"frontmatter-number\">\(escapeHTML(text))</span>"
        case .scalar(let text, .boolean):
            return "<span class=\"frontmatter-boolean\">\(escapeHTML(text.lowercased()))</span>"
        case .scalar(let text, .null):
            return "<span class=\"frontmatter-null\">\(escapeHTML(text == "~" ? "null" : text.lowercased()))</span>"
        case .scalar(let text, .date):
            return "<span class=\"frontmatter-date\">\(escapeHTML(text))</span>"
        case .list(let values):
            guard !values.isEmpty else {
                return "<span class=\"frontmatter-null\">[]</span>"
            }
            let items = values.map { renderYAMLStringToken($0) }.joined(separator: "<span class=\"frontmatter-punctuation\">, </span>")
            return """
            <span class="frontmatter-array"><span class="frontmatter-punctuation">[</span>\(items)<span class="frontmatter-punctuation">]</span></span>
            """
        case .textBlock(let text):
            return "<pre class=\"frontmatter-block\"><code>\(escapeHTML(text))</code></pre>"
        case .yamlBlock(let text):
            return "<pre class=\"frontmatter-block\"><code>\(highlightCode(text, language: "yaml"))</code></pre>"
        case .empty:
            return "<span class=\"frontmatter-null\">empty</span>"
        }
    }

    private func renderYAMLStringToken(_ text: String) -> String {
        let quoted = "\"\(text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))\""
        return "<span class=\"frontmatter-string\">\(escapeHTML(quoted))</span>"
    }

    private func parseFrontMatterEntries(_ yaml: String) -> [FrontMatterEntry] {
        let lines = yaml.components(separatedBy: "\n").map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "\r")) }
        var entries: [FrontMatterEntry] = []
        var index = 0

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else {
                index += 1
                continue
            }

            guard isTopLevelYAMLKey(line), let colonIndex = firstYAMLKeyColon(in: line) else {
                return []
            }

            let rawKey = String(line[..<colonIndex]).trimmingCharacters(in: .whitespaces)
            let key = unquoteYAMLString(rawKey)
            let rawValue = String(line[line.index(after: colonIndex)...])
            let valueText = stripYAMLComment(from: rawValue).trimmingCharacters(in: .whitespaces)

            if valueText.isEmpty || isYAMLBlockScalarIndicator(valueText) {
                let blockStart = index + 1
                var blockEnd = blockStart
                while blockEnd < lines.count, !isTopLevelYAMLKey(lines[blockEnd]) {
                    blockEnd += 1
                }
                let block = normalizeYAMLBlock(Array(lines[blockStart..<blockEnd]))
                let value = parseYAMLBlockValue(block, indicator: valueText)
                entries.append(FrontMatterEntry(key: key, value: value))
                index = blockEnd
            } else {
                entries.append(FrontMatterEntry(key: key, value: parseInlineYAMLValue(valueText)))
                index += 1
            }
        }

        return entries
    }

    private func isTopLevelYAMLKey(_ line: String) -> Bool {
        guard let first = line.first,
              !first.isWhitespace,
              first != "-",
              !line.trimmingCharacters(in: .whitespaces).hasPrefix("#") else {
            return false
        }
        return firstYAMLKeyColon(in: line) != nil
    }

    private func firstYAMLKeyColon(in line: String) -> String.Index? {
        var inSingleQuote = false
        var inDoubleQuote = false
        var isEscaped = false

        for index in line.indices {
            let character = line[index]

            if inDoubleQuote, character == "\\", !isEscaped {
                isEscaped = true
                continue
            }

            if character == "'", !inDoubleQuote {
                inSingleQuote.toggle()
            } else if character == "\"", !inSingleQuote, !isEscaped {
                inDoubleQuote.toggle()
            } else if character == ":", !inSingleQuote, !inDoubleQuote {
                let nextIndex = line.index(after: index)
                if nextIndex == line.endIndex || line[nextIndex].isWhitespace {
                    return index
                }
            }

            isEscaped = false
        }

        return nil
    }

    private func stripYAMLComment(from text: String) -> String {
        var inSingleQuote = false
        var inDoubleQuote = false
        var isEscaped = false
        var previous: Character?

        for index in text.indices {
            let character = text[index]

            if inDoubleQuote, character == "\\", !isEscaped {
                isEscaped = true
                previous = character
                continue
            }

            if character == "'", !inDoubleQuote {
                inSingleQuote.toggle()
            } else if character == "\"", !inSingleQuote, !isEscaped {
                inDoubleQuote.toggle()
            } else if character == "#", !inSingleQuote, !inDoubleQuote,
                      previous == nil || previous?.isWhitespace == true {
                return String(text[..<index])
            }

            previous = character
            isEscaped = false
        }

        return text
    }

    private func isYAMLBlockScalarIndicator(_ value: String) -> Bool {
        value.hasPrefix("|") || value.hasPrefix(">")
    }

    private func parseYAMLBlockValue(_ block: String, indicator: String) -> FrontMatterValue {
        let trimmed = block.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            return .empty
        }

        if indicator.hasPrefix("|") {
            return .textBlock(trimmed)
        }

        if indicator.hasPrefix(">") {
            return .textBlock(foldYAMLBlock(trimmed))
        }

        let nonEmptyLines = trimmed.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }

        if !nonEmptyLines.isEmpty, nonEmptyLines.allSatisfy({ $0.hasPrefix("- ") || $0 == "-" }) {
            let items = nonEmptyLines.map { line in
                let item = line == "-" ? "" : String(line.dropFirst(2))
                return unquoteYAMLString(stripYAMLComment(from: item).trimmingCharacters(in: .whitespaces))
            }
            return .list(items)
        }

        return .yamlBlock(trimmed)
    }

    private func parseInlineYAMLValue(_ value: String) -> FrontMatterValue {
        let trimmed = stripYAMLComment(from: value).trimmingCharacters(in: .whitespaces)

        guard !trimmed.isEmpty else {
            return .empty
        }

        if trimmed == "[]" {
            return .list([])
        }

        if trimmed.hasPrefix("["), trimmed.hasSuffix("]") {
            let inner = String(trimmed.dropFirst().dropLast())
            let items = splitYAMLInlineList(inner)
                .map { unquoteYAMLString($0.trimmingCharacters(in: .whitespaces)) }
                .filter { !$0.isEmpty }
            return .list(items)
        }

        if trimmed.hasPrefix("{"), trimmed.hasSuffix("}") {
            return .yamlBlock(trimmed)
        }

        let normalized = trimmed.lowercased()
        if ["true", "false", "yes", "no", "on", "off"].contains(normalized) {
            return .scalar(trimmed, .boolean)
        }

        if ["null", "~"].contains(normalized) {
            return .scalar(trimmed, .null)
        }

        let unquoted = unquoteYAMLString(trimmed)

        if isYAMLDate(unquoted) {
            return .scalar(unquoted, .date)
        }

        if isYAMLNumber(unquoted) {
            return .scalar(unquoted, .number)
        }

        return .scalar(unquoted, .string)
    }

    private func normalizeYAMLBlock(_ lines: [String]) -> String {
        var blockLines = lines

        while blockLines.first?.trimmingCharacters(in: .whitespaces).isEmpty == true {
            blockLines.removeFirst()
        }

        while blockLines.last?.trimmingCharacters(in: .whitespaces).isEmpty == true {
            blockLines.removeLast()
        }

        let indentation = blockLines
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { line in line.prefix(while: { $0 == " " || $0 == "\t" }).count }
            .min() ?? 0

        return blockLines.map { line in
            guard line.count >= indentation else { return line }
            return String(line.dropFirst(indentation))
        }.joined(separator: "\n")
    }

    private func foldYAMLBlock(_ block: String) -> String {
        block.components(separatedBy: "\n")
            .reduce(into: [String]()) { paragraphs, line in
                if line.trimmingCharacters(in: .whitespaces).isEmpty {
                    paragraphs.append("")
                } else if let last = paragraphs.indices.last, !paragraphs[last].isEmpty {
                    paragraphs[last] += " " + line.trimmingCharacters(in: .whitespaces)
                } else {
                    paragraphs.append(line.trimmingCharacters(in: .whitespaces))
                }
            }
            .joined(separator: "\n")
    }

    private func splitYAMLInlineList(_ text: String) -> [String] {
        var items: [String] = []
        var current = ""
        var inSingleQuote = false
        var inDoubleQuote = false
        var isEscaped = false
        var nestingDepth = 0

        for character in text {
            if inDoubleQuote, character == "\\", !isEscaped {
                isEscaped = true
                current.append(character)
                continue
            }

            if character == "'", !inDoubleQuote {
                inSingleQuote.toggle()
            } else if character == "\"", !inSingleQuote, !isEscaped {
                inDoubleQuote.toggle()
            } else if !inSingleQuote, !inDoubleQuote {
                if character == "[" || character == "{" {
                    nestingDepth += 1
                } else if character == "]" || character == "}" {
                    nestingDepth = max(0, nestingDepth - 1)
                } else if character == ",", nestingDepth == 0 {
                    items.append(current)
                    current = ""
                    continue
                }
            }

            current.append(character)
            isEscaped = false
        }

        if !current.isEmpty {
            items.append(current)
        }

        return items
    }

    private func unquoteYAMLString(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespaces)

        if trimmed.count >= 2, trimmed.hasPrefix("'"), trimmed.hasSuffix("'") {
            return String(trimmed.dropFirst().dropLast()).replacingOccurrences(of: "''", with: "'")
        }

        if trimmed.count >= 2, trimmed.hasPrefix("\""), trimmed.hasSuffix("\"") {
            return String(trimmed.dropFirst().dropLast())
                .replacingOccurrences(of: "\\\"", with: "\"")
                .replacingOccurrences(of: "\\\\", with: "\\")
                .replacingOccurrences(of: "\\n", with: "\n")
                .replacingOccurrences(of: "\\t", with: "\t")
        }

        return trimmed
    }

    private func isYAMLDate(_ value: String) -> Bool {
        value.range(
            of: #"^\d{4}-\d{2}-\d{2}(?:[Tt ][0-9:.+-]+)?$"#,
            options: .regularExpression
        ) != nil
    }

    private func isYAMLNumber(_ value: String) -> Bool {
        value.range(
            of: #"^[+-]?(?:\d[\d_]*(?:\.\d[\d_]*)?|\.\d[\d_]*)(?:[eE][+-]?\d[\d_]*)?$"#,
            options: .regularExpression
        ) != nil
    }

    // MARK: - Markdown → HTML

    private func markdownToHTML(_ text: String) -> String {
        let lines = text.components(separatedBy: "\n")
        var html: [String] = []
        var i = 0
        var inCodeBlock = false
        var codeLanguage = ""
        var codeLines: [String] = []
        var inList = false
        var listType = ""

        while i < lines.count {
            let line = lines[i]

            // Fenced code blocks
            if line.hasPrefix("```") {
                if inCodeBlock {
                    let code = codeLines.joined(separator: "\n")
                    let highlighted = highlightCode(code, language: codeLanguage)
                    html.append("<pre><code>\(highlighted)</code></pre>")
                    codeLines = []
                    inCodeBlock = false
                    codeLanguage = ""
                } else {
                    closeList(&html, &inList, &listType)
                    inCodeBlock = true
                    codeLanguage = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces).lowercased()
                }
                i += 1
                continue
            }

            if inCodeBlock {
                codeLines.append(line)
                i += 1
                continue
            }

            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                closeList(&html, &inList, &listType)
                i += 1
                continue
            }

            if let (level, content) = parseHeading(line) {
                closeList(&html, &inList, &listType)
                html.append("<h\(level)>\(inlineMarkdown(content))</h\(level)>")
                i += 1
                continue
            }

            if isHorizontalRule(trimmed) {
                closeList(&html, &inList, &listType)
                html.append("<hr>")
                i += 1
                continue
            }

            if trimmed.hasPrefix(">") {
                closeList(&html, &inList, &listType)
                var quoteLines: [String] = []
                while i < lines.count {
                    let ql = lines[i]
                    if ql.trimmingCharacters(in: .whitespaces).hasPrefix(">") {
                        let content = String(ql.drop(while: { $0 == " " }).dropFirst().drop(while: { $0 == " " }))
                        quoteLines.append(content)
                        i += 1
                    } else { break }
                }
                html.append("<blockquote>\(inlineMarkdown(quoteLines.joined(separator: "<br>")))</blockquote>")
                continue
            }

            // Table: current line has pipes AND next line is a separator row
            if trimmed.contains("|"),
               i + 1 < lines.count,
               isTableSeparator(lines[i + 1]) {
                closeList(&html, &inList, &listType)
                html.append(parseTable(lines, &i))
                continue
            }

            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ") {
                if !inList || listType != "ul" {
                    closeList(&html, &inList, &listType)
                    html.append("<ul>")
                    inList = true
                    listType = "ul"
                }
                html.append("<li>\(inlineMarkdown(String(trimmed.dropFirst(2))))</li>")
                i += 1
                continue
            }

            if let range = trimmed.range(of: #"^\d+\.\s"#, options: .regularExpression) {
                if !inList || listType != "ol" {
                    closeList(&html, &inList, &listType)
                    html.append("<ol>")
                    inList = true
                    listType = "ol"
                }
                html.append("<li>\(inlineMarkdown(String(trimmed[range.upperBound...])))</li>")
                i += 1
                continue
            }

            closeList(&html, &inList, &listType)
            html.append("<p>\(inlineMarkdown(trimmed))</p>")
            i += 1
        }

        if inCodeBlock {
            let code = codeLines.joined(separator: "\n")
            html.append("<pre><code>\(highlightCode(code, language: codeLanguage))</code></pre>")
        }
        closeList(&html, &inList, &listType)

        return html.joined(separator: "\n")
    }

    // MARK: - Table parsing

    private func isTableSeparator(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.contains("|") && trimmed.contains("-")
            && trimmed.allSatisfy({ $0 == "|" || $0 == "-" || $0 == ":" || $0 == " " })
    }

    private func parseTable(_ lines: [String], _ i: inout Int) -> String {
        var rows: [[String]] = []
        // Header row
        rows.append(parseTableRow(lines[i]))
        i += 1
        // Skip separator row
        if i < lines.count && isTableSeparator(lines[i]) { i += 1 }
        // Body rows
        while i < lines.count && lines[i].contains("|") {
            let trimmed = lines[i].trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { break }
            rows.append(parseTableRow(lines[i]))
            i += 1
        }
        var html = "<table><thead><tr>"
        if let header = rows.first {
            for cell in header {
                html += "<th>\(inlineMarkdown(cell.trimmingCharacters(in: .whitespaces)))</th>"
            }
        }
        html += "</tr></thead><tbody>"
        for row in rows.dropFirst() {
            html += "<tr>"
            for cell in row {
                html += "<td>\(inlineMarkdown(cell.trimmingCharacters(in: .whitespaces)))</td>"
            }
            html += "</tr>"
        }
        html += "</tbody></table>"
        return html
    }

    private func parseTableRow(_ line: String) -> [String] {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let stripped = trimmed.hasPrefix("|") ? String(trimmed.dropFirst()) : trimmed
        let end = stripped.hasSuffix("|") ? String(stripped.dropLast()) : stripped
        return end.components(separatedBy: "|")
    }

    // MARK: - Helpers

    private func closeList(_ html: inout [String], _ inList: inout Bool, _ listType: inout String) {
        if inList {
            html.append("</\(listType)>")
            inList = false
            listType = ""
        }
    }

    private func parseHeading(_ line: String) -> (Int, String)? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        var level = 0
        for ch in trimmed {
            if ch == "#" { level += 1 } else { break }
        }
        guard level >= 1, level <= 6, trimmed.count > level,
              trimmed[trimmed.index(trimmed.startIndex, offsetBy: level)] == " " else {
            return nil
        }
        return (level, String(trimmed.dropFirst(level + 1)))
    }

    private func isHorizontalRule(_ trimmed: String) -> Bool {
        trimmed.allSatisfy({ $0 == "-" || $0 == "*" || $0 == "_" || $0 == " " })
            && trimmed.filter({ $0 != " " }).count >= 3
            && Set(trimmed.filter({ $0 != " " })).count == 1
    }

    private func inlineMarkdown(_ text: String) -> String {
        var result = escapeHTML(text)
        result = result.replacingOccurrences(
            of: #"!\[([^\]]*)\]\(([^)]+)\)"#, with: "<img src=\"$2\" alt=\"$1\">", options: .regularExpression)
        result = result.replacingOccurrences(
            of: #"\[([^\]]+)\]\(([^)]+)\)"#, with: "<a href=\"$2\">$1</a>", options: .regularExpression)
        result = result.replacingOccurrences(
            of: #"\*\*\*(.+?)\*\*\*"#, with: "<strong><em>$1</em></strong>", options: .regularExpression)
        result = result.replacingOccurrences(
            of: #"\*\*(.+?)\*\*"#, with: "<strong>$1</strong>", options: .regularExpression)
        result = result.replacingOccurrences(
            of: #"__(.+?)__"#, with: "<strong>$1</strong>", options: .regularExpression)
        result = result.replacingOccurrences(
            of: #"(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)"#, with: "<em>$1</em>", options: .regularExpression)
        result = result.replacingOccurrences(
            of: #"~~(.+?)~~"#, with: "<del>$1</del>", options: .regularExpression)
        result = result.replacingOccurrences(
            of: #"`([^`]+)`"#, with: "<code>$1</code>", options: .regularExpression)
        return result
    }

    private func escapeHTML(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    // MARK: - Syntax highlighting

    private func highlightCode(_ code: String, language: String) -> String {
        let escaped = escapeHTML(code)
        switch language {
        case "yaml", "yml": return highlightYAML(escaped)
        case "json": return highlightJSON(escaped)
        case "swift": return highlightSwift(escaped)
        case "javascript", "js", "typescript", "ts": return highlightJS(escaped)
        case "python", "py": return highlightPython(escaped)
        case "shell", "bash", "sh", "zsh": return highlightShell(escaped)
        default: return escaped
        }
    }

    private func highlightYAML(_ code: String) -> String {
        var result: [String] = []
        for line in code.components(separatedBy: "\n") {
            var highlighted = line
            if let range = highlighted.range(of: #"(#.*)$"#, options: .regularExpression) {
                let comment = highlighted[range]
                highlighted = highlighted.replacingCharacters(in: range, with: "<span class=\"sy-comment\">\(comment)</span>")
                result.append(highlighted)
                continue
            }
            if let range = highlighted.range(of: #"^(\s*)([\w\-./&quot;@][^:]*?)(:)"#, options: .regularExpression) {
                let match = String(highlighted[range])
                let replaced = match.replacingOccurrences(
                    of: #"^(\s*)([\w\-./&quot;@][^:]*?)(:)"#,
                    with: "$1<span class=\"sy-key\">$2</span><span class=\"sy-punctuation\">$3</span>",
                    options: .regularExpression
                )
                highlighted = replaced + String(highlighted[range.upperBound...])
            }
            highlighted = highlighted.replacingOccurrences(
                of: #"(&#39;[^&#]*?&#39;|&quot;[^&]*?&quot;)"#,
                with: "<span class=\"sy-string\">$1</span>", options: .regularExpression)
            highlighted = highlighted.replacingOccurrences(
                of: #"\b(true|false|yes|no|null|~)\b"#,
                with: "<span class=\"sy-boolean\">$1</span>", options: .regularExpression)
            highlighted = highlighted.replacingOccurrences(
                of: #"(?<=:\s)(\d+\.?\d*)\b"#,
                with: "<span class=\"sy-number\">$1</span>", options: .regularExpression)
            result.append(highlighted)
        }
        return result.joined(separator: "\n")
    }

    private func highlightJSON(_ code: String) -> String {
        var result = code
        result = result.replacingOccurrences(
            of: #"(&quot;[^&]*?&quot;)(\s*:)"#,
            with: "<span class=\"sy-key\">$1</span><span class=\"sy-punctuation\">$2</span>", options: .regularExpression)
        result = result.replacingOccurrences(
            of: #"(:\s*)(&quot;[^&]*?&quot;)"#,
            with: "$1<span class=\"sy-string\">$2</span>", options: .regularExpression)
        result = result.replacingOccurrences(
            of: #"\b(\d+\.?\d*)\b"#,
            with: "<span class=\"sy-number\">$1</span>", options: .regularExpression)
        result = result.replacingOccurrences(
            of: #"\b(true|false|null)\b"#,
            with: "<span class=\"sy-boolean\">$1</span>", options: .regularExpression)
        result = result.replacingOccurrences(
            of: #"([\{\}\[\]])"#,
            with: "<span class=\"sy-punctuation\">$1</span>", options: .regularExpression)
        return result
    }

    private func highlightSwift(_ code: String) -> String {
        let keywords = [
            "import", "func", "var", "let", "struct", "class", "enum", "protocol",
            "if", "else", "guard", "switch", "case", "default", "for", "while", "repeat",
            "return", "throw", "throws", "try", "catch", "do", "break", "continue",
            "public", "private", "internal", "fileprivate", "open", "static", "override",
            "init", "deinit", "self", "Self", "super", "nil", "true", "false",
            "async", "await", "actor", "some", "any", "where", "in", "as", "is",
            "@State", "@Binding", "@Published", "@Observable", "@Environment",
            "@AppStorage", "@main", "@escaping", "@objc", "@MainActor",
        ]
        return highlightGeneric(code, keywords: keywords, lineComment: "//")
    }

    private func highlightJS(_ code: String) -> String {
        let keywords = [
            "import", "export", "from", "default", "function", "const", "let", "var",
            "if", "else", "switch", "case", "for", "while", "do", "return", "throw",
            "try", "catch", "finally", "new", "delete", "typeof", "instanceof",
            "class", "extends", "constructor", "this", "super", "async", "await",
            "true", "false", "null", "undefined", "of", "in", "type", "interface",
            "enum", "implements", "readonly", "abstract", "as",
        ]
        return highlightGeneric(code, keywords: keywords, lineComment: "//")
    }

    private func highlightPython(_ code: String) -> String {
        let keywords = [
            "import", "from", "def", "class", "if", "elif", "else", "for", "while",
            "return", "yield", "try", "except", "finally", "raise", "with", "as",
            "pass", "break", "continue", "and", "or", "not", "in", "is", "lambda",
            "True", "False", "None", "self", "async", "await", "global", "nonlocal",
        ]
        return highlightGeneric(code, keywords: keywords, lineComment: "#")
    }

    private func highlightShell(_ code: String) -> String {
        let keywords = [
            "if", "then", "else", "elif", "fi", "for", "while", "do", "done",
            "case", "esac", "function", "return", "exit", "export", "local",
            "echo", "cd", "ls", "rm", "cp", "mv", "mkdir", "grep", "sed", "awk",
            "cat", "curl", "wget", "git", "npm", "npx", "yarn", "pnpm",
            "true", "false",
        ]
        return highlightGeneric(code, keywords: keywords, lineComment: "#")
    }

    private func highlightGeneric(_ code: String, keywords: [String], lineComment: String) -> String {
        var result = code
        result = result.replacingOccurrences(
            of: "(\(NSRegularExpression.escapedPattern(for: lineComment)).*)",
            with: "<span class=\"sy-comment\">$1</span>", options: .regularExpression)
        result = result.replacingOccurrences(
            of: #"(&quot;[^&]*?&quot;)"#,
            with: "<span class=\"sy-string\">$1</span>", options: .regularExpression)
        result = result.replacingOccurrences(
            of: #"(&#39;[^&#]*?&#39;)"#,
            with: "<span class=\"sy-string\">$1</span>", options: .regularExpression)
        result = result.replacingOccurrences(
            of: #"\b(\d+\.?\d*)\b"#,
            with: "<span class=\"sy-number\">$1</span>", options: .regularExpression)
        for kw in keywords {
            if kw.hasPrefix("@") {
                result = result.replacingOccurrences(
                    of: "(\(NSRegularExpression.escapedPattern(for: kw)))\\b",
                    with: "<span class=\"sy-keyword\">$1</span>", options: .regularExpression)
            } else {
                result = result.replacingOccurrences(
                    of: "\\b(\(NSRegularExpression.escapedPattern(for: kw)))\\b",
                    with: "<span class=\"sy-keyword\">$1</span>", options: .regularExpression)
            }
        }
        return result
    }
}
