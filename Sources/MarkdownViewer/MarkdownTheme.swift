import Foundation
import SwiftUI

enum MarkdownTheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark
    case sepia
    case highContrast

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        case .sepia: "Sepia"
        case .highContrast: "High Contrast"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            nil
        case .light, .sepia:
            .light
        case .dark, .highContrast:
            .dark
        }
    }

    var tokens: MarkdownThemeTokens { Self.cache[self].tokens }
    var cssVariableRule: String { Self.cache[self].cssVariableRule }
    var escapedCSSVariableRuleForJavaScript: String { Self.cache[self].escapedCSSRule }

    private static let cache = ThemeCache()

    private final class ThemeCache {
        private let entries: [MarkdownTheme: Entry]

        init() {
            var dict: [MarkdownTheme: Entry] = [:]
            for theme in MarkdownTheme.allCases {
                let description = MarkdownThemeDescription.decode(theme.jsonDescription)
                let tokens = MarkdownThemeTokens(
                    description: description,
                    usesSystemNativeColors: theme == .system
                )
                let cssRule = """
                :root {
                  color-scheme: \(description.colorScheme);
                \(description.cssVariables)
                }
                """
                let escaped = cssRule
                    .replacingOccurrences(of: "\\", with: "\\\\")
                    .replacingOccurrences(of: "'", with: "\\'")
                    .replacingOccurrences(of: "\n", with: "\\n")
                dict[theme] = Entry(
                    tokens: tokens,
                    cssVariableRule: cssRule,
                    escapedCSSRule: escaped
                )
            }
            self.entries = dict
        }

        subscript(theme: MarkdownTheme) -> Entry { entries[theme]! }
    }

    private struct Entry {
        let tokens: MarkdownThemeTokens
        let cssVariableRule: String
        let escapedCSSRule: String
    }

    fileprivate var jsonDescription: String {
        switch self {
        case .system:
            """
            {
              "colorScheme": "light dark",
              "content": {
                "background": "light-dark(#ffffff, #1c1c1e)",
                "foreground": "light-dark(#1d1d1f, #e8e8ea)",
                "secondary": "light-dark(#666666, #aaaaaa)",
                "tertiary": "light-dark(#94a3b8, #687080)",
                "link": "light-dark(#0066cc, #6cb4ee)",
                "border": "light-dark(#dddddd, #444444)",
                "inlineCodeBackground": "light-dark(#f5f5f7, #2a2a2e)",
                "inlineCodeForeground": "light-dark(#c7254e, #f0c674)",
                "codeBackground": "light-dark(#f0f0f3, #1e1e22)",
                "tableHeaderBackground": "light-dark(#f5f5f7, #2a2a2e)",
                "tableStripeBackground": "light-dark(#fafafa, #232326)"
              },
              "frontmatter": {
                "border": "light-dark(#d7dce3, #343a46)",
                "gutter": "light-dark(#eef2f7, #171b22)",
                "background": "light-dark(#f8fafc, #12151b)",
                "headerBackground": "light-dark(#f1f5f9, #191e27)",
                "title": "light-dark(#475569, #a6adbb)",
                "delimiter": "light-dark(#94a3b8, #687080)",
                "text": "light-dark(#334155, #d8dee9)",
                "key": "light-dark(#0f5f8c, #8ccdf2)",
                "string": "light-dark(#0f766e, #ce9178)",
                "number": "light-dark(#0369a1, #b5cea8)",
                "boolean": "light-dark(#2563eb, #569cd6)",
                "null": "light-dark(#9333ea, #c586c0)",
                "punctuation": "light-dark(#64748b, #7b8494)",
                "blockBackground": "light-dark(#ffffff, #0f1218)",
                "blockBorder": "light-dark(#dfe4eb, #303744)",
                "shadow": "light-dark(#ffffff, #242a35)"
              },
              "syntax": {
                "comment": "light-dark(#6a737d, #6a9955)",
                "key": "light-dark(#0f5f8c, #8ccdf2)",
                "string": "light-dark(#032f62, #ce9178)",
                "number": "light-dark(#005cc5, #b5cea8)",
                "keyword": "light-dark(#d73a49, #c586c0)",
                "boolean": "light-dark(#005cc5, #569cd6)",
                "punctuation": "light-dark(#6a737d, #808080)"
              }
            }
            """
        case .light:
            fixedThemeJSON(
                colorScheme: "light",
                content: [
                    "background": "#ffffff", "foreground": "#1d1d1f", "secondary": "#666666", "tertiary": "#94a3b8",
                    "link": "#0066cc", "border": "#dddddd", "inlineCodeBackground": "#f5f5f7", "inlineCodeForeground": "#c7254e",
                    "codeBackground": "#f0f0f3", "tableHeaderBackground": "#f5f5f7", "tableStripeBackground": "#fafafa"
                ],
                frontmatter: [
                    "border": "#d7dce3", "gutter": "#eef2f7", "background": "#f8fafc", "headerBackground": "#f1f5f9",
                    "title": "#475569", "delimiter": "#94a3b8", "text": "#334155", "key": "#0f5f8c", "string": "#0f766e",
                    "number": "#0369a1", "boolean": "#2563eb", "null": "#9333ea", "punctuation": "#64748b",
                    "blockBackground": "#ffffff", "blockBorder": "#dfe4eb", "shadow": "#ffffff"
                ],
                syntax: [
                    "comment": "#6a737d", "key": "#cf222e", "string": "#1a7f37", "number": "#bc4c00",
                    "keyword": "#8250df", "boolean": "#bc4c00", "punctuation": "#57606a"
                ]
            )
        case .dark:
            fixedThemeJSON(
                colorScheme: "dark",
                content: [
                    "background": "#1c1c1e", "foreground": "#e8e8ea", "secondary": "#aaaaaa", "tertiary": "#687080",
                    "link": "#6cb4ee", "border": "#444444", "inlineCodeBackground": "#2a2a2e", "inlineCodeForeground": "#f0c674",
                    "codeBackground": "#1e1e22", "tableHeaderBackground": "#2a2a2e", "tableStripeBackground": "#232326"
                ],
                frontmatter: [
                    "border": "#343a46", "gutter": "#171b22", "background": "#12151b", "headerBackground": "#191e27",
                    "title": "#a6adbb", "delimiter": "#687080", "text": "#d8dee9", "key": "#8ccdf2", "string": "#ce9178",
                    "number": "#b5cea8", "boolean": "#569cd6", "null": "#c586c0", "punctuation": "#7b8494",
                    "blockBackground": "#0f1218", "blockBorder": "#303744", "shadow": "#242a35"
                ],
                syntax: [
                    "comment": "#7eaa6a", "key": "#9cdcfe", "string": "#ce9178", "number": "#b5cea8",
                    "keyword": "#c586c0", "boolean": "#569cd6", "punctuation": "#c8c8c8"
                ]
            )
        case .sepia:
            fixedThemeJSON(
                colorScheme: "light",
                content: [
                    "background": "#fbf4e6", "foreground": "#2f261d", "secondary": "#6f5e4c", "tertiary": "#9b8a75",
                    "link": "#8a4f12", "border": "#d9c9b3", "inlineCodeBackground": "#efe2cc", "inlineCodeForeground": "#8b2f3c",
                    "codeBackground": "#f1e4cf", "tableHeaderBackground": "#efe2cc", "tableStripeBackground": "#f6ecd9"
                ],
                frontmatter: [
                    "border": "#d5c0a3", "gutter": "#ead8bc", "background": "#f7ebd7", "headerBackground": "#efe0c6",
                    "title": "#745f48", "delimiter": "#a18a70", "text": "#443524", "key": "#7f4a18", "string": "#517447",
                    "number": "#25626d", "boolean": "#5a5f9e", "null": "#8a4d83", "punctuation": "#8d7a62",
                    "blockBackground": "#fff8ed", "blockBorder": "#d8c5aa", "shadow": "#fffaf2"
                ],
                syntax: [
                    "comment": "#8b806f", "key": "#7f4a18", "string": "#517447", "number": "#b06825",
                    "keyword": "#9a3f52", "boolean": "#b06825", "punctuation": "#8d7a62"
                ]
            )
        case .highContrast:
            fixedThemeJSON(
                colorScheme: "dark",
                content: [
                    "background": "#000000", "foreground": "#ffffff", "secondary": "#d7d7d7", "tertiary": "#b8b8b8",
                    "link": "#66d9ff", "border": "#ffffff", "inlineCodeBackground": "#141414", "inlineCodeForeground": "#fff176",
                    "codeBackground": "#0a0a0a", "tableHeaderBackground": "#171717", "tableStripeBackground": "#101010"
                ],
                frontmatter: [
                    "border": "#ffffff", "gutter": "#0f0f0f", "background": "#050505", "headerBackground": "#151515",
                    "title": "#ffffff", "delimiter": "#d7d7d7", "text": "#ffffff", "key": "#66d9ff", "string": "#a6ff8f",
                    "number": "#fff176", "boolean": "#a8c7ff", "null": "#ff9df2", "punctuation": "#d7d7d7",
                    "blockBackground": "#000000", "blockBorder": "#ffffff", "shadow": "#333333"
                ],
                syntax: [
                    "comment": "#c7c7c7", "key": "#66d9ff", "string": "#a6ff8f", "number": "#fff176",
                    "keyword": "#ff9df2", "boolean": "#a8c7ff", "punctuation": "#ffffff"
                ]
            )
        }
    }

    private func fixedThemeJSON(colorScheme: String, content: [String: String], frontmatter: [String: String], syntax: [String: String]) -> String {
        """
        {
          "colorScheme": "\(colorScheme)",
          "content": {
            "background": "\(content["background"] ?? "#ffffff")",
            "foreground": "\(content["foreground"] ?? "#1d1d1f")",
            "secondary": "\(content["secondary"] ?? "#666666")",
            "tertiary": "\(content["tertiary"] ?? "#94a3b8")",
            "link": "\(content["link"] ?? "#0066cc")",
            "border": "\(content["border"] ?? "#dddddd")",
            "inlineCodeBackground": "\(content["inlineCodeBackground"] ?? "#f5f5f7")",
            "inlineCodeForeground": "\(content["inlineCodeForeground"] ?? "#c7254e")",
            "codeBackground": "\(content["codeBackground"] ?? "#f0f0f3")",
            "tableHeaderBackground": "\(content["tableHeaderBackground"] ?? "#f5f5f7")",
            "tableStripeBackground": "\(content["tableStripeBackground"] ?? "#fafafa")"
          },
          "frontmatter": {
            "border": "\(frontmatter["border"] ?? "#d7dce3")",
            "gutter": "\(frontmatter["gutter"] ?? "#eef2f7")",
            "background": "\(frontmatter["background"] ?? "#f8fafc")",
            "headerBackground": "\(frontmatter["headerBackground"] ?? "#f1f5f9")",
            "title": "\(frontmatter["title"] ?? "#475569")",
            "delimiter": "\(frontmatter["delimiter"] ?? "#94a3b8")",
            "text": "\(frontmatter["text"] ?? "#334155")",
            "key": "\(frontmatter["key"] ?? "#0f5f8c")",
            "string": "\(frontmatter["string"] ?? "#0f766e")",
            "number": "\(frontmatter["number"] ?? "#0369a1")",
            "boolean": "\(frontmatter["boolean"] ?? "#2563eb")",
            "null": "\(frontmatter["null"] ?? "#9333ea")",
            "punctuation": "\(frontmatter["punctuation"] ?? "#64748b")",
            "blockBackground": "\(frontmatter["blockBackground"] ?? "#ffffff")",
            "blockBorder": "\(frontmatter["blockBorder"] ?? "#dfe4eb")",
            "shadow": "\(frontmatter["shadow"] ?? "#ffffff")"
          },
          "syntax": {
            "comment": "\(syntax["comment"] ?? "#6a737d")",
            "key": "\(syntax["key"] ?? "#0f5f8c")",
            "string": "\(syntax["string"] ?? "#032f62")",
            "number": "\(syntax["number"] ?? "#005cc5")",
            "keyword": "\(syntax["keyword"] ?? "#d73a49")",
            "boolean": "\(syntax["boolean"] ?? "#005cc5")",
            "punctuation": "\(syntax["punctuation"] ?? "#6a737d")"
          }
        }
        """
    }
}

