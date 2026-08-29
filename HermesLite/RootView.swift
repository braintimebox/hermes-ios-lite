import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showingSettings = false
    @State private var showingScheduled = false
    @State private var showingPins = false
    @State private var showingSessions = false
    @State private var scheduleDate = Date().addingTimeInterval(3600)

    var body: some View {
        NavigationStack {
            ZStack {
                HermesTheme.background.ignoresSafeArea()
                VStack(spacing: 10) {
                    TopStatusBar(showingSettings: $showingSettings,
                                 showingSessions: $showingSessions,
                                 showingScheduled: $showingScheduled)
                    QuickPanels(showingPins: $showingPins, showingScheduled: $showingScheduled)
                    MessageListView()
                    if let error = store.error { ErrorStrip(text: error) }
                    ComposerView(scheduleDate: $scheduleDate)
                }
                .padding(.horizontal, 10)
                .padding(.top, 8)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingSettings) { SettingsView() }
            .sheet(isPresented: $showingScheduled) { ScheduledView() }
            .sheet(isPresented: $showingPins) { PinsView() }
            .sheet(isPresented: $showingSessions) { SessionsView() }
            .task { await store.bootstrap() }
        }
    }
}

struct TopStatusBar: View {
    @EnvironmentObject private var store: AppStore
    @Binding var showingSettings: Bool
    @Binding var showingSessions: Bool
    @Binding var showingScheduled: Bool

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(Color.cyan.opacity(0.2))
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.cyan)
            }
            .frame(width: 40, height: 40)

            Button { showingSessions = true } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.session?.title ?? "Hermes")
                        .font(.headline.weight(.semibold))
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Circle().fill(store.isRefreshing ? Color.orange : Color.green).frame(width: 7, height: 7)
                        Text(store.isRefreshing ? "syncing" : "ready")
                        Text("·")
                        Text("\(store.messages.count) rows")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            HStack(spacing: 8) {
                HeaderButton(systemName: "clock") { showingScheduled = true }
                HeaderButton(systemName: "gearshape") { showingSettings = true }
            }
        }
        .foregroundStyle(.white)
        .padding(10)
        .hermesCard(radius: 22)
    }
}

struct HeaderButton: View {
    let systemName: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 34, height: 34)
                .background(Color.white.opacity(0.10), in: Circle())
        }
        .buttonStyle(.plain)
    }
}

struct QuickPanels: View {
    @EnvironmentObject private var store: AppStore
    @Binding var showingPins: Bool
    @Binding var showingScheduled: Bool

    var body: some View {
        HStack(spacing: 8) {
            Button { showingPins = true } label: {
                QuickPanel(icon: "pin.fill",
                           title: store.activePins.first == nil ? "Pins" : "Pinned",
                           subtitle: store.activePins.first?.text ?? "Long-press any bubble",
                           accent: .yellow)
            }
            .buttonStyle(.plain)

            Button { showingScheduled = true } label: {
                QuickPanel(icon: "clock.badge.checkmark",
                           title: "Scheduled",
                           subtitle: store.scheduled.isEmpty ? "No pending" : "\(store.scheduled.count) pending",
                           accent: .cyan)
            }
            .buttonStyle(.plain)
        }
    }
}

struct QuickPanel: View {
    let icon: String
    let title: String
    let subtitle: String
    let accent: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(accent)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption.weight(.semibold)).foregroundStyle(.white)
                Text(subtitle).font(.caption2).foregroundStyle(.white.opacity(0.62)).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .hermesCard(radius: 16)
    }
}

struct MessageListView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    if store.messages.isEmpty {
                        EmptyChatView()
                    } else {
                        ForEach(store.messages) { message in
                            MessageRow(message: message)
                                .id(message.id)
                        }
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.vertical, 10)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.black.opacity(0.13), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.white.opacity(0.06), lineWidth: 1))
            .onChange(of: store.messages.count) { _, _ in
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        }
    }
}

struct EmptyChatView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "bolt.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.cyan)
            Text("Fast Hermes client")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
            Text("No Markdown hot path. No heavy overlays. Send, pin, schedule.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.62))
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 70)
        .padding(.horizontal, 24)
    }
}

struct MessageRow: View {
    @EnvironmentObject private var store: AppStore
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .bottom) {
            if message.isUser { Spacer(minLength: 42) }
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                HStack(spacing: 5) {
                    if store.isPinned(message) { Image(systemName: "pin.fill").foregroundStyle(.yellow) }
                    Text(message.isUser ? "You" : "Hermes")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.52))
                }
                Text(message.content)
                    .font(.body)
                    .foregroundStyle(.white)
                    .textSelection(.enabled)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background {
                        if message.isUser {
                            RoundedRectangle(cornerRadius: 18, style: .continuous).fill(HermesTheme.userBubble)
                        } else {
                            RoundedRectangle(cornerRadius: 18, style: .continuous).fill(HermesTheme.assistantBubble)
                        }
                    }
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(message.isUser ? 0.08 : 0.10), lineWidth: 1))
                    .contentShape(Rectangle())
                    .contextMenu {
                        Button(store.isPinned(message) ? "Unpin" : "Pin", systemImage: "pin") { store.togglePin(message) }
                        Button("Copy", systemImage: "doc.on.doc") { UIPasteboard.general.string = message.content }
                    }
            }
            if !message.isUser { Spacer(minLength: 42) }
        }
        .padding(.horizontal, 8)
    }
}

struct ComposerView: View {
    @EnvironmentObject private var store: AppStore
    @Binding var scheduleDate: Date
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .bottom, spacing: 8) {
                TextField("Message Hermes…", text: $store.draft, axis: .vertical)
                    .lineLimit(1...5)
                    .focused($focused)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .foregroundStyle(.white)
                    .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                Button { Task { await store.scheduleDraft(at: scheduleDate) } } label: {
                    Image(systemName: "clock.badge.plus")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 40, height: 40)
                        .background(Color.white.opacity(0.10), in: Circle())
                }
                .disabled(store.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button { Task { await store.sendNow() } } label: {
                    Group {
                        if store.isSending { ProgressView().tint(.white) }
                        else { Image(systemName: "paperplane.fill") }
                    }
                    .font(.system(size: 16, weight: .bold))
                    .frame(width: 42, height: 42)
                    .background(Color.cyan.opacity(0.76), in: Circle())
                }
                .disabled(store.isSending || store.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            HStack(spacing: 8) {
                DatePicker("", selection: $scheduleDate, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.compact)
                    .labelsHidden()
                Spacer()
                Text("Schedule uses server timer")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
        .padding(10)
        .foregroundStyle(.white)
        .hermesCard(radius: 22)
    }
}

struct ErrorStrip: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.red.opacity(0.92))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct SessionsView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Button {
                    Task {
                        await store.newSession()
                        dismiss()
                    }
                } label: {
                    Label("New chat", systemImage: "plus.circle.fill")
                }
                ForEach(store.sessions) { session in
                    Button {
                        Task {
                            await store.select(session)
                            dismiss()
                        }
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
            .navigationTitle("Chats")
            .toolbar { Button("Done") { dismiss() } }
            .task { await store.loadSessions() }
        }
    }
}
