import SwiftUI
import WebKit
import Markdown

// jaywcjlove/swiftui-markdown wraps a WKWebView internally (the library has its own
// MarkdownWebView.swift). To make this renderer a peer of the others — participating
// in cross-pane scroll sync and honoring the font-size buttons — we locate the
// library's WKWebView at runtime via a sibling NSView placed in `.background`,
// then inject:
//   • a scroll-position bridge (matches MarkdownWebView's JS↔Swift contract)
//   • a CSS font-size override
// It also observes the WKWebView's AppKit scroll view directly, because macOS
// WebKit scrolling is not always reported through DOM `window` scroll events.
struct SwiftUIMarkdownView: View {
    let markdown: String
    let fontSize: Double
    let theme: MarkdownTheme
    let scrollPosition: RendererScrollPosition
    let scrollApplyToken: UUID
    let source: String

    @State private var content: String = ""

    var body: some View {
        Markdown(content: $content)
            .background(
                SwiftUIMarkdownBridge(
                    fontSize: fontSize,
                    theme: theme,
                    scrollPosition: scrollPosition,
                    applyToken: scrollApplyToken,
                    source: source
                )
            )
            .background(theme.tokens.documentBackground)
            .modifier(ThemeColorSchemeModifier(theme: theme))
            .onAppear { content = renderableMarkdown(markdown) }
            .onChange(of: markdown) { _, newValue in content = renderableMarkdown(newValue) }
    }

    private func renderableMarkdown(_ text: String) -> String {
        guard let frontMatter = FrontMatterDocument.split(from: text) else {
            return text
        }

        let yamlBlock = """
        ```yaml
        ---
        \(frontMatter.yaml)
        ---
        ```
        """

        guard !frontMatter.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return yamlBlock
        }

        return [yamlBlock, frontMatter.body].joined(separator: "\n\n")
    }
}

private struct FrontMatterDocument {
    let yaml: String
    let body: String

    static func split(from text: String) -> FrontMatterDocument? {
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
                return FrontMatterDocument(yaml: yaml, body: body)
            }
        }

        return nil
    }
}

private struct SwiftUIMarkdownBridge: NSViewRepresentable {
    let fontSize: Double
    let theme: MarkdownTheme
    let scrollPosition: RendererScrollPosition
    let applyToken: UUID
    let source: String

    func makeCoordinator() -> Coordinator {
        Coordinator(
            scrollPosition: scrollPosition,
            source: source,
            handlerName: "paneScrollBridge_\(source)"
        )
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.bridgeView = view
        context.coordinator.scheduleAttachAndApply(
            fontSize: fontSize,
            theme: theme,
            applyToken: applyToken,
            attemptsRemaining: 30
        )
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        context.coordinator.scrollPosition = scrollPosition
        context.coordinator.source = source
        context.coordinator.scheduleAttachAndApply(
            fontSize: fontSize,
            theme: theme,
            applyToken: applyToken,
            attemptsRemaining: 10
        )
    }

    final class Coordinator: NSObject, WKScriptMessageHandler {
        var scrollPosition: RendererScrollPosition
        var source: String
        let handlerName: String
        weak var bridgeView: NSView?

        private weak var webView: WKWebView?
        private weak var webScrollView: NSScrollView?
        private var scrollObserver: NSObjectProtocol?
        private var bridgeInstalled = false
        private var lastFontSize: Double?
        private var lastTheme: MarkdownTheme?
        private var lastApplyToken: UUID?
        private var isApplyingScroll = false

        init(scrollPosition: RendererScrollPosition, source: String, handlerName: String) {
            self.scrollPosition = scrollPosition
            self.source = source
            self.handlerName = handlerName
        }

        deinit {
            if let scrollObserver {
                NotificationCenter.default.removeObserver(scrollObserver)
            }
            webView?.configuration.userContentController.removeScriptMessageHandler(forName: handlerName)
        }

        func scheduleAttachAndApply(fontSize: Double, theme: MarkdownTheme, applyToken: UUID, attemptsRemaining: Int) {
            DispatchQueue.main.async { [weak self] in
                self?.tryAttachAndApply(
                    fontSize: fontSize,
                    theme: theme,
                    applyToken: applyToken,
                    attemptsRemaining: attemptsRemaining
                )
            }
        }

