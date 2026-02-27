# Swift libraries for building a beautiful markdown viewer

**MarkdownUI and Apple's swift-markdown dominate the Swift markdown ecosystem, but the landscape is shifting fast.** MarkdownUI (3,700+ stars) recently entered maintenance mode as its creator pivots to a successor library called Textual, while LiYanan2004's MarkdownView has emerged as the most actively maintained native SwiftUI option — already adopted by X (Grok) and Hugging Face Chat. For production apps in 2026, the winning combination is **Apple's swift-markdown for parsing** paired with either **MarkdownUI, MarkdownView, or the new Textual library for rendering**, with **HighlightSwift for code syntax highlighting**.

The ecosystem breaks into four layers: parsing (converting markdown text to structured data), rendering (turning that structure into native views), complete viewer components (drop-in solutions), and syntax highlighting (for code blocks). Choosing the right library at each layer — or picking an integrated solution — determines both visual quality and long-term maintainability.

---

## Parsing: Apple's swift-markdown is the clear winner

The parsing layer converts raw markdown text into an abstract syntax tree (AST) or structured representation that renderers can consume. **Apple's swift-markdown is the only actively maintained parser with full CommonMark and GitHub Flavored Markdown compliance.**

**Apple swift-markdown** ([swiftlang/swift-markdown](https://github.com/swiftlang/swift-markdown)) — **~3,200 stars**, actively maintained, Apache 2.0. Apple's official parser produces a rich, immutable, thread-safe, copy-on-write Swift value-type AST. It supports full GFM (tables, strikethrough, task lists, autolinks) via its cmark-gfm dependency and offers powerful visitor/rewriter patterns (`MarkupWalker`, `MarkupRewriter`, `MarkupFormatter`) for AST traversal and transformation. Used by Swift-DocC and battle-tested across Apple's documentation infrastructure. Runs on iOS, macOS, visionOS, Linux, and even WebAssembly. The main limitation is that **it is purely a parser** — it produces no visual output, requiring a separate renderer like Markdownosaur or MarkdownView.

**Down** ([johnxnguyen/Down](https://github.com/johnxnguyen/Down)) — **~2,500 stars**, effectively unmaintained. Wraps the original cmark (not cmark-gfm), giving it full CommonMark compliance but **no GFM support** — no tables, strikethrough, or task lists. Its unique strength is output format variety: HTML, XML, LaTeX, groff, CommonMark, and NSAttributedString from a single parse. Parsing speed inherits cmark's benchmark of rendering War and Peace in ~127ms. Suitable for projects that need CommonMark only and value multi-format output.

**Ink** ([JohnSundell/Ink](https://github.com/JohnSundell/Ink)) — **~2,500 stars**, inactive. A pure-Swift parser with zero dependencies, designed for John Sundell's Publish static site generator. The API is elegantly simple (`MarkdownParser().parse(markdown)` returns HTML plus metadata), but Ink **does not produce an AST** — it outputs HTML directly. It explicitly does not fully support the CommonMark spec and has known edge-case failures. Built-in YAML metadata parsing is a nice touch for blog-style content, but the lack of maintenance and incomplete spec compliance make it unsuitable as a foundation for a production markdown viewer.

**Swift MarkdownKit** ([objecthub/swift-markdownkit](https://github.com/objecthub/swift-markdownkit)) — **~201 stars**, moderately maintained (latest release May 2025). A pure-Swift alternative that produces a proper AST using `Block` and `TextFragment` enums. Includes both HTML and NSAttributedString generators. Table support exists via an extended parser, but strikethrough, task lists, and autolinks are absent. A reasonable choice if you need a zero-dependency pure-Swift parser and can live without full GFM.

**Maaku** and **cmark-gfm-swift** both offered Swift-friendly wrappers around cmark-gfm but are effectively abandoned, with compiler errors in modern Swift versions and fewer than 100 stars each.

---

## Rendering: three strong SwiftUI contenders and a UIKit veteran

The rendering layer transforms parsed markdown into native views. This is where the ecosystem offers the most choice — and where the biggest recent shakeup occurred.

**MarkdownUI** ([gonzalezreal/swift-markdown-ui](https://github.com/gonzalezreal/swift-markdown-ui)) — **~3,748 stars**, now in maintenance mode (December 2025 announcement). The most popular and mature SwiftUI markdown renderer, MarkdownUI bundles cmark-gfm internally and renders fully native SwiftUI views for headings, paragraphs, lists (including task lists), blockquotes, code blocks, tables, images, and thematic breaks. Its theming system is excellent: built-in presets (GitHub, DocC) plus a comprehensive DSL for custom `Theme`, `TextStyle`, and `BlockStyle` definitions. A `CodeSyntaxHighlighter` protocol enables integration with third-party highlighting libraries. Requires **iOS 15+/macOS 12+** (tables need iOS 16+). The main downsides are performance degradation on very long documents (each markdown element becomes a separate SwiftUI view) and the shift to maintenance mode. Still a safe choice for production apps today, but new features will not be added.

**Textual** ([gonzalezreal/textual](https://github.com/gonzalezreal/textual)) — **~93 stars**, actively developed (announced December 2025). Created by the same developer as MarkdownUI, Textual is its spiritual successor — a "SwiftUI-native text rendering engine that happens to support Markdown." It introduces two specialized views: `InlineText` (a drop-in `Text` replacement with attachment support) and `StructuredText` (for full block-level document rendering). Key improvements over MarkdownUI include **LaTeX/math rendering**, native **text selection** with copy-paste, font-relative measurements via `.fontScaled()`, and better performance through closer integration with SwiftUI's text rendering pipeline. Still very early — the API is evolving and documentation is limited — but architecturally superior to MarkdownUI.

**MarkdownView** ([LiYanan2004/MarkdownView](https://github.com/LiYanan2004/MarkdownView)) — **~559 stars**, **actively maintained** (333 commits, 31 releases, last activity within weeks of February 2026). The most feature-rich native SwiftUI markdown viewer currently in active development. Built on Apple's swift-markdown parser, it supports **SVG rendering**, **LaTeX/math**, **built-in code syntax highlighting** with themes, custom font groups per element type, block directive support, and custom image renderers. Adopted by **X (Grok) and Hugging Face Chat** for their iOS apps. Requires **iOS 16+/macOS 13+** (uses SwiftUI's Layout Protocol). The dependency tree is heavier (7 packages), and the community is smaller than MarkdownUI's, but it is the most actively maintained and feature-complete option available.

**Down's rendering layer** provides two UIKit paths: `DownView` (a `WKWebView` subclass with CSS-based styling for full visual control) and `toAttributedString()` with `DownStyler` for NSAttributedString output in `UITextView` or `UILabel`. The WebView approach enables rich HTML/CSS rendering but carries the weight and security considerations of embedding a web view. No native SwiftUI support.

**Markdownosaur** ([christianselig/Markdownosaur](https://github.com/christianselig/Markdownosaur)) — **~500 stars**, minimal maintenance. A brilliantly lightweight single-file (~200 lines) implementation that converts Apple swift-markdown's AST into `NSAttributedString` using the `MarkupVisitor` protocol. It is explicitly designed to be **copied into your project and customized**, not used as a dependency. Handles headings, bold, italic, strikethrough, inline code, code blocks, links, blockquotes, and lists. Ideal for UIKit projects that want full control over attributed string styling without a heavy framework. No theming system, no tables, no task lists, no syntax highlighting.

**SwiftyMarkdown** ([SimonFairbairn/SwiftyMarkdown](https://github.com/SimonFairbairn/SwiftyMarkdown)) — **~1,700 stars**, largely inactive (last tag May 2022). Outputs NSAttributedString with per-element style customization, Dynamic Type support, and YAML front matter parsing. Uses a custom regex-based parser rather than cmark, which means edge-case behavior diverges from standard specs. Good for simple UIKit rendering needs but not recommended for new projects.

**Parma** ([dasautoooo/Parma](https://github.com/dasautoooo/Parma)) — **~801 stars**, inactive. An early SwiftUI markdown renderer built on Down, offering a simple `Parma(markdownString)` API with customization via a `ParmaRenderable` protocol. Inherits Down's limitations (no GFM) and both libraries are unmaintained.

**keitaoouchi/MarkdownView** ([keitaoouchi/MarkdownView](https://github.com/keitaoouchi/MarkdownView)) — **~1,844 stars**. A WKWebView-based renderer using markdown-it (JavaScript) and highlight.js internally, providing both UIKit and SwiftUI wrappers. Offers the richest out-of-the-box rendering (full syntax highlighting, plugin system, CSS customization) at the cost of embedding a web view. Best when you want web-quality markdown rendering and don't mind the WebView overhead.

---

## Apple's native markdown: useful but limited

Apple introduced built-in markdown support in **iOS 15 / macOS 12** (2021) through the `AttributedString(markdown:)` initializer. Under the hood, it uses cmark-gfm and technically parses full GFM. However, **SwiftUI's `Text` view only renders inline elements**: bold, italic, strikethrough, inline code, and links. Block-level elements like headings, lists, tables, images, and code blocks are parsed into `PresentationIntent` attributes but receive no visual treatment in `Text`.

A critical gotcha: markdown rendering only activates with string literals (interpreted as `LocalizedStringKey`) or explicitly constructed `AttributedString`. Passing a `String` variable directly to `Text()` does not trigger markdown parsing — you must use `Text(try! AttributedString(markdown: variable))`.

**iOS 26 / macOS 26** (announced WWDC 2025) enhanced `TextEditor` with first-class `AttributedString` support, enabling rich text editing with bold, italic, links, and inline code. But block-level markdown rendering remains absent from Apple's built-in components.

Apple's native approach works well for **simple inline formatting** — chat messages, short descriptions, UI labels. For anything requiring headings, code blocks, tables, or images, a third-party library is essential.

---

## Syntax highlighting brings code blocks to life

Code blocks are a defining feature of any markdown viewer, and syntax highlighting transforms them from grey monospace boxes into readable, color-coded content.

**HighlightSwift** ([appstefan/HighlightSwift](https://github.com/appstefan/HighlightSwift)) — Actively maintained, estimated **300–500+ stars**. The best option for SwiftUI projects. Wraps highlight.js via JavaScriptCore but provides modern Swift APIs: a native `CodeText` SwiftUI view with `.highlightLanguage()` and `.codeTextColors()` modifiers, `AttributedString` output (not legacy `NSAttributedString`), async/await support, automatic language detection, and **built-in dark mode auto-switching** with paired light/dark themes. The JavaScriptCore dependency adds some overhead but enables support for **185 languages**. This is the recommended choice for pairing with MarkdownUI, MarkdownView, or Textual.

**Highlightr** ([raspu/Highlightr](https://github.com/raspu/Highlightr)) — **~1,800 stars**, original repo unmaintained but multiple active forks exist (notably **HighlighterSwift** by smittytone, which updates highlight.js to v11.9.0 and adds line numbering and visionOS support). Provides `NSAttributedString` output and a `CodeAttributedString` (`NSTextStorage` subclass) for real-time highlighting in `UITextView`. Supports **185 languages and 89 themes**. Performance is roughly 50ms for 500 lines on an iPhone 6s. Best for UIKit projects.

**Splash** ([JohnSundell/Splash](https://github.com/JohnSundell/Splash)) — **~1,800 stars**, unmaintained. A pure-Swift syntax highlighter with no JavaScript dependency, making it the fastest option — but it **only highlights Swift code**. Excellent for Swift-focused documentation tools; impractical for a general-purpose markdown viewer.

**Neon + SwiftTreeSitter** ([ChimeHQ/Neon](https://github.com/ChimeHQ/Neon), [tree-sitter/swift-tree-sitter](https://github.com/tree-sitter/swift-tree-sitter)) — **~376 stars** for Neon, actively developed. The most architecturally sophisticated option, using tree-sitter's incremental parsing for multi-phase highlighting. Supports nested languages (e.g., Swift code inside a markdown document). Ideal for editor-grade highlighting in production apps like Chime, but requires significant integration work and is overkill for a read-only markdown viewer.

---

## Recommended stacks for production markdown viewers

The right combination depends on your UI framework, feature requirements, and tolerance for dependency weight.

**For a new SwiftUI project (recommended):** Use **MarkdownView** (LiYanan2004) as your primary renderer. It bundles Apple's swift-markdown parser, provides built-in code highlighting themes, supports LaTeX math and SVG, and is the most actively maintained option. Proven in production by X and Hugging Face. Add **HighlightSwift** if you need more control over code block highlighting or additional themes.

**For maximum community support and theming:** Use **MarkdownUI** with **HighlightSwift** for code blocks. MarkdownUI's theming DSL is the most mature in the ecosystem, and despite entering maintenance mode, it remains stable and well-documented. The `CodeSyntaxHighlighter` protocol makes HighlightSwift integration straightforward.

**For forward-looking architecture:** Watch **Textual** closely. Its text-selection support, LaTeX rendering, and tighter SwiftUI integration represent the future direction from the most experienced developer in this space. Consider adopting it once it stabilizes (likely mid-2026).

**For UIKit projects:** Pair **Apple's swift-markdown** with a customized **Markdownosaur** for NSAttributedString output, then add **Highlightr** (or HighlighterSwift fork) for code block highlighting. This stack gives you full control with minimal dependencies.

**For web-quality rendering with minimal effort:** Use **keitaoouchi/MarkdownView** — its WKWebView-based approach with built-in highlight.js delivers the richest visual output with the least configuration, at the cost of native feel and performance.

## Conclusion

The Swift markdown ecosystem is mature but fragmented, with **no single library that handles parsing, rendering, and syntax highlighting perfectly**. Apple's swift-markdown has become the de facto parsing standard, but Apple's own rendering support remains limited to inline elements. The rendering layer is in transition: MarkdownUI dominated for years but is now ceding ground to MarkdownView (LiYanan2004) for active development and Textual for architectural innovation. For syntax highlighting, HighlightSwift has emerged as the modern SwiftUI-native choice, displacing the aging Highlightr. The most notable trend is the convergence toward LaTeX/math support and native text selection — features that MarkdownView and Textual both offer and that MarkdownUI lacks — reflecting the growing use of markdown viewers in AI chat interfaces where mathematical notation and copy-paste are essential.