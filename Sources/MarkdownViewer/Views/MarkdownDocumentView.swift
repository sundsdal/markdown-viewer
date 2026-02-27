import SwiftUI
import MarkdownView

struct MarkdownDocumentView: View {
    let document: MarkdownDocument
    @AppStorage("fontSize") private var fontSize: Double = 16
    @AppStorage("codeTheme") private var codeTheme = "auto"
    @State private var isLoaded = false

    var body: some View {
        ScrollView {
            if isLoaded {
                MarkdownView(document.text)
                    .font(.system(size: fontSize), for: .body)
                    .codeBlockStyle(DefaultCodeBlockStyle.default(lightTheme: resolvedLightTheme, darkTheme: resolvedDarkTheme))
                    .padding(40)
                    .frame(maxWidth: 800)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 200)
            }
        }
        .background(.background)
        .task {
            LogStore.shared.log(
                "Opened document (\(document.text.utf8.count) bytes)",
                level: .info,
                category: "document"
            )
            isLoaded = true
        }
        .toolbar {
            ToolbarItemGroup {
                Button(action: decreaseFontSize) {
                    Label("Decrease font", systemImage: "textformat.size.smaller")
                }
                Button(action: increaseFontSize) {
                    Label("Increase font", systemImage: "textformat.size.larger")
                }
            }
        }
    }

    private var resolvedLightTheme: String { codeTheme == "auto" ? "xcode" : codeTheme }
    private var resolvedDarkTheme: String  { codeTheme == "auto" ? "atom-one-dark" : codeTheme }

    private func decreaseFontSize() {
        if fontSize > 10 {
            fontSize -= 2
            LogStore.shared.log("Font size → \(Int(fontSize))pt", level: .debug, category: "ui")
        }
    }

    private func increaseFontSize() {
        if fontSize < 28 {
            fontSize += 2
            LogStore.shared.log("Font size → \(Int(fontSize))pt", level: .debug, category: "ui")
        }
    }
}

#Preview {
    MarkdownDocumentView(document: MarkdownDocument(text: """
    # Hello, Markdown

    This is a **preview** of the markdown renderer.

    ## Features
    - Syntax highlighting
    - Tables
    - Code blocks

    ```swift
    let greeting = "Hello, world!"
    print(greeting)
    ```
    """))
    .frame(width: 700, height: 500)
}
