import SwiftUI
import Textual

struct TextualMarkdownView: View {
    let markdown: String
    let fontSize: Double
    let showsColorSwatches: Bool
    let theme: MarkdownTheme
    let scrollPosition: RendererScrollPosition
    let scrollApplyToken: UUID
    let source: String
    let synchronizesScroll: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let frontMatter = FrontMatterDocument.split(from: markdown) {
                    TextualFrontMatterView(yaml: frontMatter.yaml, fontSize: fontSize, theme: theme)
                    if frontMatter.body.containsNonWhitespace {
                        textualMarkdown(frontMatter.body)
                    }
                } else {
                    textualMarkdown(markdown)
                }
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(.horizontal, 40)
            .padding(.vertical, 34)
            .background(
                NativeScrollPositionObserver(
                    source: source,
                    scrollPosition: scrollPosition,
                    applyToken: scrollApplyToken,
                    broadcastsScrollUpdates: synchronizesScroll
                )
            )
        }
        .background(theme.tokens.documentBackground)
        .modifier(ThemeColorSchemeModifier(theme: theme))
    }

    private func textualMarkdown(_ text: String) -> some View {
        let tokens = theme.tokens
        return structuredText(text)
            .font(.system(size: fontSize))
            .foregroundStyle(tokens.foreground)
            .textual.inlineStyle(
                InlineStyle()
                    .code(
                        .monospaced,
                        .fontScale(0.94),
                        .foregroundColor(DynamicColor(tokens.inlineCodeForeground)),
                        .backgroundColor(DynamicColor(tokens.inlineCodeBackground))
                    )
                    .strong(.fontWeight(.semibold))
                    .emphasis(.italic)
                    .strikethrough(.strikethroughStyle(.single))
                    .link(.foregroundColor(DynamicColor(tokens.link)))
            )
            .textual.blockQuoteStyle(
                StructuredText.DefaultBlockQuoteStyle(
                    backgroundColor: DynamicColor(tokens.codeBackground),
                    borderColor: DynamicColor(tokens.border)
                )
            )
            .textual.highlighterTheme(TextualThemedHighlighterTheme.make(from: tokens))
            .textual.codeBlockStyle(TextualThemedCodeBlockStyle(theme: theme))
            .textual.thematicBreakStyle(TextualThemedThematicBreakStyle(theme: theme))
            .textual.tableCellStyle(TextualCompactTableCellStyle(fontSize: fontSize))
            .textual.tableStyle(TextualAlternatingTableStyle(theme: theme))
            .textual.textSelection(.enabled)
    }

    @ViewBuilder
    private func structuredText(_ text: String) -> some View {
        if showsColorSwatches {
            StructuredText(text, parser: TextualCachingMarkdownParser(mode: .colorSwatches))
        } else {
            StructuredText(text, parser: TextualCachingMarkdownParser(mode: .markdown))
        }
    }
}

private struct TextualCachingMarkdownParser: MarkupParser {
    enum Mode: Hashable {
        case markdown
        case colorSwatches
    }

    let mode: Mode

    func attributedString(for input: String) throws -> AttributedString {
        try TextualAttributedStringCache.shared.attributedString(for: input, mode: mode) {
            let attributedString = TextualCodeBlockLanguageHints.limitingExpensiveHighlightHints(
                in: try AttributedStringMarkdownParser.markdown().attributedString(for: input)
            )
            switch mode {
            case .markdown:
                return attributedString
            case .colorSwatches:
                return TextualColorSwatchParser.insertingSwatches(in: attributedString, source: input)
            }
        }
    }
}

private enum TextualCodeBlockLanguageHints {
    private static let maxHighlightedCodeBlockCharacters = 12_000

    static func limitingExpensiveHighlightHints(in attributedString: AttributedString) -> AttributedString {
        var output = attributedString
        let replacements: [(Range<AttributedString.Index>, PresentationIntent)] = attributedString.runs.compactMap { run in
            guard attributedString[run.range].characters.count > maxHighlightedCodeBlockCharacters else {
                return nil
            }
            guard let intent = run.presentationIntent,
                  let replacement = intent.removingExpensiveCodeBlockLanguageHints else {
                return nil
            }
            return (run.range, replacement)
        }

        for (range, replacement) in replacements {
            output[range].presentationIntent = replacement
        }

        return output
    }
}

