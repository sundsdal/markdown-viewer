import SwiftUI
import MarkdownUI

struct NativeMarkdownDocumentView: View {
    let document: MarkdownDocument
    let fontSize: Double
    let theme: MarkdownTheme
    let scrollPosition: RendererScrollPosition
    let scrollApplyToken: UUID
    let source: String
    let synchronizesScroll: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let frontMatter = frontMatterDocument {
                    YAMLFrontMatterView(yaml: frontMatter.yaml, fontSize: fontSize, theme: theme)
                    markdownView(frontMatter.body)
                } else {
                    markdownView(renderableText)
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

    private var frontMatterDocument: FrontMatterDocument? {
        guard document.fileType == .markdown else { return nil }
        return FrontMatterDocument.split(from: document.text)
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

    private func markdownView(_ text: String) -> some View {
        Markdown(text)
            .markdownTheme(MarkdownUIThemeBuilder.build(for: theme, fontSize: fontSize))
            .tint(theme.tokens.link)
            .textSelection(.enabled)
    }
}

private enum MarkdownUIThemeBuilder {
    static func build(for theme: MarkdownTheme, fontSize: Double) -> Theme {
        let tokens = theme.tokens
        return Theme()
            .text {
                ForegroundColor(tokens.foreground)
                BackgroundColor(.clear)
                FontSize(CGFloat(fontSize))
            }
            .code {
                FontFamilyVariant(.monospaced)
                FontSize(.em(0.85))
                ForegroundColor(tokens.inlineCodeForeground)
                BackgroundColor(tokens.inlineCodeBackground)
            }
            .strong { FontWeight(.semibold) }
            .link { ForegroundColor(tokens.link) }
            .heading1 { configuration in
                VStack(alignment: .leading, spacing: 0) {
                    configuration.label
                        .relativePadding(.bottom, length: .em(0.3))
                        .relativeLineSpacing(.em(0.125))
                        .markdownMargin(top: 24, bottom: 16)
                        .markdownTextStyle {
                            FontWeight(.semibold)
                            FontSize(.em(2))
                        }
                    Divider().overlay(tokens.border)
                }
            }
            .heading2 { configuration in
                VStack(alignment: .leading, spacing: 0) {
                    configuration.label
                        .relativePadding(.bottom, length: .em(0.3))
                        .relativeLineSpacing(.em(0.125))
                        .markdownMargin(top: 24, bottom: 16)
                        .markdownTextStyle {
                            FontWeight(.semibold)
                            FontSize(.em(1.5))
                        }
                    Divider().overlay(tokens.border)
                }
            }
            .heading3 { configuration in
                configuration.label
                    .relativeLineSpacing(.em(0.125))
                    .markdownMargin(top: 24, bottom: 16)
                    .markdownTextStyle {
                        FontWeight(.semibold)
                        FontSize(.em(1.25))
                    }
            }
            .heading4 { configuration in
                configuration.label
                    .relativeLineSpacing(.em(0.125))
                    .markdownMargin(top: 24, bottom: 16)
                    .markdownTextStyle { FontWeight(.semibold) }
            }
            .heading5 { configuration in
                configuration.label
                    .relativeLineSpacing(.em(0.125))
                    .markdownMargin(top: 24, bottom: 16)
                    .markdownTextStyle {
                        FontWeight(.semibold)
                        FontSize(.em(0.875))
                    }
            }
            .heading6 { configuration in
                configuration.label
                    .relativeLineSpacing(.em(0.125))
                    .markdownMargin(top: 24, bottom: 16)
                    .markdownTextStyle {
                        FontWeight(.semibold)
                        FontSize(.em(0.85))
                        ForegroundColor(tokens.tertiary)
                    }
            }
            .paragraph { configuration in
                configuration.label
                    .fixedSize(horizontal: false, vertical: true)
                    .relativeLineSpacing(.em(0.25))
                    .markdownMargin(top: 0, bottom: 16)
            }
            .blockquote { configuration in
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(tokens.border)
                        .relativeFrame(width: .em(0.2))
                    configuration.label
                        .markdownTextStyle { ForegroundColor(tokens.secondary) }
                        .relativePadding(.horizontal, length: .em(1))
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            .codeBlock { configuration in
                ScrollView(.horizontal) {
                    configuration.label
                        .fixedSize(horizontal: false, vertical: true)
                        .relativeLineSpacing(.em(0.225))
                        .markdownTextStyle {
                            FontFamilyVariant(.monospaced)
                            FontSize(.em(0.85))
                            ForegroundColor(tokens.foreground)
                        }
                        .padding(16)
                }
                .background(tokens.codeBackground)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(tokens.border, lineWidth: 1)
                )
                .markdownMargin(top: 0, bottom: 16)
            }
            .listItem { configuration in
                configuration.label.markdownMargin(top: .em(0.25))
            }
            .table { configuration in
                configuration.label
                    .fixedSize(horizontal: false, vertical: true)
                    .markdownTableBorderStyle(.init(color: tokens.border))
                    .markdownTableBackgroundStyle(
                        .alternatingRows(
                            tokens.documentBackground,
                            tokens.tableStripeBackground,
                            header: tokens.tableHeaderBackground
                        )
                    )
                    .markdownMargin(top: 0, bottom: 16)
            }
            .tableCell { configuration in
                configuration.label
                    .markdownTextStyle {
                        if configuration.row == 0 {
                            FontWeight(.semibold)
                        }
                        BackgroundColor(nil)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 13)
                    .relativeLineSpacing(.em(0.25))
            }
            .thematicBreak {
                Divider()
                    .relativeFrame(height: .em(0.25))
                    .overlay(tokens.border)
                    .markdownMargin(top: 24, bottom: 24)
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

private struct YAMLFrontMatterView: View {
    let yaml: String
    let fontSize: Double
    let theme: MarkdownTheme

    private var entries: [YAMLEntry] {
        YAMLEntry.parse(yaml)
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

            if entries.isEmpty {
                Text(yaml)
                    .foregroundStyle(theme.tokens.frontMatterText)
                    .font(.system(size: FrontMatterTypography.codeSize(for: fontSize), design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
            } else {
                Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 14, verticalSpacing: 8) {
                    ForEach(entries) { entry in
                        GridRow {
                            Text(entry.key)
                                .font(.system(size: FrontMatterTypography.valueSize(for: fontSize), weight: .medium, design: .monospaced))
                                .foregroundStyle(theme.tokens.frontMatterKey)
                                .textSelection(.enabled)
                            YAMLValueView(value: entry.value, fontSize: fontSize, theme: theme)
                        }
                    }
                }
                .padding(14)
            }

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
}

private struct YAMLValueView: View {
    let value: YAMLValue
    let fontSize: Double
    let theme: MarkdownTheme

    var body: some View {
        switch value {
        case .empty:
            Text("empty")
                .foregroundStyle(theme.tokens.tertiary)
                .font(.system(size: FrontMatterTypography.valueSize(for: fontSize), design: .monospaced))
        case .scalar(let text, let kind):
            Text(displayText(text, kind: kind))
                .foregroundStyle(color(for: kind))
                .font(.system(size: FrontMatterTypography.valueSize(for: fontSize), design: .monospaced))
                .textSelection(.enabled)
        case .list(let values):
            Text("[\(values.map(quote).joined(separator: ", "))]")
                .foregroundStyle(theme.tokens.frontMatterString)
                .font(.system(size: FrontMatterTypography.valueSize(for: fontSize), design: .monospaced))
                .textSelection(.enabled)
        case .block(let text):
            Text(text)
                .foregroundStyle(theme.tokens.frontMatterText)
                .font(.system(size: FrontMatterTypography.codeSize(for: fontSize), design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(theme.tokens.frontMatterBlockBackground)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    private func displayText(_ text: String, kind: YAMLScalarKind) -> String {
        switch kind {
        case .string:
            return quote(text)
        case .boolean:
            return text.lowercased()
        case .null:
            return text == "~" ? "null" : text.lowercased()
        case .number, .date:
            return text
        }
    }

    private func quote(_ text: String) -> String {
        let escaped = text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    private func color(for kind: YAMLScalarKind) -> Color {
        switch kind {
        case .string:
            return theme.tokens.frontMatterString
        case .number, .date:
            return theme.tokens.frontMatterNumber
        case .boolean:
            return theme.tokens.frontMatterBoolean
        case .null:
            return theme.tokens.frontMatterNull
        }
    }
}

private struct YAMLEntry: Identifiable {
    let id = UUID()
    let key: String
    let value: YAMLValue

    static func parse(_ yaml: String) -> [YAMLEntry] {
        let lines = yaml.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "\r")) }
        var entries: [YAMLEntry] = []
        var index = 0

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else {
                index += 1
                continue
            }

            guard isTopLevelKey(line), let colonIndex = firstKeyColon(in: line) else {
                return []
            }

            let rawKey = String(line[..<colonIndex]).trimmingCharacters(in: .whitespaces)
            let rawValue = String(line[line.index(after: colonIndex)...])
            let valueText = stripComment(from: rawValue).trimmingCharacters(in: .whitespaces)

            if valueText.isEmpty || valueText.hasPrefix("|") || valueText.hasPrefix(">") {
                let blockStart = index + 1
                var blockEnd = blockStart
                while blockEnd < lines.count, !isTopLevelKey(lines[blockEnd]) {
                    blockEnd += 1
                }
                let block = normalizeBlock(Array(lines[blockStart..<blockEnd]))
                entries.append(YAMLEntry(key: unquote(rawKey), value: parseBlock(block, indicator: valueText)))
                index = blockEnd
            } else {
                entries.append(YAMLEntry(key: unquote(rawKey), value: parseInline(valueText)))
                index += 1
            }
        }

        return entries
    }

    private static func parseInline(_ value: String) -> YAMLValue {
        let trimmed = stripComment(from: value).trimmingCharacters(in: .whitespaces)

        guard !trimmed.isEmpty else { return .empty }

        if trimmed == "[]" {
            return .list([])
        }

        if trimmed.hasPrefix("["), trimmed.hasSuffix("]") {
            let inner = String(trimmed.dropFirst().dropLast())
            let values = splitInlineList(inner)
                .map { unquote($0.trimmingCharacters(in: .whitespaces)) }
                .filter { !$0.isEmpty }
            return .list(values)
        }

        if trimmed.hasPrefix("{"), trimmed.hasSuffix("}") {
            return .block(trimmed)
        }

        let unquoted = unquote(trimmed)
        let normalized = trimmed.lowercased()

        if ["true", "false", "yes", "no", "on", "off"].contains(normalized) {
            return .scalar(trimmed, .boolean)
        }

        if ["null", "~"].contains(normalized) {
            return .scalar(trimmed, .null)
        }

        if isDate(unquoted) {
            return .scalar(unquoted, .date)
        }

        if isNumber(unquoted) {
            return .scalar(unquoted, .number)
        }

        return .scalar(unquoted, .string)
    }

    private static func parseBlock(_ block: String, indicator: String) -> YAMLValue {
        let trimmed = block.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .empty }

        if indicator.hasPrefix(">") {
            return .block(foldBlock(trimmed))
        }

        let nonEmptyLines = trimmed.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }

        if !nonEmptyLines.isEmpty, nonEmptyLines.allSatisfy({ $0.hasPrefix("- ") || $0 == "-" }) {
            return .list(nonEmptyLines.map { line in
                line == "-" ? "" : unquote(stripComment(from: String(line.dropFirst(2))).trimmingCharacters(in: .whitespaces))
            })
        }

        return .block(trimmed)
    }

    private static func isTopLevelKey(_ line: String) -> Bool {
        guard let first = line.first,
              !first.isWhitespace,
              first != "-",
              !line.trimmingCharacters(in: .whitespaces).hasPrefix("#") else {
            return false
        }
        return firstKeyColon(in: line) != nil
    }

    private static func firstKeyColon(in line: String) -> String.Index? {
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

    private static func stripComment(from text: String) -> String {
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

    private static func splitInlineList(_ text: String) -> [String] {
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

    private static func normalizeBlock(_ lines: [String]) -> String {
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

    private static func foldBlock(_ block: String) -> String {
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

    private static func unquote(_ value: String) -> String {
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

    private static func isDate(_ value: String) -> Bool {
        value.range(
            of: #"^\d{4}-\d{2}-\d{2}(?:[Tt ][0-9:.+-]+)?$"#,
            options: .regularExpression
        ) != nil
    }

    private static func isNumber(_ value: String) -> Bool {
        value.range(
            of: #"^[+-]?(?:\d[\d_]*(?:\.\d[\d_]*)?|\.\d[\d_]*)(?:[eE][+-]?\d[\d_]*)?$"#,
            options: .regularExpression
        ) != nil
    }
}

private enum YAMLValue {
    case empty
    case scalar(String, YAMLScalarKind)
    case list([String])
    case block(String)
}

private enum YAMLScalarKind {
    case string
    case number
    case boolean
    case null
    case date
}

#Preview {
    NativeMarkdownDocumentView(
        document: MarkdownDocument(text: """
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

        # Hello, MarkdownUI

        This is rendered with **MarkdownUI**.

        | Vector | Mitigated? |
        |--------|------------|
        | XSS | Better |
        """),
        fontSize: 16,
        theme: .system,
        scrollPosition: RendererScrollPosition(),
        scrollApplyToken: UUID(),
        source: "preview",
        synchronizesScroll: false
    )
    .frame(width: 700, height: 560)
}