struct ThemeColorSchemeModifier: ViewModifier {
    let theme: MarkdownTheme

    @ViewBuilder
    func body(content: Content) -> some View {
        if let colorScheme = theme.colorScheme {
            content.environment(\.colorScheme, colorScheme)
        } else {
            content
        }
    }
}

struct MarkdownThemeTokens {
    let documentBackground: Color
    let foreground: Color
    let secondary: Color
    let tertiary: Color
    let link: Color
    let border: Color
    let inlineCodeBackground: Color
    let inlineCodeForeground: Color
    let codeBackground: Color
    let tableHeaderBackground: Color
    let tableStripeBackground: Color
    let frontMatterBackground: Color
    let frontMatterHeaderBackground: Color
    let frontMatterGutter: Color
    let frontMatterText: Color
    let frontMatterKey: Color
    let frontMatterString: Color
    let frontMatterNumber: Color
    let frontMatterBoolean: Color
    let frontMatterNull: Color
    let frontMatterPunctuation: Color
    let frontMatterBlockBackground: Color
    let syntaxComment: Color
    let syntaxKeyword: Color
    let syntaxString: Color
    let syntaxNumber: Color
    let syntaxBoolean: Color
    let syntaxPunctuation: Color
    let syntaxKey: Color

    let cssVariables: String