private extension PresentationIntent {
    var removingExpensiveCodeBlockLanguageHints: PresentationIntent? {
        var rebuilt: PresentationIntent?
        var changed = false

        for component in components.reversed() {
            let kind: PresentationIntent.Kind
            switch component.kind {
            case .codeBlock(let languageHint) where languageHint?.lowercased() != "math":
                kind = .codeBlock(languageHint: nil)
                changed = changed || languageHint != nil
            default:
                kind = component.kind
            }
            rebuilt = PresentationIntent(kind, identity: component.identity, parent: rebuilt)
        }

        return changed ? rebuilt : nil
    }
}

@MainActor
private final class TextualAttributedStringCache {
    static let shared = TextualAttributedStringCache()

    private struct Key: Hashable {
        let input: String
        let mode: TextualCachingMarkdownParser.Mode
    }

    private let limit = 12
    private var values: [Key: AttributedString] = [:]
    private var recentKeys: [Key] = []

    func attributedString(
        for input: String,
        mode: TextualCachingMarkdownParser.Mode,
        build: () throws -> AttributedString
    ) throws -> AttributedString {
        let key = Key(input: input, mode: mode)
        if let cached = values[key] {
            markRecentlyUsed(key)
            return cached
        }

        let attributedString = try build()
        values[key] = attributedString
        markRecentlyUsed(key)
        trimIfNeeded()
        return attributedString
    }

    private func markRecentlyUsed(_ key: Key) {
        recentKeys.removeAll { $0 == key }
        recentKeys.append(key)
    }

    private func trimIfNeeded() {
        while recentKeys.count > limit, let key = recentKeys.first {
            recentKeys.removeFirst()
            values.removeValue(forKey: key)
        }
    }
}

private enum TextualColorSwatchParser {
    static func insertingSwatches(in attributedString: AttributedString, source: String) -> AttributedString {
        guard source.contains("#") else {
            return attributedString
        }

        var output = AttributedString()

        for run in attributedString.runs {
            if run.isTextualSwatchPreformatted {
                output.append(attributedString[run.range])
                continue
            }

            let text = String(attributedString[run.range].characters)
            guard text.contains("#") else {
                output.append(attributedString[run.range])
                continue
            }

            let matches = HexColorLiteral.matches(in: text)

            guard !matches.isEmpty else {
                output.append(attributedString[run.range])
                continue
            }

            var cursor = text.startIndex
            for match in matches {
                if cursor < match.range.lowerBound {
                    output.append(AttributedString(String(text[cursor..<match.range.lowerBound]), attributes: run.attributes))
                }

                let attachment = ColorSwatchAttachment(color: match.color)
                output.append(AttributedString("\u{FFFC}", attributes: run.attributes.attachment(.init(attachment))))
                output.append(AttributedString(String(text[match.range]), attributes: run.attributes))
                cursor = match.range.upperBound
            }

            if cursor < text.endIndex {
                output.append(AttributedString(String(text[cursor..<text.endIndex]), attributes: run.attributes))
            }
        }

        return output
    }
}

private struct HexColorLiteral {
    let range: Range<String.Index>
    let color: SwatchColor

    static func matches(in text: String) -> [HexColorLiteral] {
        var matches: [HexColorLiteral] = []
        var index = text.startIndex

        while index < text.endIndex {
            defer { index = text.index(after: index) }

            guard text[index] == "#", isColorBoundaryBefore(index, in: text) else {
                continue
            }

            var end = text.index(after: index)
            var digitCount = 0
            while end < text.endIndex, isHexDigit(text[end]) {
                digitCount += 1
                end = text.index(after: end)
            }

            guard [3, 6, 8].contains(digitCount), isColorBoundaryAfter(end, in: text) else {
                continue
            }

            let literalRange = index..<end
            guard let color = SwatchColor(hexLiteral: String(text[literalRange])) else {
                continue
            }

            matches.append(HexColorLiteral(range: literalRange, color: color))
            index = text.index(before: end)
        }

        return matches
    }

