import SwiftUI

final class RendererScrollPosition: ObservableObject {
    var fraction: CGFloat = 0
    var activeSource: String?
    @Published var applyToken = UUID()

    func update(fraction: CGFloat, source: String, broadcast: Bool = true) {
        guard fraction.isFinite else { return }
        self.fraction = min(max(fraction, 0), 1)
        activeSource = source
        if broadcast {
            applyToken = UUID()
        }
    }

    func requestApply(source: String? = nil) {
        activeSource = source
        applyToken = UUID()
    }
}

struct NativeScrollPositionObserver: NSViewRepresentable {
    let source: String
    let scrollPosition: RendererScrollPosition
    let applyToken: UUID
    let broadcastsScrollUpdates: Bool

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            context.coordinator.attach(from: view)
            context.coordinator.applyScrollPositionIfNeeded(applyToken: applyToken)
        }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        context.coordinator.source = source
        context.coordinator.scrollPosition = scrollPosition
        context.coordinator.broadcastsScrollUpdates = broadcastsScrollUpdates
        DispatchQueue.main.async {
            context.coordinator.attach(from: view)
            context.coordinator.applyScrollPositionIfNeeded(applyToken: applyToken)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            source: source,
            scrollPosition: scrollPosition,
            broadcastsScrollUpdates: broadcastsScrollUpdates
        )
    }

    final class Coordinator {
        var source: String
        var scrollPosition: RendererScrollPosition
        var broadcastsScrollUpdates: Bool
        private weak var scrollView: NSScrollView?
        private var observer: NSObjectProtocol?
        private var isApplying = false
        private var lastApplyToken: UUID?

        init(source: String, scrollPosition: RendererScrollPosition, broadcastsScrollUpdates: Bool) {
            self.source = source
            self.scrollPosition = scrollPosition
            self.broadcastsScrollUpdates = broadcastsScrollUpdates
        }

        deinit {
            if let observer {
                NotificationCenter.default.removeObserver(observer)
            }
        }

        func attach(from view: NSView) {
            guard let enclosingScrollView = view.enclosingScrollView,
                  enclosingScrollView !== scrollView else {
                return
            }

            if let observer {
                NotificationCenter.default.removeObserver(observer)
            }

            scrollView = enclosingScrollView
            enclosingScrollView.contentView.postsBoundsChangedNotifications = true
            observer = NotificationCenter.default.addObserver(
                forName: NSView.boundsDidChangeNotification,
                object: enclosingScrollView.contentView,
                queue: .main
            ) { [weak self] _ in
                self?.recordScrollPosition()
            }
        }

        func applyScrollPositionIfNeeded(applyToken: UUID) {
            guard lastApplyToken != applyToken else { return }
            lastApplyToken = applyToken
            guard scrollPosition.activeSource != source else { return }
            guard let scrollView else { return }
            isApplying = true
            scroll(to: scrollPosition.fraction, in: scrollView)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                self?.scroll(to: self?.scrollPosition.fraction ?? 0, in: scrollView)
                self?.isApplying = false
            }
        }

        private func recordScrollPosition() {
            guard !isApplying, let scrollView else { return }
            scrollPosition.update(
                fraction: currentFraction(in: scrollView),
                source: source,
                broadcast: broadcastsScrollUpdates
            )
        }

        private func scroll(to fraction: CGFloat, in scrollView: NSScrollView) {
            let maximumY = max(0, documentHeight(in: scrollView) - scrollView.contentView.bounds.height)
            let y = min(max(fraction, 0), 1) * maximumY
            let currentX = scrollView.contentView.bounds.origin.x
            scrollView.contentView.scroll(to: NSPoint(x: currentX, y: y))
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }

        private func currentFraction(in scrollView: NSScrollView) -> CGFloat {
            let maximumY = max(0, documentHeight(in: scrollView) - scrollView.contentView.bounds.height)
            guard maximumY > 0 else { return 0 }
            return scrollView.contentView.bounds.origin.y / maximumY
        }

        private func documentHeight(in scrollView: NSScrollView) -> CGFloat {
            scrollView.documentView?.bounds.height ?? 0
        }
    }
}
