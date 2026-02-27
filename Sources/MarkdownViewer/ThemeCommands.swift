import SwiftUI

struct ThemeCommands: Commands {
    @AppStorage("codeTheme") private var codeTheme = "auto"

    private let lightThemes = ["xcode", "github", "atom-one-light", "solarized-light", "vs"]
    private let darkThemes = ["atom-one-dark", "github-dark", "dracula", "nord", "tokyo-night-dark", "tomorrow-night-bright", "monokai"]

    var body: some Commands {
        CommandGroup(after: .toolbar) {
            Menu("Code Syntax") {
                Picker("", selection: $codeTheme) {
                    Text("Auto").tag("auto")
                    Section("Light") {
                        ForEach(lightThemes, id: \.self) { Text($0).tag($0) }
                    }
                    Section("Dark") {
                        ForEach(darkThemes, id: \.self) { Text($0).tag($0) }
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
        }
    }
}
