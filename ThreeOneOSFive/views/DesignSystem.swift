import SwiftUI

// MARK: - Cyberpunk Neon Palette
enum AppTheme {
    /// Primary accent: electric cyan, the dominant neon of the cyberpunk palette.
    static let neonCyan = Color(red: 0.00, green: 0.95, blue: 1.00)
    /// Slightly cooler cyan used for backlights and borders.
    static let neonIce = Color(red: 0.55, green: 1.00, blue: 1.00)
    /// Hot magenta accent for highlights, errors and active toggles.
    static let neonMagenta = Color(red: 1.00, green: 0.10, blue: 0.65)
    /// Acid lime accent for "success" or "running" indicators.
    static let neonLime = Color(red: 0.65, green: 1.00, blue: 0.20)
    /// Warm neon amber, used as legacy accent on the few places we still highlight non-toggle rows.
    static let neonAmber = Color(red: 1.00, green: 0.78, blue: 0.20)
    /// Deep violet used as a tertiary accent (rare).
    static let neonViolet = Color(red: 0.55, green: 0.30, blue: 1.00)

    /// Background anchor used by `.preferredColorScheme(.dark)` callers — kept for legacy code.
    static let accent = neonCyan
    static let pageBackground = Color(red: 0.02, green: 0.04, blue: 0.08)
    static let consoleBackground = Color(red: 0.04, green: 0.07, blue: 0.12)
    static let pageInset: CGFloat = 16

    // MARK: - Cyberpunk backdrop gradient (Home / per-game menu screens)
    static let techBackgroundTop = Color(red: 0.03, green: 0.06, blue: 0.12)
    static let techBackgroundMid = Color(red: 0.01, green: 0.02, blue: 0.06)
    static let techBackgroundBottom = Color(red: 0.00, green: 0.00, blue: 0.03)

    /// Glow that sits behind cards to make them feel like floating holograms.
    static let techGlow = neonCyan
    /// Card fill — a translucent slate-blue, slightly cooler than the background.
    static let techCardFill = Color.white.opacity(0.04)
    /// Card border — a dim neon line that lights up on focus.
    static let techCardStroke = neonCyan.opacity(0.35)

    /// Per-row accent cycled across list items so each toggle has its own neon color, like the
    /// "PROXY MOD MENU" reference design.
    static let rowPalette: [Color] = [
        neonAmber,
        neonMagenta,
        neonCyan,
        neonViolet,
        neonLime,
    ]

    static func rowColor(_ index: Int) -> Color {
        rowPalette[index % rowPalette.count]
    }
}

// MARK: - Cyberpunk Backdrop

/// The animated cyberpunk backdrop. A vertical gradient sits below a scrolling grid pattern and
/// a slowly pulsing magenta/cyan radial glow. A horizontal scanline bar drifts down forever,
/// giving the surface a CRT/hologram feel.
struct TechBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scanlineY: CGFloat = -0.25
    @State private var glowPhase: Double = 0

    var body: some View {
        ZStack {
            // Base vertical gradient
            LinearGradient(
                colors: [
                    AppTheme.techBackgroundTop,
                    AppTheme.techBackgroundMid,
                    AppTheme.techBackgroundBottom,
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Soft dotted matrix (replaces the previous checkerboard-like grid) — masked with a
            // radial fade so the dots fade out toward the edges instead of tiling uniformly.
            TechDotMatrixCanvas()
                .opacity(0.85)
                .mask(
                    RadialGradient(
                        colors: [.white, .white, .clear],
                        center: .center,
                        startRadius: 80,
                        endRadius: 480
                    )
                )

            // Diagonal accent lines, animated to drift sideways slowly.
            TechDiagonalLines()
                .stroke(AppTheme.neonMagenta.opacity(0.05), lineWidth: 1)
                .blur(radius: 0.5)

            // Pulsing radial glow at the top, mixing cyan and magenta.
            RadialGradient(
                colors: [
                    AppTheme.neonCyan.opacity(0.20),
                    AppTheme.neonMagenta.opacity(0.06),
                    .clear,
                ],
                center: .top,
                startRadius: 0,
                endRadius: 520
            )
            .opacity(reduceMotion ? 1.0 : (0.85 + 0.15 * sin(glowPhase)))
            .blendMode(.screen)

            // Drifting scanline that travels down the screen continuously.
            GeometryReader { geo in
                ScanlineBar()
                    .fill(
                        LinearGradient(
                            colors: [
                                .clear,
                                AppTheme.neonCyan.opacity(0.18),
                                AppTheme.neonIce.opacity(0.35),
                                AppTheme.neonCyan.opacity(0.18),
                                .clear,
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 90)
                    .offset(y: scanlineY * geo.size.height)
                    .blendMode(.screen)
            }

            // Fine horizontal scanline overlay (CRT texture) — kept static for performance.
            TechScanlineOverlay()
                .fill(Color.white.opacity(0.02))
        }
        .ignoresSafeArea()
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 7.5).repeatForever(autoreverses: false)) {
                scanlineY = 1.25
            }
            withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) {
                glowPhase = .pi
            }
        }
    }
}

