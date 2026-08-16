import SwiftUI

/// Overlay phủ toàn màn hình khi server trả `build_revoked` / `build_unknown`.
/// Block toàn bộ tương tác — không có nút đóng, không thể bấm ra ngoài.
/// Persist qua UserDefaults nên thoát ra vào lại vẫn thấy cho tới khi admin
/// add token mới trên server.
struct BuildBlockedOverlay: View {
    @State private var pulse = false

    var body: some View {
        ZStack {
            // Backdrop blur + dim, không thể tương tác với view bên dưới.
            Color.black.opacity(0.92)
                .ignoresSafeArea()

            VStack(spacing: 22) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 78, weight: .bold))
                    .foregroundStyle(.yellow)
                    .scaleEffect(pulse ? 1.08 : 0.96)
                    .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: pulse)

                Text(Language.text("build.blocked_title"))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(Language.text("build.blocked_body"))
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)

                Text(Language.text("build.blocked_hint"))
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
            }
            .padding(40)
        }
        .onAppear { pulse = true }
        // Catch-all: chặn tap, swipe, gesture. Lớp overlay ở RootView nên đã
        // chặn, nhưng thêm `allowsHitTesting(false)` cho chắc.
        .allowsHitTesting(true)
    }
}