    private static func isColorBoundaryBefore(_ index: String.Index, in text: String) -> Bool {
        guard index > text.startIndex else {
            return true
        }

        return !isIdentifierCharacter(text[text.index(before: index)])
    }

    private static func isColorBoundaryAfter(_ index: String.Index, in text: String) -> Bool {
        guard index < text.endIndex else {
            return true
        }

        return !isHexDigit(text[index])
    }

    private static func isIdentifierCharacter(_ character: Character) -> Bool {
        character == "#" || character == "_" || character.isLetter || character.isNumber
    }

    private static func isHexDigit(_ character: Character) -> Bool {
        guard character.unicodeScalars.count == 1, let scalar = character.unicodeScalars.first else {
            return false
        }

        switch scalar.value {
        case 48...57, 65...70, 97...102:
            return true
        default:
            return false
        }
    }
}

private struct SwatchColor: Hashable, Sendable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double

    init?(hexLiteral: String) {
        let digits = String(hexLiteral.dropFirst())
        let expanded: String

        if digits.count == 3 {
            expanded = digits.map { "\($0)\($0)" }.joined()
        } else {
            expanded = digits
        }

        guard let value = UInt64(expanded, radix: 16) else {
            return nil
        }

        switch expanded.count {
        case 6:
            red = Double((value >> 16) & 0xff) / 255
            green = Double((value >> 8) & 0xff) / 255
            blue = Double(value & 0xff) / 255
            alpha = 1
        case 8:
            red = Double((value >> 24) & 0xff) / 255
            green = Double((value >> 16) & 0xff) / 255
            blue = Double((value >> 8) & 0xff) / 255
            alpha = Double(value & 0xff) / 255
        default:
            return nil
        }
    }
}

private struct ColorSwatchAttachment: Attachment {
    let color: SwatchColor

    var description: String {
        ""
    }

    var selectionStyle: AttachmentSelectionStyle {
        .text
    }

    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(red: color.red, green: color.green, blue: color.blue, opacity: color.alpha))
                .overlay {
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(.separator, lineWidth: 1)
                }
                .frame(width: 12, height: 12)
            Spacer(minLength: 3)
        }
        .frame(width: 15, height: 12)
    }

    func baselineOffset(in environment: TextEnvironmentValues) -> CGFloat {
        -1
    }

    func sizeThatFits(_ proposal: ProposedViewSize, in environment: TextEnvironmentValues) -> CGSize {
        CGSize(width: 15, height: 12)
    }
}

private extension AttributedString.Runs.Run {
    var isTextualSwatchPreformatted: Bool {
        if self.inlinePresentationIntent?.isTextualSwatchPreformatted ?? false {
            return true
        }

        if self.presentationIntent?.isTextualSwatchPreformatted ?? false {
            return true
        }

        return false
    }
}

private extension InlinePresentationIntent {
    var isTextualSwatchPreformatted: Bool {
        contains(.code) || contains(.inlineHTML) || contains(.blockHTML)
    }
}

private extension PresentationIntent {
    var isTextualSwatchPreformatted: Bool {
        components.first?.kind.isTextualSwatchPreformatted ?? false
    }
}

private extension PresentationIntent.Kind {
    var isTextualSwatchPreformatted: Bool {
        switch self {
        case .codeBlock:
            return true
        default:
            return false
        }
    }
}