/// A canvas that draws a uniform dot matrix — replaces the previous hard grid so the
/// background reads as a soft starfield / circuit-board rather than a square tile.
private struct TechDotMatrixCanvas: View {
    var spacing: CGFloat = 24
    var dotRadius: CGFloat = 0.9

    // Subtle accent dots in cyan + magenta, scattered sparsely (every 5 cells along each axis)
    // to add visual depth — so the matrix isn't a perfectly regular grid.
    private func isAccent(row: Int, col: Int) -> Bool {
        (row % 5 == 0 && col % 7 == 0) || (row % 7 == 0 && col % 5 == 0)
    }

    var body: some View {
        Canvas { context, size in
            var col = 0
            var x: CGFloat = spacing / 2
            while x <= size.width {
                var row = 0
                var y: CGFloat = spacing / 2
                while y <= size.height {
                    let isAccentDot = isAccent(row: row, col: col)
                    let radius = isAccentDot ? 1.6 : dotRadius
                    let color = isAccentDot
                        ? AppTheme.neonMagenta.opacity(0.28)
                        : AppTheme.neonCyan.opacity(0.18)
                    let rect = CGRect(
                        x: x - radius,
                        y: y - radius,
                        width: radius * 2,
                        height: radius * 2
                    )
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(color)
                    )
                    y += spacing
                    row += 1
                }
                x += spacing
                col += 1
            }
        }
    }
}

private struct TechDiagonalLines: Shape {
    var spacing: CGFloat = 22

    func path(in rect: CGRect) -> Path {
        var path = Path()
        var x: CGFloat = -rect.height
        while x <= rect.width {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x + rect.height, y: rect.height))
            x += spacing
        }
        return path
    }
}

private struct TechScanlineOverlay: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        var y: CGFloat = 0
        while y <= rect.height {
            path.addRect(CGRect(x: 0, y: y, width: rect.width, height: 1))
            y += 3
        }
        return path
    }
}

private struct ScanlineBar: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRoundedRect(in: rect, cornerSize: CGSize(width: 40, height: 40))
        return path
    }
}

// MARK: - Neon Card Style

private struct TechCardStyle: ViewModifier {
    var glowColor: Color = AppTheme.neonCyan
    var glowOpacity: Double = 0.12

    func body(content: Content) -> some View {
        content
            .background(AppTheme.techCardFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                glowColor.opacity(0.45),
                                glowColor.opacity(0.18),
                                glowColor.opacity(0.45),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: glowColor.opacity(glowOpacity), radius: 14, y: 0)
    }
}

extension View {
    func techCard(glow: Color = AppTheme.neonCyan, opacity: Double = 0.12) -> some View {
        modifier(TechCardStyle(glowColor: glow, glowOpacity: opacity))
    }
}

// MARK: - Toast

struct ToastMessage: Identifiable, Equatable {
    let id = UUID()
    var text: String
}

/// A brief, self-dismissing confirmation pill (e.g. "Đã bật Auto Aim Fix") shown after a
/// successful toggle, so a patch flip has clear positive feedback without the interruption of
/// a blocking alert (alerts stay reserved for failures).
private struct ToastOverlay: ViewModifier {
    @Binding var toast: ToastMessage?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let toast {
                    HStack(spacing: 9) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(AppTheme.neonLime)
                        Text(toast.text)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(
                        Capsule().strokeBorder(AppTheme.neonCyan.opacity(0.55), lineWidth: 1)
                    )
                    .shadow(color: AppTheme.neonCyan.opacity(0.35), radius: 20, y: 6)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .id(toast.id)
                    .task(id: toast.id) {
                        try? await Task.sleep(nanoseconds: 2_200_000_000)
                        if self.toast?.id == toast.id {
                            self.toast = nil
                        }
                    }
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.78), value: toast)
    }
}

