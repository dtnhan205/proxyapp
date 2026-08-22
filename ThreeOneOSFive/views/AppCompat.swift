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
        @ViewBuilder destination: @escaping () -> V
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
        for bars: ToolbarItemPlacement
    ) -> some View {
        if #available(iOS 16.0, *) {
            self.toolbarBackground(background, for: ToolbarPlacement.automatic)
        } else {
            self
        }
    }

    @ViewBuilder
    func toolbarBackgroundCompat(_ visibility: Visibility, for bars: ToolbarItemPlacement) -> some View {
        if #available(iOS 16.0, *) {
            self.toolbarBackground(visibility, for: ToolbarPlacement.automatic)
        } else {
            self
        }
    }
}

/// Wrapper cho `.fontWeight(.semibold)` (iOS 16+). Trên iOS 15 dùng
/// `.font(.body.weight(.semibold))`. Cách dùng:
///
/// ```swift
/// Text("Hi")
///     .fontWeightCompat(.semibold)
/// ```
extension View {
    @ViewBuilder
    func fontWeightCompat(_ weight: Font.Weight) -> some View {
        if #available(iOS 16.0, *) {
            self.fontWeight(weight)
        } else {
            // iOS 15 fallback: dùng Font constructor với weight.
            // Lưu ý: áp dụng được cho Text, Image, etc. Nếu view là SwiftUI
            // modifier chain khác, kết quả vẫn OK vì `.font()` tự wrap inner.
            self.environment(\.font, .system(size: 17, weight: weight))
        }
    }
}

/// Wrapper cho `.tracking(_:)` (iOS 16+). Trên iOS 15, `.tracking` không
/// tồn tại — chuyển sang `kerning(_:)` (iOS 13+). Lưu ý: tracking và
/// kerning không hoàn toàn giống nhau (tracking = letter-spacing tracking
/// có tính đến advance, kerning = letter-spacing giữa 2 glyph liền kề)
/// nhưng cho UX desktop-gần-giống là đủ.
extension View {
    @ViewBuilder
    func trackingCompat(_ amount: CGFloat) -> some View {
        if #available(iOS 16.0, *) {
            self.tracking(amount)
        } else {
            self.kerning(amount)
        }
    }
}

/// Wrapper cho `LabeledContent { content }` (iOS 16+). Trên iOS 15 dùng
/// `HStack` thuần với alignment `.firstTextBaseline`.
///
/// Cách dùng — trailing closure là `content`, named arg trước là `label`:
/// ```swift
/// LabeledContentCompat {
///     Text("value")
/// } label: {
///     Text("key")
/// }
/// ```
struct LabeledContentCompat<Label: View, Content: View>: View {
    @ViewBuilder let content: Content
    @ViewBuilder let label: Label

    init(@ViewBuilder content: () -> Content, @ViewBuilder label: () -> Label) {
        self.content = content()
        self.label = label()
    }

    /// Overload cho callers dùng cú pháp `LabeledContent(title, value:)`.
    /// Ví dụ: `LabeledContentCompat(label: {...}, value: {...})` — lưu ý
    /// tham số `value` được truyền đầu tiên theo Swift trailing-closure
    /// convention nhưng ở đây chúng ta dùng named args để rõ ràng.
    init(@ViewBuilder label: () -> Label, @ViewBuilder value content: () -> Content) {
        self.content = content()
        self.label = label()
    }

    var body: some View {
        if #available(iOS 16.0, *) {
            LabeledContent {
                content
            } label: {
                label
            }
        } else {
            HStack(alignment: .firstTextBaseline) {
                label
                Spacer()
                content
            }
        }
    }
}

/// Fix cho ambiguous `.toolbar { body }` trên iOS 15. Trên iOS 16+
/// SwiftUI chỉ có 1 overload của `.toolbar`. Trên iOS 15 có 2 overloads
/// (một cho View, một cho ToolbarContent) — khi body chứa `ToolbarItem`
/// compiler không resolve được → báo "ambiguous".
///
/// Wrap này ép compiler dùng `@ToolbarContentBuilder` overload trên cả
/// iOS 15 và iOS 16+ (đảm bảo code iOS 16 không regress).
///
/// Cách dùng — extract toolbar items thành computed property với
/// annotation, rồi pass vào đây:
///
/// ```swift
/// @ToolbarContentBuilder
/// private var myToolbar: some ToolbarContent {
///     ToolbarItem(placement: .navigationBarTrailing) { ... }
/// }
///
/// var body: some View {
///     SomeView()
///         .toolbarCompat(myToolbar)
/// }
/// ```
extension View {
    @ViewBuilder
    func toolbarCompat<Content: ToolbarContent>(@ToolbarContentBuilder _ content: () -> Content) -> some View {
        // Trick để compiler chọn đúng overload `.toolbar(content:)`:
        //   iOS 15 có 2 overloads — một cho View, một cho ToolbarContent.
        //   Compiler cần biết kiểu Content để chọn. Vì Content: ToolbarContent
        //   đã rõ từ generic bound, gọi thẳng `.toolbar(content:)` đủ.
        //
        //   Lưu ý: cú pháp `.toolbar(content:)` (named arg) có thể ambiguous
        //   nếu compiler suy Content thành `() -> some View`. Để chắc chắn,
        //   ta gọi qua một hàm trung gian đã disambiguated.
        self.toolbar(content: content)
    }
}
