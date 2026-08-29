import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showingSettings = false
    @State private var showingScheduled = false
    @State private var showingPins = false
    @State private var scheduleDate = Date().addingTimeInterval(3600)

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let pin = store.pins.first {
                    Button { showingPins = true } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "pin.fill")
                            Text(pin.text).lineLimit(1)
                            Spacer()
                        }
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.thinMaterial)
                    }
                    .buttonStyle(.plain)
                }

                MessageListView()

                if let error = store.error {
                    Text(error).font(.caption).foregroundStyle(.red).padding(.horizontal)
                }

                ComposerView(scheduleDate: $scheduleDate)
            }
            .navigationTitle("Hermes Lite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingSettings = true } label: { Image(systemName: "gear") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingPins = true } label: { Image(systemName: "pin") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingScheduled = true } label: { Image(systemName: "clock") }
                }
            }
            .sheet(isPresented: $showingSettings) { SettingsView() }
            .sheet(isPresented: $showingScheduled) { ScheduledView() }
            .sheet(isPresented: $showingPins) { PinsView() }
            .task { await store.refreshMessages() }
        }
    }
}

struct MessageListView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(store.messages) { message in
                        MessageRow(message: message)
                            .id(message.id)
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(10)
            }
            .background(Color(.systemBackground))
            .onChange(of: store.messages.count) { _, _ in
                withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo("bottom", anchor: .bottom) }
            }
        }
    }
}

struct MessageRow: View {
    @EnvironmentObject private var store: AppStore
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.isUser { Spacer(minLength: 36) }
            Text(message.content)
                .font(.body)
                .textSelection(.enabled)
                .padding(10)
                .background(message.isUser ? Color.accentColor.opacity(0.18) : Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .contentShape(Rectangle())
                .contextMenu {
                    Button(store.isPinned(message) ? "Unpin" : "Pin", systemImage: "pin") { store.togglePin(message) }
                    Button("Copy", systemImage: "doc.on.doc") { UIPasteboard.general.string = message.content }
                }
            if !message.isUser { Spacer(minLength: 36) }
        }
    }
}

struct ComposerView: View {
    @EnvironmentObject private var store: AppStore
    @Binding var scheduleDate: Date

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Message", text: $store.draft, axis: .vertical)
                .lineLimit(1...5)
                .textFieldStyle(.roundedBorder)
            Button { Task { await store.scheduleDraft(at: scheduleDate) } } label: {
                Image(systemName: "clock.badge.plus")
            }
            .disabled(store.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button { Task { await store.sendNow() } } label: {
                if store.isSending { ProgressView() } else { Image(systemName: "paperplane.fill") }
            }
            .disabled(store.isSending || store.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(10)
        DatePicker("", selection: $scheduleDate, displayedComponents: [.date, .hourAndMinute])
            .datePickerStyle(.compact)
            .labelsHidden()
            .padding(.horizontal, 10)
            .padding(.bottom, 6)
    }
}
