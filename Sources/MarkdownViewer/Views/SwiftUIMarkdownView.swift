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
struct SwiftUIMarkdownView: View {
    let markdown: String
    let fontSize: Double
    let scrollPosition: RendererScrollPosition
    let scrollApplyToken: UUID
    let source: String

    @State private var content: String = ""

    var body: some View {
        Markdown(content: $content)
            .background(
                SwiftUIMarkdownBridge(
                    fontSize: fontSize,
                    scrollPosition: scrollPosition,
                    applyToken: scrollApplyToken,
                    source: source
                )
            )
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
        private var bridgeInstalled = false
        private var lastFontSize: Double?
        private var lastApplyToken: UUID?
        private var isApplyingScroll = false

        init(scrollPosition: RendererScrollPosition, source: String, handlerName: String) {
            self.scrollPosition = scrollPosition
            self.source = source
            self.handlerName = handlerName
        }

        deinit {
            webView?.configuration.userContentController.removeScriptMessageHandler(forName: handlerName)
        }

        func scheduleAttachAndApply(fontSize: Double, applyToken: UUID, attemptsRemaining: Int) {
            DispatchQueue.main.async { [weak self] in
                self?.tryAttachAndApply(
                    fontSize: fontSize,
                    applyToken: applyToken,
                    attemptsRemaining: attemptsRemaining
                )
            }
        }

        private func tryAttachAndApply(fontSize: Double, applyToken: UUID, attemptsRemaining: Int) {
            if webView == nil, let bridgeView {
                webView = findWebView(near: bridgeView)
                if webView != nil {
                    LogStore.shared.log(
                        "SwiftUI-Markdown bridge attached (\(source))",
                        level: .debug,
                        category: "ui"
                    )
                }
            }
            if let webView {
                installBridgeIfNeeded(in: webView)
                applyFontSizeIfNeeded(fontSize, in: webView)
                applyScrollIfNeeded(applyToken: applyToken, in: webView)
                return
            }
            guard attemptsRemaining > 0 else {
                LogStore.shared.log(
                    "SwiftUI-Markdown bridge gave up locating WKWebView (\(source)) — scroll sync and font scaling unavailable for this pane",
                    level: .warning,
                    category: "ui"
                )
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.tryAttachAndApply(
                    fontSize: fontSize,
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
              const maxScroll = () => Math.max(0, document.documentElement.scrollHeight - window.innerHeight);
              window.addEventListener("scroll", () => {
                if (pending) return;
                pending = true;
                requestAnimationFrame(() => {
                  pending = false;
                  const m = maxScroll();
                  const f = m === 0 ? 0 : window.scrollY / m;
                  handler.postMessage({ fraction: f });
                });
              }, { passive: true });
            })();
            """
            evaluateRetrying(js, in: webView, attemptsRemaining: 20)
        }

        private func applyFontSizeIfNeeded(_ fontSize: Double, in webView: WKWebView) {
            guard lastFontSize != fontSize else { return }
            lastFontSize = fontSize
            let js = """
            (function() {
              var px = '\(fontSize)px';
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
              s.textContent = 'body { font-size: ' + px + '; }';
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
            let js = """
            (() => {
              const maxY = Math.max(0, document.documentElement.scrollHeight - window.innerHeight);
              window.scrollTo(0, maxY * \(fraction));
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