extension View {
    func toast(_ message: Binding<ToastMessage?>) -> some View {
        modifier(ToastOverlay(toast: message))
    }
}

// MARK: - Neon App Logo

struct AppLogo: View {
    var size: CGFloat = 44

    var body: some View {
        Group {
            if let icon = UIImage(named: "AppIcon60x60")
                ?? Bundle.main.path(forResource: "AppIcon60x60@2x", ofType: "png").flatMap(UIImage.init(contentsOfFile:))
                ?? UIImage(named: "AppIcon") {
                Image(uiImage: icon)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "slider.horizontal.3")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(
                        LinearGradient(
                            colors: [AppTheme.neonCyan, AppTheme.neonMagenta],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .strokeBorder(AppTheme.neonCyan.opacity(0.6), lineWidth: 1)
        )
        .shadow(color: AppTheme.neonCyan.opacity(0.45), radius: 8, y: 0)
        .accessibilityHidden(true)
    }
}

// MARK: - Neon Section Header

/// A small uppercase section title styled like a cyberpunk HUD: a vertical neon bar on the left,
/// tracked-out caps text, and a thin glowing underline.
struct NeonSectionHeader: View {
    let title: String
    var tint: Color = AppTheme.neonCyan
    var symbol: String? = nil

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(tint)
                .frame(width: 3, height: 16)
                .shadow(color: tint.opacity(0.7), radius: 4)
            if let symbol = symbol {
                Image(systemName: symbol)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(tint)
            }
            Text(title)
                .font(.subheadline.weight(.heavy))
                .textCase(.uppercase)
                .tracking(0.6)
                .foregroundStyle(.primary)
            Spacer()
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [tint.opacity(0.6), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 0.5)
                .offset(y: -2)
        }
    }
}

// MARK: - Neon Toggle

/// A bespoke neon toggle styled for the cyberpunk theme. The track is a translucent neon capsule
/// that fills with a cyan→magenta gradient when on, and a dim grey when off. The knob is a small
/// glowing disc.
struct NeonToggleStyle: ToggleStyle {
    var onColor: Color = AppTheme.neonCyan
    var offColor: Color = Color.white.opacity(0.18)

    func makeBody(configuration: Configuration) -> some View {
        let isOn = configuration.isOn
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                configuration.isOn.toggle()
            }
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(
                        isOn
                            ? LinearGradient(
                                colors: [onColor.opacity(0.85), AppTheme.neonMagenta.opacity(0.55)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            : LinearGradient(
                                colors: [offColor, offColor.opacity(0.5)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                    )
                    .frame(width: 48, height: 28)
                    .overlay(
                        Capsule()
                            .strokeBorder(
                                (isOn ? onColor : Color.white.opacity(0.25)).opacity(0.7),
                                lineWidth: 1
                            )
                    )
                    .shadow(
                        color: isOn ? onColor.opacity(0.65) : .clear,
                        radius: isOn ? 8 : 0
                    )

                Circle()
                    .fill(Color.white)
                    .frame(width: 22, height: 22)
                    .shadow(
                        color: isOn ? onColor.opacity(0.8) : .clear,
                        radius: isOn ? 6 : 0
                    )
                    .padding(3)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(configuration.isOn ? "On" : "Off")
    }
}

extension View {
    /// Convenience to apply the cyberpunk neon style with a chosen accent color on a Toggle.
    /// Placed on `View` rather than `Toggle` because `.labelsHidden()` returns `some View`,
    /// so the call site no longer has a concrete `Toggle` to dispatch to.
    func neonToggleTint(_ color: Color = AppTheme.neonCyan) -> some View {
        self.toggleStyle(NeonToggleStyle(onColor: color))
    }
}

// MARK: - Pulsing Dot

/// A small dot that pulses in size and opacity, used as a "live / syncing" indicator.
struct PulsingDot: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var color: Color = AppTheme.neonLime
    var size: CGFloat = 8

    @State private var pulse: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.35))
                .frame(width: size * 2.4, height: size * 2.4)
                .scaleEffect(reduceMotion ? 1.0 : CGFloat(1.0 + pulse * 0.6))
                .opacity(reduceMotion ? 0.35 : (0.55 - pulse * 0.45))
            Circle()
                .fill(color)
                .frame(width: size, height: size)
                .shadow(color: color.opacity(0.8), radius: 4)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 1.1).repeatForever(autoreverses: false)) {
                pulse = 1.0
            }
        }
    }
}

