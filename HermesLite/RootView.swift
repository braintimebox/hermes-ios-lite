import SwiftUI

// ============================================================
// HERMEX-LIKE READING-FIRST SURFACE
// - Composer hidden by default; a circular FAB reveals it.
// - Reasoning fold on assistant messages.
// - Scroll-to-bottom button appears when the user scrolled up.
// - Header: avatar/sessions menu + title + settings (glass).
// - Sticky Pinned panel only when there are pins.
// ============================================================

struct RootView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showingSessions = false
    @State private var showingScheduled = false
    @State private var showingPins = false
    @State private var showingSettings = false

    var body: some View {
        ZStack {
            HermesTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                HermesHeader(showingSessions: $showingSessions,
                             showingScheduled: $showingScheduled,
                             showingSettings: $showingSettings)

                if !store.activePins.isEmpty {
                    PinnedBanner(showingPins: $showingPins)
                        .padding(.horizontal, 12)
                        .padding(.top, 6)
                }

                ChatSurface()

                ComposerZone()
            }
        }
        .sheet(isPresented: $showingSessions) { SessionsSheet() }
        .sheet(isPresented: $showingScheduled) { ScheduledScreen() }
        .sheet(isPresented: $showingPins) { PinsScreen() }
        .sheet(isPresented: $showingSettings) { SettingsView() }
        .task { await store.bootstrap() }
    }
}

// MARK: - Header
struct HermesHeader: View {
    @EnvironmentObject private var store: AppStore
    @Binding var showingSessions: Bool
    @Binding var showingScheduled: Bool
    @Binding var showingSettings: Bool

    var body: some View {
        HStack(spacing: 10) {
            Button { showingSessions = true } label: {
                ZStack {
                    Circle().fill(Color.cyan.opacity(0.18))
                    Text(initials)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.cyan)
                }
                .frame(width: 38, height: 38)
            }
            .buttonStyle(.plain)

            Button { showingSessions = true } label: {
                VStack(alignment: .leading, spacing: 1) {
                    Text(store.session?.title ?? "Hermes")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            HStack(spacing: 8) {
                IconButton("clock") { showingScheduled = true }
                IconButton("gearshape") { showingSettings = true }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
    }

    private var initials: String {
        let t = store.session?.title ?? "H"
        return String(t.prefix(1)).uppercased()
    }
    private var detail: String {
        if store.isSending { return "sending…" }
        if store.isRefreshing { return "syncing…" }
        return "\(store.messages.count) messages"
    }
}

struct IconButton: View {
    let systemName: String
    let action: () -> Void
    init(_ s: String, action: @escaping () -> Void) { self.systemName = s; self.action = action }
    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 32, height: 32)
                .background(Color.white.opacity(0.08), in: Circle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Pinned banner (Hermex-like compact)
struct PinnedBanner: View {
    @EnvironmentObject private var store: AppStore
    @Binding var showingPins: Bool

    var body: some View {
        Button { showingPins = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "pin.fill")
                    .foregroundStyle(.yellow)
                    .font(.caption)
                Text(store.activePins.first?.text ?? "")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.82))
                    .lineLimit(1)
                Spacer()
                if store.activePins.count > 1 {
                    Text("+\(store.activePins.count - 1)")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
