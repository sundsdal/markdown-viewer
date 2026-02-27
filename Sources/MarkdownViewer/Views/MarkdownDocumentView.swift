import SwiftUI
import MarkdownView

struct MarkdownDocumentView: View {
    let document: MarkdownDocument
    @AppStorage("fontSize") private var fontSize: Double = 16
    @State private var isLoaded = false

    var body: some View {
        ScrollView {
            if isLoaded {
                MarkdownView(document.text)
                    .font(.system(size: fontSize), for: .body)
                    .codeBlockStyle(DefaultCodeBlockStyle.default(lightTheme: "xcode", darkTheme: "dark"))
                    .padding(40)
                    .frame(maxWidth: 800)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 200)
            }
        }
        .background(.background)
        .task { isLoaded = true }
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

    private func decreaseFontSize() { if fontSize > 10 { fontSize -= 2 } }
    private func increaseFontSize() { if fontSize < 28 { fontSize += 2 } }
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