private enum TextualThemedHighlighterTheme {
    static func make(from tokens: MarkdownThemeTokens) -> StructuredText.HighlighterTheme {
        let keyword = AnyTextProperty(
            .foregroundColor(DynamicColor(tokens.syntaxKeyword)),
            .fontWeight(.semibold)
        )
        let literal = AnyTextProperty(
            .foregroundColor(DynamicColor(tokens.syntaxBoolean)),
            .fontWeight(.semibold)
        )
        let string = AnyTextProperty(.foregroundColor(DynamicColor(tokens.syntaxString)))
        let number = AnyTextProperty(.foregroundColor(DynamicColor(tokens.syntaxNumber)))
        let comment = AnyTextProperty(.foregroundColor(DynamicColor(tokens.syntaxComment)))
        let property = AnyTextProperty(.foregroundColor(DynamicColor(tokens.syntaxKey)))
        let punctuation = AnyTextProperty(.foregroundColor(DynamicColor(tokens.syntaxPunctuation)))

        return StructuredText.HighlighterTheme(
            foregroundColor: DynamicColor(tokens.foreground),
            backgroundColor: DynamicColor(tokens.codeBackground),
            tokenProperties: [
                .keyword: keyword,
                .builtin: keyword,
                .literal: literal,
                .boolean: literal,
                .nil: literal,
                .string: string,
                .char: string,
                .regex: string,
                .url: AnyTextProperty(.foregroundColor(DynamicColor(tokens.link))),
                .number: number,
                .symbol: number,
                .comment: comment,
                .blockComment: comment,
                .docComment: comment,
                .property: property,
                .attributeName: property,
                .className: property,
                .variable: AnyTextProperty(.foregroundColor(DynamicColor(tokens.foreground))),
                .constant: AnyTextProperty(.foregroundColor(DynamicColor(tokens.foreground))),
                .function: AnyTextProperty(.foregroundColor(DynamicColor(tokens.foreground))),
                .functionName: AnyTextProperty(.foregroundColor(DynamicColor(tokens.foreground))),
                .punctuation: punctuation,
                .operator: punctuation,
                .tag: keyword,
                .preprocessor: keyword,
                .directive: keyword,
                .attribute: property,
            ]
        )
    }
}

private struct TextualThemedCodeBlockStyle: StructuredText.CodeBlockStyle {
    let theme: MarkdownTheme

    func makeBody(configuration: Configuration) -> some View {
        let tokens = theme.tokens
        return configuration.label
            .textual.lineSpacing(.fontScaled(0.39))
            .textual.fontScale(0.882)
            .fixedSize(horizontal: false, vertical: true)
            .monospaced()
            .foregroundStyle(tokens.foreground)
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tokens.codeBackground)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(tokens.border, lineWidth: 1)
            )
            .textual.blockSpacing(.fontScaled(top: 0.88, bottom: 0))
    }
}

private struct TextualThemedThematicBreakStyle: StructuredText.ThematicBreakStyle {
    let theme: MarkdownTheme

    func makeBody(configuration _: Configuration) -> some View {
        Rectangle()
            .fill(theme.tokens.border)
            .frame(height: 1)
            .frame(maxWidth: .infinity)
            .textual.blockSpacing(.fontScaled(top: 1.6, bottom: 1.6))
    }
}

private struct TextualCompactTableCellStyle: StructuredText.TableCellStyle {
    let fontSize: Double

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: tableFontSize, weight: configuration.row == 0 ? .semibold : .regular))
            .textual.lineSpacing(.fontScaled(0.08))
            .padding(.vertical, configuration.row == 0 ? 5 : 4)
            .padding(.horizontal, 10)
    }

    private var tableFontSize: CGFloat {
        max(13, CGFloat(fontSize) * 0.88)
    }
}

private struct TextualAlternatingTableStyle: StructuredText.TableStyle {
    private static let borderWidth: CGFloat = 1
    let theme: MarkdownTheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .textual.tableCellSpacing(horizontal: Self.borderWidth, vertical: Self.borderWidth)
            .textual.blockSpacing(.init(top: 0, bottom: 16))
            .textual.tableBackground { layout in
                Canvas { context, _ in
                    for row in layout.rowIndices where row > 0 && row.isMultiple(of: 2) {
                        let bounds = layout.rowBounds(row)
                        guard !bounds.isNull else { continue }
                        context.fill(
                            Path(bounds.integral),
                            with: .color(theme.tokens.tableStripeBackground)
                        )
                    }
                }
            }
            .textual.tableOverlay { layout in
                Canvas { context, _ in
                    for divider in layout.dividers() {
                        context.fill(
                            Path(divider),
                            with: .color(theme.tokens.border)
                        )
                    }
                }
            }
            .padding(Self.borderWidth)
            .overlay {
                Rectangle()
                    .stroke(theme.tokens.border, lineWidth: Self.borderWidth)
            }
    }
}

private struct FrontMatterDocument {
    let yaml: String
    let body: String

