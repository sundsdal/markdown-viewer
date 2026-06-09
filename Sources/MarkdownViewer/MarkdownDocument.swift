import Combine
import Darwin
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
        try self.init(data: configuration.file.regularFileContents, contentType: configuration.contentType)
    }

    init(data: Data?, contentType: UTType) throws {
        guard
            let data,
            let text = String(data: data, encoding: .utf8)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }

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

final class AutoReloadingMarkdownDocument: ObservableObject {
    @Published private(set) var document: MarkdownDocument

    private let fileURL: URL?
    private let queue = DispatchQueue(label: "MarkdownViewer.autoReload")
    private var lastLoadedDocument: MarkdownDocument
    private var fileSource: DispatchSourceFileSystemObject?
    private var directorySource: DispatchSourceFileSystemObject?
    private var reloadWorkItem: DispatchWorkItem?

    init(document: MarkdownDocument, fileURL: URL?) {
        self.document = document
        self.lastLoadedDocument = document
        self.fileURL = fileURL

        guard let fileURL else {
            return
        }

        queue.async { [weak self] in
            self?.installFileWatcher(for: fileURL)
            self?.installDirectoryWatcher(for: fileURL.deletingLastPathComponent())
        }
    }

    deinit {
        fileSource?.cancel()
        directorySource?.cancel()
        reloadWorkItem?.cancel()
    }

    func reload() {
        guard fileURL != nil else {
            return
        }
        queue.async { [weak self] in
            self?.reloadFromDisk(forceUpdate: true)
        }
    }

    private func installFileWatcher(for fileURL: URL) {
        fileSource?.cancel()
        fileSource = nil

        let fileDescriptor = open(fileURL.path, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .extend, .attrib, .delete, .rename, .revoke],
            queue: queue
        )

        source.setEventHandler { [weak self] in
            guard let self else { return }
            let events = source.data
            if events.contains(.delete) || events.contains(.rename) || events.contains(.revoke) {
                self.installFileWatcher(for: fileURL)
            }
            self.scheduleReload()
        }
        source.setCancelHandler {
            close(fileDescriptor)
        }

        fileSource = source
        source.resume()
    }

    private func installDirectoryWatcher(for directoryURL: URL) {
        directorySource?.cancel()
        directorySource = nil

        let fileDescriptor = open(directoryURL.path, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .delete, .rename, .revoke],
            queue: queue
        )

        source.setEventHandler { [weak self] in
            guard let self, let fileURL = self.fileURL else { return }
            self.installFileWatcher(for: fileURL)
            self.scheduleReload()
        }
        source.setCancelHandler {
            close(fileDescriptor)
        }

        directorySource = source
        source.resume()
    }

    private func scheduleReload() {
        reloadWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.reloadFromDisk()
        }
        reloadWorkItem = workItem
        queue.asyncAfter(deadline: .now() + 0.15, execute: workItem)
    }

    private func reloadFromDisk(forceUpdate: Bool = false) {
        guard let fileURL else {
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let contentType = Self.contentType(for: fileURL)
            let loadedDocument = try MarkdownDocument(data: data, contentType: contentType)

            let textChanged = loadedDocument.text != lastLoadedDocument.text
                || loadedDocument.fileType != lastLoadedDocument.fileType

            guard textChanged || forceUpdate else {
                return
            }

            lastLoadedDocument = loadedDocument
            installFileWatcher(for: fileURL)

            DispatchQueue.main.async { [weak self] in
                self?.document = loadedDocument
                let reason = forceUpdate && !textChanged ? "manual reload (no changes)" : (forceUpdate ? "manual reload" : "external change")
                LogStore.shared.log("Reloaded \(fileURL.lastPathComponent) — \(reason)", level: .debug, category: "file")
            }
        } catch {
            DispatchQueue.main.async {
                LogStore.shared.log("Could not reload \(fileURL.lastPathComponent): \(error.localizedDescription)", level: .warning, category: "file")
            }
        }
    }

    private static func contentType(for fileURL: URL) -> UTType {
        switch fileURL.pathExtension.lowercased() {
        case "md", "markdown":
            return .markdown
        case "json":
            return .json
        case "yaml", "yml":
            return .yaml
        default:
            return UTType(filenameExtension: fileURL.pathExtension) ?? .plainText
        }
    }
}
