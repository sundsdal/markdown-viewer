import Foundation

enum MarkdownHTMLRenderer {

    // MARK: - Full HTML document

    static func buildFullHTML(markdown: String, fontSize: Double, theme: MarkdownTheme) -> String {
        let body = renderMarkdownDocument(markdown)
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
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

    // MARK: - Document sections

    static func renderMarkdownDocument(_ text: String) -> String {
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

    private static func splitFrontMatter(from text: String) -> (yaml: String, body: String)? {
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

    private static func renderFrontMatter(_ yaml: String) -> String {
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

    // MARK: - Markdown → HTML

    private static func markdownToHTML(_ text: String) -> String {
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

    private static func isTableSeparator(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.contains("|") && trimmed.contains("-")
            && trimmed.allSatisfy({ $0 == "|" || $0 == "-" || $0 == ":" || $0 == " " })
    }

    private static func parseTable(_ lines: [String], _ i: inout Int) -> String {
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

    private static func parseTableRow(_ line: String) -> [String] {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let stripped = trimmed.hasPrefix("|") ? String(trimmed.dropFirst()) : trimmed
        let end = stripped.hasSuffix("|") ? String(stripped.dropLast()) : stripped
        return end.components(separatedBy: "|")
    }

    // MARK: - Helpers

    private static func closeList(_ html: inout [String], _ inList: inout Bool, _ listType: inout String) {
        if inList {
            html.append("</\(listType)>")
            inList = false
            listType = ""
        }
    }

    private static func parseHeading(_ line: String) -> (Int, String)? {
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

    private static func isHorizontalRule(_ trimmed: String) -> Bool {
        trimmed.allSatisfy({ $0 == "-" || $0 == "*" || $0 == "_" || $0 == " " })
            && trimmed.filter({ $0 != " " }).count >= 3
            && Set(trimmed.filter({ $0 != " " })).count == 1
    }

    private static func inlineMarkdown(_ text: String) -> String {
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

    private static func escapeHTML(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    // MARK: - Syntax highlighting

    private static func highlightCode(_ code: String, language: String) -> String {
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

    private static func highlightYAML(_ code: String) -> String {
        var result: [String] = []
        for line in code.components(separatedBy: "\n") {
            var contentPart = line
            var commentPart = ""

            if let range = line.range(of: #"(#.*)$"#, options: .regularExpression) {
                commentPart = "<span class=\"sy-comment\">\(line[range])</span>"
                contentPart = String(line[..<range.lowerBound])
            }

            var highlighted = contentPart
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
            result.append(highlighted + commentPart)
        }
        return result.joined(separator: "\n")
    }

    private static func highlightJSON(_ code: String) -> String {
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

    private static func highlightSwift(_ code: String) -> String {
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

    private static func highlightJS(_ code: String) -> String {
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

    private static func highlightPython(_ code: String) -> String {
        let keywords = [
            "import", "from", "def", "class", "if", "elif", "else", "for", "while",
            "return", "yield", "try", "except", "finally", "raise", "with", "as",
            "pass", "break", "continue", "and", "or", "not", "in", "is", "lambda",
            "True", "False", "None", "self", "async", "await", "global", "nonlocal",
        ]
        return highlightGeneric(code, keywords: keywords, lineComment: "#")
    }

    private static func highlightShell(_ code: String) -> String {
        let keywords = [
            "if", "then", "else", "elif", "fi", "for", "while", "do", "done",
            "case", "esac", "function", "return", "exit", "export", "local",
            "echo", "cd", "ls", "rm", "cp", "mv", "mkdir", "grep", "sed", "awk",
            "cat", "curl", "wget", "git", "npm", "npx", "yarn", "pnpm",
            "true", "false",
        ]
        return highlightGeneric(code, keywords: keywords, lineComment: "#")
    }

    private static func highlightGeneric(_ code: String, keywords: [String], lineComment: String) -> String {
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
            } else if kw == "class" {
                result = result.replacingOccurrences(
                    of: "\\b(\(NSRegularExpression.escapedPattern(for: kw)))\\b(?!\\s*=)",
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
