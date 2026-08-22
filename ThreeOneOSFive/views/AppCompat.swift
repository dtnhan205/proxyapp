import SwiftUI

// MARK: - AppCompat.swift
//
// Compatibility layer để app hỗ trợ iOS 15.0+ mặc dù codebase dùng nhiều
// API iOS 16+. Mỗi wrapper fallback về API iOS 15 tương đương. Compile-time
// check `if #available(iOS 16.0, *)` không cần vì SwiftUI's @ViewBuilder
// đã hỗ trợ ViewBuilder conditionals.
//
// Lý do không dùng `if #available` inline khắp nơi:
//   - Khó bảo trì: 15+ chỗ phải wrap, dễ quên 1 chỗ → crash im lặng
//   - Khó debug: compiler diagnostics với `if #available` trong @ViewBuilder
//     closure gây confusion cho người mới đọc code
//   - Single source of truth: AppCompat.swift là 1 chỗ duy nhất chứa compat
//
// Mapping iOS 16+ → iOS 15 fallback:
//   NavigationStack       → NavigationView
//   .navigationDestination(isPresented:) → NavigationLink with .fullScreenCover / sheet
//   .scrollContentBackground(.hidden)   → no-op (background mặc định OK trên iOS 15)
//   .scrollDismissesKeyboard(.interactively) → no-op
//   .toolbarBackground(_, for:)         → no-op
//   .toolbarBackground(.visible, for:)  → no-op

/// Wrapper quanh `NavigationStack` / `NavigationView`. Cách dùng:
/// ```swift
/// NavigationStackCompat {
///     ScrollView { ... }
///         .navigationDestinationCompat(isPresented: $showDetail) {
///             DetailView()
///         }
/// }
/// ```
struct NavigationStackCompat<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        if #available(iOS 16.0, *) {
            NavigationStack { content }
        } else {
            NavigationView { content }
        }
    }
}

/// Compatibility cho `.navigationDestination(isPresented:destination:)` (iOS 16+).
/// Trên iOS 15, fallback bằng cách overlay một cover view và bind qua toggle.
///
/// Cách dùng:
/// ```swift
/// NavigationStackCompat {
///     List { ... }
///         .navigationDestinationCompat(isPresented: $showDetail) {
///             DetailView()
///         }
/// }
/// ```
///
/// Lưu ý: trên iOS 15 fallback dùng `.fullScreenCover` thay vì navigation
/// push, nên UX hơi khác (modal full-screen thay vì slide-in từ phải). Đây
/// là giải pháp tạm thời — nếu cần UX navigation đúng chuẩn, refactor
/// từng view sang `NavigationLink { ... }` thuần.
extension View {
    @ViewBuilder
    func navigationDestinationCompat<V: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder destination: () -> V
    ) -> some View {
        if #available(iOS 16.0, *) {
            self.navigationDestination(isPresented: isPresented, destination: destination)
        } else {
            // iOS 15: dùng fullScreenCover. Caller vẫn toggle cùng 1 binding.
            self.fullScreenCover(isPresented: isPresented, content: destination)
        }
    }
}

/// No-op wrapper cho `.scrollContentBackground(.hidden)` (iOS 16+). Trên
/// iOS 15, List/ScrollView không có tint issue nghiêm trọng nên bỏ qua.
extension View {
    @ViewBuilder
    func scrollContentBackgroundCompat() -> some View {
        if #available(iOS 16.0, *) {
            self.scrollContentBackground(.hidden)
        } else {
            self
        }
    }
}

/// No-op wrapper cho `.scrollDismissesKeyboard(.interactively)` (iOS 16+).
extension View {
    @ViewBuilder
    func scrollDismissesKeyboardCompat() -> some View {
        if #available(iOS 16.0, *) {
            self.scrollDismissesKeyboard(.interactively)
        } else {
            self
        }
    }
}

/// No-op wrapper cho `.toolbarBackground(_, for:)` (iOS 16+). Trên iOS 15
/// toolbar background dùng default appearance, chấp nhận được.
extension View {
    @ViewBuilder
    func toolbarBackgroundCompat<Background: ShapeStyle>(
        _ background: Background,
        for bars: ToolbarPlacement
    ) -> some View {
        if #available(iOS 16.0, *) {
            self.toolbarBackground(background, for: bars)
        } else {
            self
        }
    }

    @ViewBuilder
    func toolbarBackgroundCompat(_ visibility: Visibility, for bars: ToolbarPlacement) -> some View {
        if #available(iOS 16.0, *) {
            self.toolbarBackground(visibility, for: bars)
        } else {
            self
        }
    }
}