    static func split(from text: String) -> FrontMatterDocument? {
        var firstLineStart = text.startIndex
        if text[firstLineStart...].first == "\u{feff}" {
            firstLineStart = text.index(after: firstLineStart)
        }

        let firstLineEnd = text[firstLineStart...].firstIndex(of: "\n") ?? text.endIndex
        guard text[firstLineStart..<firstLineEnd].trimmingCharacters(in: .whitespacesAndNewlines) == "---",
              firstLineEnd < text.endIndex else {
            return nil
        }

        let yamlStart = text.index(after: firstLineEnd)
        var lineStart = yamlStart

        while lineStart < text.endIndex {
            let lineEnd = text[lineStart...].firstIndex(of: "\n") ?? text.endIndex
            let trimmed = text[lineStart..<lineEnd].trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed == "---" || trimmed == "..." {
                let bodyStart = lineEnd < text.endIndex ? text.index(after: lineEnd) : text.endIndex
                var yaml = String(text[yamlStart..<lineStart])
                if yaml.hasSuffix("\n") {
                    yaml.removeLast()
                }
                if yaml.hasSuffix("\r") {
                    yaml.removeLast()
                }
                let body = String(text[bodyStart..<text.endIndex])
                return FrontMatterDocument(yaml: yaml, body: body)
            }

            guard lineEnd < text.endIndex else {
                break
            }
            lineStart = text.index(after: lineEnd)
        }

        return nil
    }
}

private struct TextualFrontMatterView: View {
    let yaml: String
    let fontSize: Double
    let theme: MarkdownTheme
    private let yamlCodeBlock: String

    init(yaml: String, fontSize: Double, theme: MarkdownTheme) {
        self.yaml = yaml
        self.fontSize = fontSize
        self.theme = theme
        self.yamlCodeBlock = Self.yamlCodeBlock(for: yaml)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("frontmatter")
                    .font(.system(size: FrontMatterTypography.titleSize(for: fontSize), weight: .semibold, design: .monospaced))
                    .foregroundStyle(theme.tokens.secondary)
                Spacer()
                Text("---")
                    .font(.system(size: FrontMatterTypography.delimiterSize(for: fontSize), design: .monospaced))
                    .foregroundStyle(theme.tokens.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(theme.tokens.frontMatterHeaderBackground)

            StructuredText(yamlCodeBlock, parser: TextualCachingMarkdownParser(mode: .markdown))
                .font(.system(size: FrontMatterTypography.codeSize(for: fontSize), design: .monospaced))
                .foregroundStyle(theme.tokens.frontMatterText)
                .textual.codeBlockStyle(TextualFrontMatterCodeBlockStyle(fontSize: fontSize, theme: theme))
                .textual.textSelection(.enabled)

            Text("---")
                .font(.system(size: FrontMatterTypography.valueSize(for: fontSize), design: .monospaced))
                .foregroundStyle(theme.tokens.tertiary)
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
        }
        .background(theme.tokens.frontMatterBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(theme.tokens.border, lineWidth: 1)
        }
    }

    private static func yamlCodeBlock(for yaml: String) -> String {
        let fence = String(repeating: "`", count: max(3, longestBacktickRun(in: yaml) + 1))
        return "\(fence)yaml\n\(yaml)\n\(fence)"
    }

    private static func longestBacktickRun(in text: String) -> Int {
        var longest = 0
        var current = 0

        for character in text {
            if character == "`" {
                current += 1
                longest = max(longest, current)
            } else {
                current = 0
            }
        }

        return longest
    }
}

private struct TextualFrontMatterCodeBlockStyle: StructuredText.CodeBlockStyle {
    let fontSize: Double
    let theme: MarkdownTheme

    func makeBody(configuration: Configuration) -> some View {
        let tokens = theme.tokens
        return configuration.label
            .font(.system(size: FrontMatterTypography.codeSize(for: fontSize), design: .monospaced))
            .foregroundStyle(tokens.frontMatterText)
            .textual.lineSpacing(.fontScaled(0.12))
            .monospaced()
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(tokens.frontMatterBlockBackground)
    }
}

private extension String {
    var containsNonWhitespace: Bool {
        contains { !$0.isWhitespace }
    }
}
