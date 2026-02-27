import SwiftUI

struct DebugLogView: View {
    private let store = LogStore.shared

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    var body: some View {
        Group {
            if store.entries.isEmpty {
                ContentUnavailableView(
                    "No Logs",
                    systemImage: "doc.text",
                    description: Text("Log messages will appear here.")
                )
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 1) {
                            ForEach(store.entries) { entry in
                                LogEntryRow(entry: entry, formatter: Self.timeFormatter)
                                    .id(entry.id)
                            }
                        }
                        .padding(8)
                    }
                    .onChange(of: store.entries.count) { _, _ in
                        if let last = store.entries.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem {
                Button("Clear", action: store.clear)
                    .disabled(store.entries.isEmpty)
            }
        }
    }
}

private struct LogEntryRow: View {
    let entry: LogEntry
    let formatter: DateFormatter

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(formatter.string(from: entry.date))
                .foregroundStyle(.secondary)
            Text(entry.level.rawValue)
                .foregroundStyle(levelColor)
                .frame(width: 56, alignment: .leading)
            Text(entry.category)
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .leading)
            Text(entry.message)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.system(.caption, design: .monospaced))
        .padding(.vertical, 2)
    }

    private var levelColor: Color {
        switch entry.level {
        case .debug:   .secondary
        case .info:    .primary
        case .warning: .orange
        case .error:   .red
        }
    }
}
