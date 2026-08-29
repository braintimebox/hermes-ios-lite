import SwiftUI

struct ScheduledView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.scheduled) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.text).lineLimit(3)
                        Text(item.scheduledAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .swipeActions {
                        Button(role: .destructive) { Task { await store.deleteScheduled(item) } } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .overlay {
                if store.scheduled.isEmpty { ContentUnavailableView("No scheduled messages", systemImage: "clock") }
            }
            .navigationTitle("Scheduled")
            .toolbar { Button("Done") { dismiss() } }
            .task { await store.loadScheduled() }
        }
    }
}

struct PinsView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.pins) { pin in
                    Text(pin.text).lineLimit(4)
                }
                .onDelete { offsets in store.pins.remove(atOffsets: offsets) }
            }
            .overlay {
                if store.pins.isEmpty { ContentUnavailableView("No pinned messages", systemImage: "pin") }
            }
            .navigationTitle("Pinned")
            .toolbar { Button("Done") { dismiss() } }
        }
    }
}