// MARK: - Neon Button

/// A bordered neon button that lights up the border and casts a glow when pressed/hovered.
struct NeonButtonStyle: ButtonStyle {
    var tint: Color = AppTheme.neonCyan

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .foregroundStyle(tint)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(tint.opacity(configuration.isPressed ? 0.18 : 0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(tint.opacity(configuration.isPressed ? 0.95 : 0.55), lineWidth: 1)
            )
            .shadow(color: tint.opacity(configuration.isPressed ? 0.5 : 0.25), radius: configuration.isPressed ? 10 : 6)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == NeonButtonStyle {
    static var neon: NeonButtonStyle { NeonButtonStyle() }
}

extension View {
    /// Convenience to apply the cyberpunk neon style to a Button.
    /// Placed on `View` rather than `Button` because `.buttonStyle(.plain)` returns `some View`,
    /// so the call site no longer has a concrete `Button` to dispatch to.
    func neonButtonTint(_ color: Color = AppTheme.neonCyan) -> some View {
        self.buttonStyle(NeonButtonStyle(tint: color))
    }
}

// MARK: - Glitch Text

/// Occasional subtitle text styled in monospaced neon caps — like a HUD readout.
struct NeonReadout: View {
    let text: String
    var tint: Color = AppTheme.neonCyan

    var body: some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .tracking(1.6)
            .textCase(.uppercase)
            .foregroundStyle(tint)
            .shadow(color: tint.opacity(0.6), radius: 4)
    }
}

/// Thay thế dòng text "X replacement rules" — đếm số lượng rule bằng một thanh
/// mỏng có ánh sáng neon lướt qua liên tục. Độ rộng thanh tỉ lệ với count để
/// giữ lại thông tin "nhiều hay ít rule", còn con số thì không hiện ra text.
struct NeonShimmerBar: View {
    let count: Int
    var tint: Color = AppTheme.neonCyan
    @State private var phase: CGFloat = -0.5

    private let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    /// Độ rộng thanh: scale theo count, tối đa 110pt.
    private var width: CGFloat {
        let base: CGFloat = 28
        let extra = CGFloat(min(count, 12)) * 6.5
        return min(base + extra, 110)
    }

    var body: some View {
        ZStack(alignment: .leading) {
            // Track mờ bên dưới — cho thấy "có thứ gì đó đang đo".
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(tint.opacity(0.10))
                .frame(width: width, height: 4)

            // Segment phát sáng dịch theo phase.
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [tint.opacity(0.0), tint.opacity(0.95), tint.opacity(0.0)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: width * 0.55, height: 4)
                .offset(x: phase * width)
                .shadow(color: tint.opacity(0.85), radius: 6)

            // Hạt sáng nhỏ ở đầu — đi cùng segment.
            Circle()
                .fill(tint)
                .frame(width: 4, height: 4)
                .offset(x: phase * width + (width * 0.275))
                .shadow(color: tint, radius: 4)
        }
        .frame(width: width, height: 4)
        .onReceive(timer) { _ in
            phase += 0.04
            if phase > 1.5 { phase = -0.5 }
        }
        .accessibilityLabel(Text("\(count) replacement rules"))
    }
}

/// Chọn ngẫu nhiên icon SF Symbol cho một patch dựa vào id ổn định của nó.
/// Mỗi lần build server trả về nhiều patch, mỗi row sẽ hiện một icon khác
/// nhau nhưng cố định theo id (không bị đổi khi redraw).
enum PatchIconCatalog {
    static let symbols: [String] = [
        "bolt.fill",
        "sparkles",
        "wand.and.stars",
        "shield.lefthalf.filled",
        "cpu.fill",
        "bolt.shield.fill",
        "scope",
        "target",
        "diamond.fill",
        "hexagon.fill",
        "atom",
        "rays",
        "flame.fill",
        "snowflake",
        "burst.fill",
        "circle.hexagongrid.fill",
        "bolt.horizontal.fill",
        "gamecontroller.fill",
        "trophy.fill",
        "star.fill",
        "shield.fill",
        "bolt.ring.closed",
        "ladybug.fill",
        "cross.case.fill",
    ]

    /// Hash id của patch thành index ổn định → icon cố định.
    static func symbol(for id: UUID) -> String {
        let bytes = id.uuidString.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        let idx = abs(bytes) % symbols.count
        return symbols[idx]
    }
}
