import SwiftUI

struct SettingsView: View {
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var appState: AppState
    @AppStorage(AppLanguage.storageKey) private var languageCode = AppLanguage.vietnamese.rawValue

    var body: some View {
        ZStack {
            TechBackground()

            ScrollView {
                VStack(spacing: 18) {
                    profileCard
                    deviceCard
                    verifiedCard
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
        }
        .tint(AppTheme.neonCyan)
        .navigationTitle(language.text("settings.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppTheme.techBackgroundTop.opacity(0.6), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    private var profileCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                PulsingDot(color: AppTheme.neonLime, size: 6)
                NeonReadout(text: "USER PROFILE", tint: AppTheme.neonLime)
            }
            HStack(spacing: 14) {
                AppLogo()

                VStack(alignment: .leading, spacing: 3) {
                    Text("TheNhanCheat")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(language.text("common.version", appVersion))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .padding(16)
        .techCard(glow: AppTheme.neonCyan, opacity: 0.15)
    }

    private var deviceCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            NeonSectionHeader(title: language.text("common.device").uppercased(), tint: AppTheme.neonCyan, symbol: "iphone.gen3")
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                cyberRow(label: language.text("dashboard.hardware_model"), value: AppInfo.displayMachineName, accent: AppTheme.neonCyan)
                cyberDivider()
                cyberRow(
                    label: language.text("settings.ios_version"),
                    value: "\(AppInfo.osVersion) (\(AppInfo.osBuild))",
                    accent: AppTheme.neonMagenta
                )
            }
            .padding(.bottom, 14)
        }
        .techCard(glow: AppTheme.neonCyan, opacity: 0.12)
    }

    private var verifiedCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            NeonSectionHeader(title: language.text("settings.verified_versions").uppercased(), tint: AppTheme.neonMagenta, symbol: "checkmark.shield.fill")
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                HStack {
                    Text(language.text("settings.current_version"))
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    Spacer()
                    HStack(spacing: 6) {
                        PulsingDot(
                            color: appState.isSupported ? AppTheme.neonLime : AppTheme.neonMagenta,
                            size: 6
                        )
                        Text(language.text(appState.isSupported ? "settings.supported" : "settings.unsupported"))
                            .font(.caption.weight(.bold))
                            .tracking(1.0)
                            .textCase(.uppercase)
                            .foregroundStyle(appState.isSupported ? AppTheme.neonLime : AppTheme.neonMagenta)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(
                        (appState.isSupported ? AppTheme.neonLime : AppTheme.neonMagenta).opacity(0.12),
                        in: Capsule()
                    )
                    .overlay(
                        Capsule().strokeBorder(
                            (appState.isSupported ? AppTheme.neonLime : AppTheme.neonMagenta).opacity(0.5),
                            lineWidth: 1
                        )
                    )
                }
                .padding(.vertical, 10)

                cyberDivider()

                cyberRow(
                    label: "iOS 16",
                    value: ExploitSupportPolicy.verifiedIOS16Range,
                    accent: AppTheme.neonAmber,
                    monospace: true
                )
                cyberDivider()
                cyberRow(
                    label: "iOS 17",
                    value: ExploitSupportPolicy.verifiedIOS17Range,
                    accent: AppTheme.neonCyan,
                    monospace: true
                )
                cyberDivider()
                cyberRow(
                    label: "iOS 18",
                    value: ExploitSupportPolicy.verifiedIOS18Range,
                    accent: AppTheme.neonCyan,
                    monospace: true
                )
                cyberDivider()
                cyberRow(
                    label: "iOS 26",
                    value: ExploitSupportPolicy.verifiedIOS26Range,
                    accent: AppTheme.neonCyan,
                    monospace: true
                )
                cyberDivider()
                VStack(alignment: .leading, spacing: 6) {
                    Text("iOS 27.0")
                        .font(.body)
                        .foregroundStyle(.primary)
                    ForEach(ExploitSupportPolicy.verifiedIOS27Builds, id: \.build) { version in
                        Text(
                            language.text(
                                "settings.beta_build",
                                Int64(version.beta),
                                version.build
                            )
                        )
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            Text(language.text("settings.supported_versions_footer"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
        }
        .techCard(glow: AppTheme.neonMagenta, opacity: 0.12)
    }

    private func cyberRow(label: String, value: String, accent: Color, monospace: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Spacer()
            Text(value)
                .font(monospace ? Font.subheadline.monospaced() : Font.subheadline.weight(.semibold))
                .foregroundStyle(accent)
                .shadow(color: accent.opacity(0.4), radius: 4)
        }
        .padding(.vertical, 10)
    }

    private func cyberDivider() -> some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        AppTheme.neonCyan.opacity(0.4),
                        .clear,
                        AppTheme.neonCyan.opacity(0.4),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 0.5)
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "AppReleaseDisplayVersion") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "1.0"
    }
}
