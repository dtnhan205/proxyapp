import SwiftUI

struct LogView: View {
    @ObservedObject var appLog = AppLog.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.appLanguage) private var language

    var body: some View {
        NavigationStack {
            ZStack {
                TechBackground()
                Group {
                    if appLog.entries.isEmpty {
                        VStack(spacing: 14) {
                            Image(systemName: "apple.terminal")
                                .font(.system(size: 38, weight: .medium))
                                .foregroundStyle(AppTheme.neonCyan)
                                .shadow(color: AppTheme.neonCyan.opacity(0.5), radius: 8)
                            Text(language.text("logs.empty_title"))
                                .font(.title3.bold())
                            Text(language.text("logs.empty_message"))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(32)
                    } else {
                        ScrollViewReader { proxy in
                            ScrollView {
                                LazyVStack(alignment: .leading, spacing: 0) {
                                    ForEach(Array(appLog.entries.enumerated()), id: \.offset) { index, entry in
                                        VStack(spacing: 0) {
                                            Text(entry)
                                                .font(.system(.caption, design: .monospaced))
                                                .foregroundStyle(AppTheme.neonCyan)
                                                .textSelection(.enabled)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(.vertical, 11)

                                            if index < appLog.entries.count - 1 {
                                                Rectangle()
                                                    .fill(
                                                        LinearGradient(
                                                            colors: [
                                                                AppTheme.neonCyan.opacity(0.3),
                                                                .clear,
                                                                AppTheme.neonCyan.opacity(0.3),
                                                            ],
                                                            startPoint: .leading,
                                                            endPoint: .trailing
                                                        )
                                                    )
                                                    .frame(height: 0.5)
                                            }
                                        }
                                        .id(index)
                                        .accessibilityLabel(language.text("accessibility.log_entry", Int64(index + 1), entry))
                                    }
                                }
                                .padding(AppTheme.pageInset)
                            }
                            .onChange(of: appLog.entries.count) { count in
                                guard count > 0 else { return }
                                if reduceMotion {
                                    proxy.scrollTo(count - 1, anchor: .bottom)
                                } else {
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        proxy.scrollTo(count - 1, anchor: .bottom)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(language.text("logs.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.techBackgroundTop.opacity(0.6), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(language.text("logs.clear"), role: .destructive) { appLog.entries.removeAll() }
                        .foregroundStyle(AppTheme.neonMagenta)
                        .disabled(appLog.entries.isEmpty)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(language.text("common.done")) { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(AppTheme.neonCyan)
                }
            }
        }
    }
}
