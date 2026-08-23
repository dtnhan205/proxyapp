import SwiftUI
import UIKit

struct GamesHomeView: View {
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var draftCoordinator: PatchDraftCoordinator
    @StateObject private var store = PatchProjectStore()
    @State private var games: [RemoteGameSummary] = []
    @State private var isLoadingGames = false
    @State private var showingGamePatches = false
    @State private var selectedGame: RemoteGameSummary?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 14)]

    var body: some View {
        NavigationStackCompat {
            ScrollView {
                deviceInfoCard
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                gamesGrid

                emptyStatePlaceholder
            }
            .frame(maxWidth: .infinity)
            .appBackground()
            .navigationTitle(AppBranding.string("tabHome", locale: language.rawValue))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { homeToolbar }
            .toolbarBackground(AppTheme.techBackgroundTop.opacity(0.6), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .refreshable { await loadGames() }
            .task { await loadGames() }
            .sheet(item: $draftCoordinator.request) { request in
                PatchProjectEditorView(
                    existingProject: nil,
                    passwordIsProtected: false,
                    initialDraft: request.draft
                ) { project, password in
                    store.create(project: project, password: password)
                    draftCoordinator.clear()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .tint(AppTheme.neonCyan)
        .preferredColorScheme(.dark)
    }

    /// Grid chứa danh sách game — tách riêng để Swift type-checker xử lý
    /// được trong thời gian hợp lý (tránh timeout compile ở build -O).
    private var gamesGrid: some View {
        LazyVGrid(columns: columns, spacing: 14) {
            ForEach(Array(games.enumerated()), id: \.element.id) { index, game in
                gameCardButton(for: game, at: index)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .animation(.easeOut(duration: 0.3), value: games)
        .navigationDestinationCompat(isPresented: $showingGamePatches) {
            if let game = selectedGame {
                GamePatchesView(game: game, store: store)
            }
        }
    }

    private func gameCardButton(for game: RemoteGameSummary, at index: Int) -> some View {
        Button {
            selectedGame = game
            showingGamePatches = true
        } label: {
            GameCardView(
                title: game.name,
                subtitle: game.bundleID.isEmpty ? " " : game.bundleID,
                bannerColor: Color(hex: game.bannerColor) ?? AppTheme.neonCyan,
                iconURL: game.iconURL,
                systemIconName: "app.fill",
                accent: AppTheme.rowColor(index)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var emptyStatePlaceholder: some View {
        if games.isEmpty && !isLoadingGames {
            Text(language.text("patch.no_games_yet"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.top, 8)
        }
    }

    @ToolbarContentBuilder
    private var homeToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            HStack(spacing: 4) {
                PulsingDot(color: AppTheme.neonLime, size: 6)
                NeonReadout(text: "ONLINE", tint: AppTheme.neonLime)
            }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            NavigationLink {
                SettingsView()
            } label: {
                Image(systemName: "gearshape")
                    .foregroundStyle(AppTheme.neonCyan)
                    .shadow(color: AppTheme.neonCyan.opacity(0.6), radius: 4)
            }
            .accessibilityLabel(AppBranding.string("tabSettings", locale: language.rawValue))
        }
    }

    private func loadGames() async {
        isLoadingGames = true
        if let fetched = try? await PatchHubService.fetchGames() {
            games = fetched
        }
        isLoadingGames = false
    }

    private var deviceInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                PulsingDot(color: AppTheme.neonCyan, size: 6)
                NeonReadout(text: "DEVICE STATUS", tint: AppTheme.neonCyan)
            }
            deviceInfoRow(icon: "apple.logo", iconColor: AppTheme.neonMagenta, label: "iOS", value: shortOSVersion)
            deviceInfoRow(icon: "iphone", iconColor: AppTheme.neonCyan, label: language.text("common.device"), value: AppInfo.hardwareDisplayName)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .techCard(glow: AppTheme.neonCyan, opacity: 0.15)
    }

    private func deviceInfoRow(icon: String, iconColor: Color, label: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(iconColor)
                .frame(width: 18)
                .shadow(color: iconColor.opacity(0.6), radius: 4)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
    }

    private var shortOSVersion: String {
        let version = AppInfo.osVersion
        if version.hasSuffix(".0") {
            return String(version.dropLast(2))
        }
        return version
    }
}

struct GameCardView: View {
    let title: String
    let subtitle: String
    let bannerColor: Color
    let iconURL: URL?
    let systemIconName: String
    let accent: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var glowPhase: Double = 0

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                LinearGradient(
                    colors: [
                        bannerColor,
                        bannerColor.opacity(0.6),
                        Color.black.opacity(0.4),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                // Performance: Slower sheen (8s vs 3.5s), skip animation if reduceMotion
                if !reduceMotion {
                    LinearGradient(
                        colors: [
                            .clear,
                            Color.white.opacity(0.25),
                            .clear,
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .rotationEffect(.degrees(20))
                    .offset(x: CGFloat(glowPhase * 200 - 100))
                    .blendMode(.overlay)
                }
                iconView
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.4), radius: 10, y: 6)
            }
            .frame(height: 88)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(AppTheme.techCardFill)
        }
        .background(Color.black.opacity(0.001))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            accent.opacity(0.6),
                            accent.opacity(0.15),
                            accent.opacity(0.6),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .onAppear {
            guard !reduceMotion else { return }
            // Performance: Slower animation (8s vs 3.5s = 57% slower)
            withAnimation(.linear(duration: 8.0).repeatForever(autoreverses: false)) {
                glowPhase = 1.0
            }
        }
    }

    @ViewBuilder
    private var iconView: some View {
        if let iconURL {
            CachedAsyncImage(url: iconURL) {
                placeholderIcon
            }
        } else {
            placeholderIcon
        }
    }

    private var placeholderIcon: some View {
        Image(systemName: systemIconName)
            .resizable()
            .scaledToFit()
            .padding(13)
            .foregroundStyle(.white)
    }
}

/// Shows a locally cached copy immediately if one exists (so icons still render offline after
/// their first successful load), then refreshes from the network in the background when
/// possible. See RemoteImageCache for the on-disk persistence.
struct CachedAsyncImage<Placeholder: View>: View {
    let url: URL?
    @ViewBuilder let placeholder: () -> Placeholder

    @State private var uiImage: UIImage?

    var body: some View {
        Group {
            if let uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            guard let url else { return }
            if let cached = RemoteImageCache.cachedImage(for: url) {
                uiImage = cached
            }
            if let fresh = await RemoteImageCache.fetchAndCache(url) {
                uiImage = fresh
            }
        }
    }
}

extension Color {
    init?(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, let rgb = UInt32(value, radix: 16) else { return nil }
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}