        private func tryAttachAndApply(fontSize: Double, theme: MarkdownTheme, applyToken: UUID, attemptsRemaining: Int) {
            if webView == nil, let bridgeView {
                webView = findWebView(near: bridgeView)
            }
            if let webView {
                attachScrollObserverIfNeeded(in: webView)
                installBridgeIfNeeded(in: webView)
                applyFontSizeIfNeeded(fontSize, in: webView)
                applyThemeIfNeeded(theme, in: webView)
                applyScrollIfNeeded(applyToken: applyToken, in: webView)
                return
            }
            guard attemptsRemaining > 0 else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.tryAttachAndApply(
                    fontSize: fontSize,
                    theme: theme,
                    applyToken: applyToken,
                    attemptsRemaining: attemptsRemaining - 1
                )
            }
        }

        // Walk up ancestor chain; for each ancestor, search its subtree for a WKWebView.
        // The first hit is the closest one — in compare mode each pane has its own
        // local container, so the closest match is always the local pane's web view.
        private func findWebView(near view: NSView) -> WKWebView? {
            var ancestor: NSView? = view.superview
            while let candidate = ancestor {
                if let found = recursiveFindWebView(in: candidate) {
                    return found
                }
                ancestor = candidate.superview
            }
            return nil
        }

        private func recursiveFindWebView(in view: NSView) -> WKWebView? {
            if let wk = view as? WKWebView { return wk }
            for sub in view.subviews {
                if let found = recursiveFindWebView(in: sub) { return found }
            }
            return nil
        }

        private func attachScrollObserverIfNeeded(in webView: WKWebView) {
            guard let scrollView = recursiveFindScrollView(in: webView),
                  scrollView !== webScrollView else {
                return
            }

            if let scrollObserver {
                NotificationCenter.default.removeObserver(scrollObserver)
            }

            webScrollView = scrollView
            scrollView.contentView.postsBoundsChangedNotifications = true
            scrollObserver = NotificationCenter.default.addObserver(
                forName: NSView.boundsDidChangeNotification,
                object: scrollView.contentView,
                queue: .main
            ) { [weak self] _ in
                self?.recordNativeScrollPosition()
            }
        }

        private func recursiveFindScrollView(in view: NSView) -> NSScrollView? {
            if let scrollView = view as? NSScrollView { return scrollView }
            for subview in view.subviews {
                if let found = recursiveFindScrollView(in: subview) { return found }
            }
            return nil
        }

        private func installBridgeIfNeeded(in webView: WKWebView) {
            guard !bridgeInstalled else { return }
            bridgeInstalled = true

            webView.configuration.userContentController.add(self, name: handlerName)

            let js = """
            (() => {
              const id = "\(handlerName)";
              if (window["__bridgeInstalled_" + id]) return;
              window["__bridgeInstalled_" + id] = true;
              let pending = false;
              const handler = window.webkit.messageHandlers[id];
              const scrollingElement = () => document.scrollingElement || document.documentElement || document.body;
              const maxScroll = () => {
                const el = scrollingElement();
                return Math.max(0, el.scrollHeight - el.clientHeight);
              };
              const currentScroll = () => {
                const el = scrollingElement();
                return el.scrollTop || window.scrollY || 0;
              };
              const report = () => {
                if (pending) return;
                pending = true;
                requestAnimationFrame(() => {
                  pending = false;
                  const m = maxScroll();
                  const f = m === 0 ? 0 : currentScroll() / m;
                  handler.postMessage({ fraction: f });
                });
              };
              window.addEventListener("scroll", report, { passive: true });
              document.addEventListener("scroll", report, { passive: true, capture: true });
            })();
            """
            evaluateRetrying(js, in: webView, attemptsRemaining: 20)
        }

        private func applyFontSizeIfNeeded(_ fontSize: Double, in webView: WKWebView) {
            guard lastFontSize != fontSize else { return }
            lastFontSize = fontSize
            let codeFontSize = FrontMatterTypography.codeSize(for: fontSize)
            let js = """
            (function() {
              var px = '\(fontSize)px';
              var codePx = '\(codeFontSize)px';
              document.documentElement.style.fontSize = px;
              if (document.body) document.body.style.fontSize = px;
              var styleId = '__pane_font_size_override__';
              var existing = document.getElementById(styleId);
              var s;
              if (existing) {
                s = existing;
              } else {
                s = document.createElement('style');
                s.id = styleId;
                (document.head || document.documentElement).appendChild(s);
              }
              s.textContent = [
                'body { font-size: ' + px + ' !important; }',
                'pre, code { font-size: ' + codePx + ' !important; }',
                'pre code { font-size: inherit !important; }'
              ].join('\\n');
            })();
            """
            evaluateRetrying(js, in: webView, attemptsRemaining: 20)
        }

