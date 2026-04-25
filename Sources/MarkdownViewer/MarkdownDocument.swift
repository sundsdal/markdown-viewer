import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let markdown = UTType(
        importedAs: "net.daringfireball.markdown",
        conformingTo: .plainText
    )
}

struct MarkdownDocument: FileDocument {
    enum FileType {
        case markdown
        case json
        case yaml
        case plainText
    }

    static var readableContentTypes: [UTType] = [.markdown, .json, .yaml, .plainText]

    var text: String
    var fileType: FileType

    init(text: String = "", fileType: FileType = .markdown) {
        self.text = text
        self.fileType = fileType
    }

    init(configuration: ReadConfiguration) throws {
        guard
            let data = configuration.file.regularFileContents,
            let text = String(data: data, encoding: .utf8)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }

        let contentType = configuration.contentType
        if contentType.conforms(to: .json) {
            self.fileType = .json
            // Pretty-print JSON; fall back to raw text on parse failure
            if let jsonObject = try? JSONSerialization.jsonObject(with: data),
               let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted, .sortedKeys]),
               let prettyText = String(data: prettyData, encoding: .utf8) {
                self.text = prettyText
            } else {
                self.text = text
            }
        } else if contentType.conforms(to: .yaml) {
            self.fileType = .yaml
            self.text = text
        } else if contentType.conforms(to: UTType.markdown) {
            self.fileType = .markdown
            self.text = text
        } else {
            self.fileType = .plainText
            self.text = text
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = Data(text.utf8)
        return FileWrapper(regularFileWithContents: data)
    }
}