    fileprivate init(description: MarkdownThemeDescription, usesSystemNativeColors: Bool) {
        let content = description.content
        let frontmatter = description.frontmatter
        let syntax = description.syntax

        if usesSystemNativeColors {
            documentBackground = Color(nsColor: .textBackgroundColor)
            foreground = Color(nsColor: .textColor)
            secondary = Color(nsColor: .secondaryLabelColor)
            tertiary = Color(nsColor: .tertiaryLabelColor)
            link = Color(nsColor: .linkColor)
            border = Color(nsColor: .separatorColor)
            inlineCodeBackground = Color(nsColor: .controlBackgroundColor)
            inlineCodeForeground = Color(red: 0.78, green: 0.22, blue: 0.36)
            codeBackground = Color(nsColor: .controlBackgroundColor)
            tableHeaderBackground = Color(nsColor: .controlBackgroundColor)
            tableStripeBackground = Color(nsColor: .textColor).opacity(0.035)
            frontMatterBackground = Color(nsColor: .textBackgroundColor)
            frontMatterHeaderBackground = Color(nsColor: .controlBackgroundColor)
            frontMatterGutter = Color(nsColor: .controlBackgroundColor)
            frontMatterText = Color(nsColor: .textColor)
            frontMatterKey = Color(red: 0.06, green: 0.37, blue: 0.55)
            frontMatterString = Color(red: 0.05, green: 0.46, blue: 0.43)
            frontMatterNumber = Color(red: 0.01, green: 0.41, blue: 0.63)
            frontMatterBoolean = Color(red: 0.15, green: 0.39, blue: 0.92)
            frontMatterNull = Color(red: 0.58, green: 0.20, blue: 0.92)
            frontMatterPunctuation = Color(nsColor: .secondaryLabelColor)
            frontMatterBlockBackground = Color(nsColor: .textBackgroundColor)
            syntaxComment = Color(red: 0.42, green: 0.45, blue: 0.49)
            syntaxKeyword = Color(red: 0.51, green: 0.31, blue: 0.87)
            syntaxString = Color(red: 0.10, green: 0.50, blue: 0.21)
            syntaxNumber = Color(red: 0.74, green: 0.30, blue: 0.00)
            syntaxBoolean = Color(red: 0.74, green: 0.30, blue: 0.00)
            syntaxPunctuation = Color(nsColor: .secondaryLabelColor)
            syntaxKey = Color(red: 0.81, green: 0.13, blue: 0.18)
        } else {
            documentBackground = Color(cssColor: content.background)
            foreground = Color(cssColor: content.foreground)
            secondary = Color(cssColor: content.secondary)
            tertiary = Color(cssColor: content.tertiary)
            link = Color(cssColor: content.link)
            border = Color(cssColor: content.border)
            inlineCodeBackground = Color(cssColor: content.inlineCodeBackground)
            inlineCodeForeground = Color(cssColor: content.inlineCodeForeground)
            codeBackground = Color(cssColor: content.codeBackground)
            tableHeaderBackground = Color(cssColor: content.tableHeaderBackground)
            tableStripeBackground = Color(cssColor: content.tableStripeBackground)
            frontMatterBackground = Color(cssColor: frontmatter.background)
            frontMatterHeaderBackground = Color(cssColor: frontmatter.headerBackground)
            frontMatterGutter = Color(cssColor: frontmatter.gutter)
            frontMatterText = Color(cssColor: frontmatter.text)
            frontMatterKey = Color(cssColor: frontmatter.key)
            frontMatterString = Color(cssColor: frontmatter.string)
            frontMatterNumber = Color(cssColor: frontmatter.number)
            frontMatterBoolean = Color(cssColor: frontmatter.boolean)
            frontMatterNull = Color(cssColor: frontmatter.null)
            frontMatterPunctuation = Color(cssColor: frontmatter.punctuation)
            frontMatterBlockBackground = Color(cssColor: frontmatter.blockBackground)
            syntaxComment = Color(cssColor: syntax.comment)
            syntaxKeyword = Color(cssColor: syntax.keyword)
            syntaxString = Color(cssColor: syntax.string)
            syntaxNumber = Color(cssColor: syntax.number)
            syntaxBoolean = Color(cssColor: syntax.boolean)
            syntaxPunctuation = Color(cssColor: syntax.punctuation)
            syntaxKey = Color(cssColor: syntax.key)
        }

        cssVariables = description.cssVariables
    }
}

