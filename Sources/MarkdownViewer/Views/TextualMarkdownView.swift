import SwiftUI
import Textual

struct TextualMarkdownView: View {
    let markdown: String
    let fontSize: Double
    let scrollPosition: RendererScrollPosition
    let scrollApplyToken: UUID
    let source: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let frontMatter = FrontMatterDocument.split(from: markdown) {
                    TextualFrontMatterView(yaml: frontMatter.yaml)
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
    }

    private func textualMarkdown(_ text: String) -> some View {
        StructuredText(markdown: text)
            .font(.system(size: fontSize))
            .textual.textSelection(.enabled)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("frontmatter.yml")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("---")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Color(nsColor: .controlBackgroundColor))

            Text(yaml)
                .font(.system(size: 13, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)

            Text("---")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
        }
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        }
    }
}
