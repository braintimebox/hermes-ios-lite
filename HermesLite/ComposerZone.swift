import SwiftUI

// MARK: - ComposerZone (reading-first: hidden until FAB reveals)
struct ComposerZone: View {
    @EnvironmentObject private var store: AppStore
    @State private var showingSchedule = false
    @State private var scheduleDate = Date().addingTimeInterval(3600)
    @FocusState private var focused: Bool

    var body: some View {
        if store.composerVisible {
            inputBar
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
        }
    }

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Button { showingSchedule = true } label: {
                Image(systemName: "clock.badge.plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(Color.white.opacity(0.08), in: Circle())
            }
            .disabled(store.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            TextField("Message…", text: $store.draft, axis: .vertical)
                .lineLimit(1...5)
                .focused($focused)
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            Button { Task { await store.sendNow() } } label: {
                Group {
                    if store.isSending { ProgressView().tint(.white) }
                    else { Image(systemName: "paperplane.fill") }
                }
                .font(.system(size: 16, weight: .bold))
                .frame(width: 40, height: 40)
                .background(Color.cyan.opacity(0.75), in: Circle())
            }
            .disabled(store.isSending || store.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(8)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .sheet(isPresented: $showingSchedule) {
            ScheduleSheet(date: $scheduleDate)
        }
        .onAppear { focused = true }
    }
}

// MARK: - ScheduleSheet (Hermex-style, not an inline picker)
struct ScheduleSheet: View {
    @EnvironmentObject private var store: AppStore
    @Binding var date: Date
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Send at", selection: $date, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                Section {
                    Button("Schedule") {
                        Task { await store.scheduleDraft(at: date); dismiss() }
                    }
                }
            }
            .navigationTitle("Schedule message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Cancel") { dismiss() } }
        }
        .presentationDetents([.medium])
    }
}