private struct MarkdownThemeDescription: Decodable {
    let colorScheme: String
    let content: ThemeContentDescription
    let frontmatter: ThemeFrontMatterDescription
    let syntax: ThemeSyntaxDescription

    static func decode(_ json: String) -> MarkdownThemeDescription {
        do {
            return try JSONDecoder().decode(Self.self, from: Data(json.utf8))
        } catch {
            assertionFailure("Invalid markdown theme JSON: \(error)")
            return try! JSONDecoder().decode(Self.self, from: Data(MarkdownTheme.light.jsonDescription.utf8))
        }
    }

    var cssVariables: String {
        """
          --md-bg: \(content.background);
          --md-fg: \(content.foreground);
          --md-secondary: \(content.secondary);
          --md-tertiary: \(content.tertiary);
          --md-link: \(content.link);
          --md-border: \(content.border);
          --md-inline-code-bg: \(content.inlineCodeBackground);
          --md-inline-code-fg: \(content.inlineCodeForeground);
          --md-code-bg: \(content.codeBackground);
          --md-table-header-bg: \(content.tableHeaderBackground);
          --md-table-stripe-bg: \(content.tableStripeBackground);
          --md-frontmatter-border: \(frontmatter.border);
          --md-frontmatter-gutter: \(frontmatter.gutter);
          --md-frontmatter-bg: \(frontmatter.background);
          --md-frontmatter-header-bg: \(frontmatter.headerBackground);
          --md-frontmatter-title: \(frontmatter.title);
          --md-frontmatter-delimiter: \(frontmatter.delimiter);
          --md-frontmatter-code-fg: \(frontmatter.text);
          --md-frontmatter-key: \(frontmatter.key);
          --md-frontmatter-value: \(frontmatter.text);
          --md-frontmatter-string: \(frontmatter.string);
          --md-frontmatter-number: \(frontmatter.number);
          --md-frontmatter-boolean: \(frontmatter.boolean);
          --md-frontmatter-null: \(frontmatter.null);
          --md-frontmatter-punctuation: \(frontmatter.punctuation);
          --md-frontmatter-block-bg: \(frontmatter.blockBackground);
          --md-frontmatter-block-border: \(frontmatter.blockBorder);
          --md-frontmatter-shadow: \(frontmatter.shadow);
          --md-syntax-comment: \(syntax.comment);
          --md-syntax-key: \(syntax.key);
          --md-syntax-string: \(syntax.string);
          --md-syntax-number: \(syntax.number);
          --md-syntax-keyword: \(syntax.keyword);
          --md-syntax-boolean: \(syntax.boolean);
          --md-syntax-punctuation: \(syntax.punctuation);
        """
    }
}

