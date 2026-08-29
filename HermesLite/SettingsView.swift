import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Server") {
                    TextField("Base URL", text: Binding(
                        get: { store.client.baseURL },
                        set: { store.client.baseURL = $0 }
                    ))
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    SecureField("WebUI password", text: Binding(
                        get: { store.client.password },
                        set: { store.client.password = $0 }
                    ))
                    Button("Reset login cookie") { store.client.clearAuth() }
                }
                Section("Current chat") {
                    Text(store.session?.sessionId ?? "No session yet")
                        .font(.caption)
                        .textSelection(.enabled)
                    Button("New chat") {
                        Task { await store.newSession(); dismiss() }
                    }
                }
                Section("Performance choices") {
                    Label("Reading-first composer (FAB)", systemImage: "bolt.fill")
                    Label("Throttled Markdown: assistant only, >2KB", systemImage: "textformat")
                    Label("Stable identity + granular invalidation", systemImage: "list.bullet")
                    Label("Pinned and Scheduled are local + server timer", systemImage: "pin.fill")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { dismiss() } }
        }
    }
}
