import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Server") {
                    TextField("Base URL", text: $store.client.baseURL)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                    SecureField("WebUI password", text: $store.client.password)
                    Button("Reset login cookie") { store.client.clearAuth() }
                }
                Section("Current chat") {
                    Text(store.session?.sessionId ?? "No session yet")
                        .font(.caption)
                        .textSelection(.enabled)
                    Button("New chat") {
                        store.session = nil
                        store.messages = []
                    }
                }
                Section("Performance choices") {
                    Label("Plain Text renderer: no Markdown re-layout", systemImage: "bolt.fill")
                    Label("LazyVStack transcript", systemImage: "list.bullet")
                    Label("Pins are local and instant", systemImage: "pin.fill")
                }
            }
            .navigationTitle("Settings")
            .toolbar { Button("Done") { dismiss() } }
        }
    }
}
