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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let frontMatter = FrontMatterDocument.split(from: markdown) {
                    TextualFrontMatterView(yaml: frontMatter.yaml, fontSize: fontSize, theme: theme)
                    if !frontMatter.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
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
                        applyToken: scrollApplyToken
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
            .textual.highlighterTheme(
                StructuredText.HighlighterTheme(
                    foregroundColor: DynamicColor(tokens.foreground),
                    backgroundColor: DynamicColor(tokens.codeBackground)
                )
            )
            .textual.codeBlockStyle(TextualThemedCodeBlockStyle(theme: theme))
            .textual.thematicBreakStyle(TextualThemedThematicBreakStyle(theme: theme))
            .textual.tableCellStyle(TextualCompactTableCellStyle(fontSize: fontSize))
            .textual.tableStyle(TextualAlternatingTableStyle(theme: theme))
            .textual.textSelection(.enabled)
    }

    @ViewBuilder
    private func structuredText(_ text: String) -> some View {
        if showsColorSwatches {
            StructuredText(text, parser: TextualColorSwatchParser())
        } else {
            StructuredText(markdown: text)
        }
    }
}

private struct TextualColorSwatchParser: MarkupParser {
    private let markdownParser = AttributedStringMarkdownParser.markdown()

    func attributedString(for input: String) throws -> AttributedString {
        let attributedString = try markdownParser.attributedString(for: input)
        return Self.insertingSwatches(in: attributedString)
    }

    private static func insertingSwatches(in attributedString: AttributedString) -> AttributedString {
        var output = AttributedString()

        for run in attributedString.runs {
            if run.isTextualSwatchPreformatted {
                output.append(attributedString[run.range])
                continue
            }

            let text = String(attributedString[run.range].characters)
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

private struct TextualFrontMatterView: View {
    let yaml: String
    let fontSize: Double
    let theme: MarkdownTheme

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

            StructuredText(markdown: yamlCodeBlock)
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

    private var yamlCodeBlock: String {
        let fence = String(repeating: "`", count: max(3, longestBacktickRun(in: yaml) + 1))
        return "\(fence)yaml\n\(yaml)\n\(fence)"
    }

    private func longestBacktickRun(in text: String) -> Int {
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
