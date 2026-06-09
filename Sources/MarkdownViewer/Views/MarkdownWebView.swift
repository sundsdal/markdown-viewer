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
    let searchQuery: String
    let searchIsCaseSensitive: Bool
    let selectedSearchHitIndex: Int
    let onSearchHitCountChange: (Int) -> Void

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.suppressesIncrementalRendering = true
        config.userContentController.add(context.coordinator, name: "scrollPosition")
        config.userContentController.add(context.coordinator, name: "searchHitCount")

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
        context.coordinator.onSearchHitCountChange = onSearchHitCountChange
        let signature = documentSignature(markdown: markdown, fontSize: fontSize)

        if context.coordinator.loadedDocumentSignature != signature {
            context.coordinator.loadedDocumentSignature = signature
            context.coordinator.lastTheme = theme
            context.coordinator.invalidateSearchHighlightCache()
            webView.loadHTMLString(buildFullHTML(markdown: markdown, fontSize: fontSize, theme: theme), baseURL: nil)
        } else {
            context.coordinator.applyThemeIfNeeded(theme)
            context.coordinator.applySearchIfNeeded(
                query: searchQuery,
                isCaseSensitive: searchIsCaseSensitive,
                selectedIndex: selectedSearchHitIndex
            )
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
            synchronizesScroll: synchronizesScroll,
            searchQuery: searchQuery,
            searchIsCaseSensitive: searchIsCaseSensitive,
            selectedSearchHitIndex: selectedSearchHitIndex,
            onSearchHitCountChange: onSearchHitCountChange
        )
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        weak var webView: WKWebView?
        var scrollPosition: RendererScrollPosition
        var source: String
        var synchronizesScroll: Bool
        var onSearchHitCountChange: (Int) -> Void
        var loadedDocumentSignature: String?
        var lastApplyToken: UUID?
        var lastTheme: MarkdownTheme?
        private var isApplyingScroll = false
        private var pendingSearchQuery: String
        private var pendingSearchIsCaseSensitive: Bool
        private var pendingSelectedSearchHitIndex: Int
        private var appliedSearchQuery: String?
        private var appliedSearchIsCaseSensitive: Bool?
        private var appliedSelectedSearchHitIndex: Int?
        private var hasFinishedInitialLoad = false
        private var lastReportedHitCount = -1

        init(
            scrollPosition: RendererScrollPosition,
            source: String,
            synchronizesScroll: Bool,
            searchQuery: String,
            searchIsCaseSensitive: Bool,
            selectedSearchHitIndex: Int,
            onSearchHitCountChange: @escaping (Int) -> Void
        ) {
            self.scrollPosition = scrollPosition
            self.source = source
            self.synchronizesScroll = synchronizesScroll
            self.pendingSearchQuery = searchQuery
            self.pendingSearchIsCaseSensitive = searchIsCaseSensitive
            self.pendingSelectedSearchHitIndex = selectedSearchHitIndex
            self.onSearchHitCountChange = onSearchHitCountChange
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            hasFinishedInitialLoad = true
            appliedSearchQuery = nil
            appliedSearchIsCaseSensitive = nil
            appliedSelectedSearchHitIndex = nil
            applyScrollPositionIfNeeded()
            applySearchIfNeeded(
                query: pendingSearchQuery,
                isCaseSensitive: pendingSearchIsCaseSensitive,
                selectedIndex: pendingSelectedSearchHitIndex
            )
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            switch message.name {
            case "scrollPosition":
                guard !isApplyingScroll,
                      let body = message.body as? [String: Any],
                      let fraction = body["fraction"] as? Double else {
                    return
                }
                scrollPosition.update(
                    fraction: CGFloat(fraction),
                    source: source,
                    broadcast: synchronizesScroll
                )
            case "searchHitCount":
                guard let count = message.body as? Int else { return }
                if count != lastReportedHitCount {
                    lastReportedHitCount = count
                    onSearchHitCountChange(count)
                }
            default:
                break
            }
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

        func applySearchIfNeeded(query: String, isCaseSensitive: Bool, selectedIndex: Int) {
            pendingSearchQuery = query
            pendingSearchIsCaseSensitive = isCaseSensitive
            pendingSelectedSearchHitIndex = selectedIndex

            guard hasFinishedInitialLoad, let webView else { return }

            let queryChanged = appliedSearchQuery != query
                || appliedSearchIsCaseSensitive != isCaseSensitive
            let selectionChanged = appliedSelectedSearchHitIndex != selectedIndex

            guard queryChanged || selectionChanged else { return }

            if queryChanged {
                appliedSearchQuery = query
                appliedSearchIsCaseSensitive = isCaseSensitive
                let escapedQuery = MarkdownWebView.escapeForJavaScriptStringLiteral(query)
                let script = "window.__markdownFind && window.__markdownFind.applyHighlights('\(escapedQuery)', \(isCaseSensitive ? "true" : "false"), \(selectedIndex));"
                webView.evaluateJavaScript(script)
                appliedSelectedSearchHitIndex = selectedIndex
            } else if selectionChanged {
                appliedSelectedSearchHitIndex = selectedIndex
                let script = "window.__markdownFind && window.__markdownFind.setSelected(\(selectedIndex));"
                webView.evaluateJavaScript(script)
            }
        }

        func invalidateSearchHighlightCache() {
            appliedSearchQuery = nil
            appliedSearchIsCaseSensitive = nil
            appliedSelectedSearchHitIndex = nil
            hasFinishedInitialLoad = false
            lastReportedHitCount = -1
        }
    }

    private static func escapeForJavaScriptStringLiteral(_ value: String) -> String {
        var result = ""
        result.reserveCapacity(value.count)
        for scalar in value.unicodeScalars {
            switch scalar {
            case "\\": result += "\\\\"
            case "'": result += "\\'"
            case "\"": result += "\\\""
            case "\n": result += "\\n"
            case "\r": result += "\\r"
            case "\t": result += "\\t"
            case "\u{2028}": result += "\\u2028"
            case "\u{2029}": result += "\\u2029"
            default: result.unicodeScalars.append(scalar)
            }
        }
        return result
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
        let body = MarkdownHTMLRenderer.renderMarkdownDocument(markdown)
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

            window.__markdownFind = (() => {
                const HIT_CLASS = "markdown-find-hit";
                const CURRENT_CLASS = "markdown-find-current";

                function escapeRegex(value) {
                    const specials = new Set([".", "*", "+", "?", "^", "$", "{", "}", "(", ")", "|", "[", "]", "\\\\"]);
                    return Array.from(value, (character) => specials.has(character) ? "\\\\" + character : character).join("");
                }

                function postHitCount(count) {
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.searchHitCount) {
                        window.webkit.messageHandlers.searchHitCount.postMessage(count);
                    }
                }

                function clearHighlights() {
                    const marks = document.querySelectorAll("mark." + HIT_CLASS);
                    marks.forEach((mark) => {
                        const parent = mark.parentNode;
                        if (!parent) return;
                        while (mark.firstChild) {
                            parent.insertBefore(mark.firstChild, mark);
                        }
                        parent.removeChild(mark);
                        parent.normalize();
                    });
                }

                function collectTextNodes(root) {
                    const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT, {
                        acceptNode(node) {
                            if (!node.nodeValue || !node.nodeValue.length) {
                                return NodeFilter.FILTER_REJECT;
                            }
                            const parent = node.parentNode;
                            if (!parent) return NodeFilter.FILTER_REJECT;
                            const tag = parent.nodeName;
                            if (tag === "SCRIPT" || tag === "STYLE" || tag === "MARK") {
                                return NodeFilter.FILTER_REJECT;
                            }
                            return NodeFilter.FILTER_ACCEPT;
                        }
                    });
                    const nodes = [];
                    let current;
                    while ((current = walker.nextNode())) {
                        nodes.push(current);
                    }
                    return nodes;
                }

                function applyHighlights(query, caseSensitive, selectedIndex) {
                    clearHighlights();
                    if (!query) {
                        postHitCount(0);
                        return 0;
                    }
                    const flags = caseSensitive ? "g" : "gi";
                    const regex = new RegExp(escapeRegex(query), flags);
                    const nodes = collectTextNodes(document.body);
                    let count = 0;

                    for (const node of nodes) {
                        const text = node.nodeValue;
                        regex.lastIndex = 0;
                        let lastIndex = 0;
                        const fragments = [];
                        let match;
                        while ((match = regex.exec(text)) !== null) {
                            if (match.index > lastIndex) {
                                fragments.push(document.createTextNode(text.substring(lastIndex, match.index)));
                            }
                            const mark = document.createElement("mark");
                            mark.className = HIT_CLASS;
                            mark.appendChild(document.createTextNode(match[0]));
                            fragments.push(mark);
                            lastIndex = regex.lastIndex;
                            count += 1;
                            if (match.index === regex.lastIndex) {
                                regex.lastIndex += 1;
                            }
                        }
                        if (fragments.length) {
                            if (lastIndex < text.length) {
                                fragments.push(document.createTextNode(text.substring(lastIndex)));
                            }
                            const parent = node.parentNode;
                            for (const fragment of fragments) {
                                parent.insertBefore(fragment, node);
                            }
                            parent.removeChild(node);
                        }
                    }

                    if (count > 0) {
                        setSelected(selectedIndex);
                    }
                    postHitCount(count);
                    return count;
                }

                function setSelected(index) {
                    const marks = document.querySelectorAll("mark." + HIT_CLASS);
                    document.querySelectorAll("mark." + CURRENT_CLASS).forEach((m) => m.classList.remove(CURRENT_CLASS));
                    if (!marks.length) return;
                    const clamped = Math.max(0, Math.min(index, marks.length - 1));
                    const target = marks[clamped];
                    target.classList.add(CURRENT_CLASS);
                    const rect = target.getBoundingClientRect();
                    const viewportHeight = window.innerHeight || document.documentElement.clientHeight;
                    if (rect.top < 80 || rect.bottom > viewportHeight - 80) {
                        target.scrollIntoView({ block: "center", behavior: "auto" });
                    }
                }

                return { applyHighlights, setSelected, clearHighlights };
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
            mark.markdown-find-hit {
                background: rgba(255, 213, 0, 0.55);
                color: inherit;
                border-radius: 2px;
                padding: 0 1px;
                box-shadow: 0 0 0 1px rgba(255, 213, 0, 0.55);
            }
            mark.markdown-find-current {
                background: rgba(255, 138, 0, 0.95);
                color: #1a1a1a;
                box-shadow: 0 0 0 1px rgba(255, 138, 0, 0.95), 0 0 0 3px rgba(255, 138, 0, 0.25);
            }
        </style>
        </head>
        <body>
        \(body)
        </body>
        </html>
        """
    }

}
