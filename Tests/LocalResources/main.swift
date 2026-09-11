import AppKit
import Darwin
import WebKit

final class ResourceTask: NSObject, WKURLSchemeTask {
    let request: URLRequest
    var data = Data()
    var finished = false
    var error: Error?
    var callbacks = 0

    init(fileURL: URL) {
        var url = URLComponents()
        url.scheme = "markdown-resource"
        url.host = "document"
        url.path = fileURL.path
        request = URLRequest(url: url.url!)
    }
    func didReceive(_ response: URLResponse) { callbacks += 1 }
    func didReceive(_ data: Data) { callbacks += 1; self.data.append(data) }
    func didFinish() { callbacks += 1; finished = true }
    func didFailWithError(_ error: Error) { callbacks += 1; self.error = error }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: directory) }
let regular = directory.appendingPathComponent("image.png")
let expected = Data((0..<(128 * 1024 + 1)).map { UInt8($0 % 251) })
try expected.write(to: regular)
let fifo = directory.appendingPathComponent("pipe")
precondition(mkfifo(fifo.path, 0o600) == 0)
let oversized = directory.appendingPathComponent("large.png")
let descriptor = open(oversized.path, O_CREAT | O_WRONLY, 0o600)
precondition(descriptor >= 0)
precondition(ftruncate(descriptor, 33 * 1024 * 1024) == 0)
close(descriptor)
let symlink = directory.appendingPathComponent("device.png")
try FileManager.default.createSymbolicLink(at: symlink, withDestinationURL: URL(fileURLWithPath: "/dev/zero"))

let scrollPosition = MainActor.assumeIsolated { RendererScrollPosition() }
let view = MarkdownWebView(markdown: "", sourceFileURL: regular, fontSize: 16, theme: .light,
    scrollPosition: scrollPosition, scrollApplyToken: UUID(), source: "test", synchronizesScroll: false,
    searchQuery: "", searchIsCaseSensitive: false, selectedSearchHitIndex: 0, onSearchHitCountChange: { _ in })
let coordinator = view.makeCoordinator()
let configuration = WKWebViewConfiguration()
configuration.websiteDataStore = .nonPersistent()
let webView = WKWebView(frame: .zero, configuration: configuration)
let good = ResourceTask(fileURL: regular)
let rejected = [URL(fileURLWithPath: "/dev/zero"), fifo, oversized, symlink, directory].map(ResourceTask.init)
let cancelled = ResourceTask(fileURL: regular)
for task in [good] + rejected + [cancelled] {
    coordinator.webView(webView, start: task)
}
coordinator.webView(webView, stop: cancelled)
let deadline = Date().addingTimeInterval(5)
while Date() < deadline && (!good.finished || rejected.contains(where: { $0.error == nil })) {
    RunLoop.current.run(until: Date().addingTimeInterval(0.01))
}
// Let any incorrectly retained cancelled callbacks reach the main queue.
RunLoop.current.run(until: Date().addingTimeInterval(0.1))
precondition(good.finished && good.error == nil && good.data == expected, "Regular resource must load unchanged")
for task in rejected {
    precondition(task.error != nil && task.data.isEmpty && !task.finished, "Must reject promptly without reading: \(task.request.url!)")
}
precondition(cancelled.callbacks == 0, "Stopped request must not receive callbacks")
print("PASS: regular resource, device, FIFO, oversized file, device symlink, directory, cancellation")