        private func applyThemeIfNeeded(_ theme: MarkdownTheme, in webView: WKWebView) {
            guard lastTheme != theme else { return }
            lastTheme = theme
            let css = """
            \(theme.cssVariableRule)
            html, body {
              background: var(--md-bg) !important;
              color: var(--md-fg) !important;
            }
            body, p, li, td, th, div, span, h1, h2, h3, h4, h5, h6 {
              color: var(--md-fg) !important;
            }
            ul, ol {
              color: var(--md-fg) !important;
            }
            a {
              color: var(--md-link) !important;
            }
            code {
              background: var(--md-inline-code-bg) !important;
              color: var(--md-inline-code-fg) !important;
            }
            pre {
              background: var(--md-code-bg) !important;
              border-color: var(--md-border) !important;
              color: var(--md-fg) !important;
            }
            pre code {
              background: transparent !important;
              color: inherit !important;
            }
            blockquote {
              border-color: var(--md-border) !important;
              color: var(--md-secondary) !important;
            }
            hr {
              border-color: var(--md-border) !important;
              background: var(--md-border) !important;
            }
            table {
              border-color: var(--md-border) !important;
            }
            th, td {
              border-color: var(--md-border) !important;
            }
            th {
              background: var(--md-table-header-bg) !important;
            }
            tr:nth-child(even) td {
              background: var(--md-table-stripe-bg) !important;
            }
            """
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")
                .replacingOccurrences(of: "\n", with: "\\n")
            let js = """
            (function() {
              var styleId = '__pane_theme_override__';
              var existing = document.getElementById(styleId);
              var s;
              if (existing) {
                s = existing;
              } else {
                s = document.createElement('style');
                s.id = styleId;
                (document.head || document.documentElement).appendChild(s);
              }
              s.textContent = '\(css)';
            })();
            """
            evaluateRetrying(js, in: webView, attemptsRemaining: 20)
        }

        private func applyScrollIfNeeded(applyToken: UUID, in webView: WKWebView) {
            guard lastApplyToken != applyToken else { return }
            lastApplyToken = applyToken
            guard scrollPosition.activeSource != source else { return }
            isApplyingScroll = true
            let fraction = min(max(scrollPosition.fraction, 0), 1)
            if let webScrollView {
                scroll(to: fraction, in: webScrollView)
            }
            let js = """
            (() => {
              const el = document.scrollingElement || document.documentElement || document.body;
              const maxY = Math.max(0, el.scrollHeight - el.clientHeight);
              const y = maxY * \(fraction);
              el.scrollTop = y;
              window.scrollTo(0, y);
            })();
            """
            webView.evaluateJavaScript(js) { [weak self] _, _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    self?.isApplyingScroll = false
                }
            }
        }

        private func evaluateRetrying(_ js: String, in webView: WKWebView, attemptsRemaining: Int) {
            webView.evaluateJavaScript(js) { [weak self, weak webView] _, error in
                guard let webView, error != nil, attemptsRemaining > 0 else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self?.evaluateRetrying(js, in: webView, attemptsRemaining: attemptsRemaining - 1)
                }
            }
        }

        private func recordNativeScrollPosition() {
            guard !isApplyingScroll, let webScrollView else { return }
            scrollPosition.update(fraction: currentFraction(in: webScrollView), source: source)
        }

        private func scroll(to fraction: CGFloat, in scrollView: NSScrollView) {
            let maximumY = max(0, documentHeight(in: scrollView) - scrollView.contentView.bounds.height)
            let y = min(max(fraction, 0), 1) * maximumY
            let currentX = scrollView.contentView.bounds.origin.x
            scrollView.contentView.scroll(to: NSPoint(x: currentX, y: y))
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }

        private func currentFraction(in scrollView: NSScrollView) -> CGFloat {
            let maximumY = max(0, documentHeight(in: scrollView) - scrollView.contentView.bounds.height)
            guard maximumY > 0 else { return 0 }
            return min(max(scrollView.contentView.bounds.origin.y / maximumY, 0), 1)
        }

        private func documentHeight(in scrollView: NSScrollView) -> CGFloat {
            scrollView.documentView?.bounds.height ?? 0
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard message.name == handlerName,
                  !isApplyingScroll,
                  let body = message.body as? [String: Any],
                  let fraction = body["fraction"] as? Double else {
                return
            }
            scrollPosition.update(fraction: CGFloat(fraction), source: source)
        }
    }
}
