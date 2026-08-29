import SwiftUI

// MARK: - SessionsSheet (multi-session, Hermex-like)
struct SessionsSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Button {
                    Task { await store.newSession(); dismiss() }
                } label: {
                    Label("New chat", systemImage: "plus.circle.fill")
                }
                Section("Chats") {
                    ForEach(store.sessions) { session in
                        Button {
                            Task { await store.select(session); dismiss() }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(session.title).lineLimit(1)
                                    Text(session.sessionId).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                                }
                                Spacer()
                                if store.session?.sessionId == session.sessionId { Image(systemName: "checkmark") }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Chats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { dismiss() } }
            .task { await store.loadSessions() }
        }
    }
}

// MARK: - PinnedScreen
struct PinsScreen: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.activePins) { pin in
                    Text(pin.text).lineLimit(4)
                }
                .onDelete { offsets in
                    for i in offsets {
                        let p = store.activePins[i]
                        store.pins.removeAll { $0.id == p.id }
                    }
                }
            }
            .overlay {
                if store.activePins.isEmpty { ContentUnavailableView("No pinned messages", systemImage: "pin") }
            }
            .navigationTitle("Pinned")
            .toolbar { Button("Done") { dismiss() } }
        }
    }
}

// MARK: - ScheduledScreen
struct ScheduledScreen: View {
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