private struct ThemeContentDescription: Decodable {
    let background: String
    let foreground: String
    let secondary: String
    let tertiary: String
    let link: String
    let border: String
    let inlineCodeBackground: String
    let inlineCodeForeground: String
    let codeBackground: String
    let tableHeaderBackground: String
    let tableStripeBackground: String
}

private struct ThemeFrontMatterDescription: Decodable {
    let border: String
    let gutter: String
    let background: String
    let headerBackground: String
    let title: String
    let delimiter: String
    let text: String
    let key: String
    let string: String
    let number: String
    let boolean: String
    let null: String
    let punctuation: String
    let blockBackground: String
    let blockBorder: String
    let shadow: String
}

private struct ThemeSyntaxDescription: Decodable {
    let comment: String
    let key: String
    let string: String
    let number: String
    let keyword: String
    let boolean: String
    let punctuation: String
}

private extension Color {
    init(cssColor: String) {
        let trimmed = cssColor.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("#") else {
            self = Color(nsColor: .textColor)
            return
        }

        let value = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let int = UInt64(value, radix: 16) ?? 0
        self.init(
            red: Double((int >> 16) & 0xff) / 255,
            green: Double((int >> 8) & 0xff) / 255,
            blue: Double(int & 0xff) / 255
        )
    }
}
