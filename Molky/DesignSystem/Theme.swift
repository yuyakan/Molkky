import SwiftUI
import UIKit

enum Theme {
    // MARK: - Brand palette (Finnish forest + sport)
    /// Deep forest ink — メインのテキスト/背景
    static let ink = Color(red: 0.10, green: 0.13, blue: 0.16)
    /// Birch / paper — 紙のように温かみのある明るい背景
    static let birch = Color(red: 0.98, green: 0.96, blue: 0.91)
    static let birchDeep = Color(red: 0.94, green: 0.91, blue: 0.83)
    /// Wood — スキットルの色
    static let wood = Color(red: 0.88, green: 0.74, blue: 0.50)
    static let woodDeep = Color(red: 0.72, green: 0.55, blue: 0.32)
    /// Pine — 鮮やかなアクセント（フィンランドの森）
    static let pine = Color(red: 0.10, green: 0.55, blue: 0.40)
    static let pineDeep = Color(red: 0.06, green: 0.36, blue: 0.27)
    /// Berry — 注目色
    static let berry = Color(red: 0.92, green: 0.32, blue: 0.40)
    /// Sun — 勝者/ハイライト
    static let sun = Color(red: 1.00, green: 0.75, blue: 0.18)
    /// Sky — 補助色
    static let sky = Color(red: 0.36, green: 0.58, blue: 0.92)

    // Semantic aliases
    static let accent = pine
    static let accentDeep = pineDeep
    static let danger = berry
    static let warning = sun
    static let success = pine

    static let background = birch
    static let groupedBackground = birch
    static let surface = Color.white
    static let surfaceMuted = birchDeep

    static let textPrimary = ink
    static let textSecondary = Color(red: 0.40, green: 0.42, blue: 0.45)

    /// プレイ中の手番カード
    static let currentTurnBackground = ink
    static let currentTurnForeground = birch

    // MARK: - Gradients
    static let accentGradient = LinearGradient(
        colors: [pine, pineDeep],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let woodGradient = LinearGradient(
        colors: [wood, woodDeep],
        startPoint: .top,
        endPoint: .bottom
    )
    static let sunGradient = LinearGradient(
        colors: [sun, Color(red: 0.98, green: 0.55, blue: 0.20)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let inkGradient = LinearGradient(
        colors: [ink, Color(red: 0.16, green: 0.20, blue: 0.24)],
        startPoint: .top,
        endPoint: .bottom
    )

    // MARK: - Participant colors
    static func participantColor(index: Int) -> Color {
        let palette: [Color] = [pine, berry, sky, sun, Color(red: 0.55, green: 0.35, blue: 0.85), Color(red: 0.20, green: 0.65, blue: 0.70)]
        return palette[index % palette.count]
    }

    static func participantGradient(index: Int) -> LinearGradient {
        let c = participantColor(index: index)
        return LinearGradient(
            colors: [c.opacity(0.95), c.opacity(0.7)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Tokens
    enum Radius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 14
        static let large: CGFloat = 22
        static let xLarge: CGFloat = 32
    }

    enum Space {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 36
    }

    // MARK: - iPad用タイポ/サイズトークン
    enum FontSize {
        /// 手番カードの巨大スコア
        static func heroScore(isPad: Bool) -> CGFloat { isPad ? 180 : 96 }
        /// 手番カードの名前
        static func heroName(isPad: Bool) -> CGFloat { isPad ? 56 : 32 }
        /// 手番カードの残り点
        static func heroRemain(isPad: Bool) -> CGFloat { isPad ? 96 : 56 }
        /// プレイヤー行の名前
        static func rowName(isPad: Bool) -> CGFloat { isPad ? 30 : 20 }
        /// プレイヤー行のスコア
        static func rowScore(isPad: Bool) -> CGFloat { isPad ? 52 : 32 }
        /// キーパッド数字
        static func keypadDigit(isPad: Bool) -> CGFloat { isPad ? 52 : 32 }
        /// キーパッドミス/取消テキスト
        static func keypadAction(isPad: Bool) -> CGFloat { isPad ? 28 : 20 }
        /// 結果画面の勝者スコア
        static func resultScore(isPad: Bool) -> CGFloat { isPad ? 140 : 80 }
        /// 結果画面の勝者名
        static func resultName(isPad: Bool) -> CGFloat { isPad ? 64 : 44 }
    }

    enum KeySize {
        /// 数字キー高さ
        static func keypadKey(isPad: Bool) -> CGFloat { isPad ? 88 : 60 }
        /// ミス/取消キー高さ
        static func keypadAction(isPad: Bool) -> CGFloat { isPad ? 88 : 60 }
        /// 行の最小高さ
        static func rowMin(isPad: Bool) -> CGFloat { isPad ? 84 : 60 }
        /// 結果画面アクションバー高さ
        static func resultAction(isPad: Bool) -> CGFloat { isPad ? 80 : 56 }
    }
}

// MARK: - iPad判定ヘルパー
extension UIDevice {
    static var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
}

// MARK: - Skittle Shape
/// モルックのスキットル（ピン）を抽象化した形状。先端が斜めにカットされた縦長角丸。
struct SkittleShape: Shape {
    var cutRatio: CGFloat = 0.18
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        let r: CGFloat = min(w, h) * 0.22
        let cut = h * cutRatio
        // 上から時計回り
        p.move(to: CGPoint(x: rect.minX + r, y: rect.minY + cut))
        // 上辺（斜めカット）
        p.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + r),
                       control: CGPoint(x: rect.maxX, y: rect.minY))
        // 右辺
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - r, y: rect.maxY),
                       control: CGPoint(x: rect.maxX, y: rect.maxY))
        // 下辺
        p.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - r),
                       control: CGPoint(x: rect.minX, y: rect.maxY))
        // 左辺
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r + cut))
        p.addQuadCurve(to: CGPoint(x: rect.minX + r, y: rect.minY + cut),
                       control: CGPoint(x: rect.minX, y: rect.minY + cut))
        p.closeSubpath()
        return p
    }
}

// MARK: - Decorative views

/// 番号付きスキットル（プレイヤー/チーム識別）
struct SkittleBadge: View {
    let number: String
    let color: Color
    var size: CGFloat = 44
    var body: some View {
        ZStack {
            SkittleShape()
                .fill(
                    LinearGradient(colors: [color, color.opacity(0.75)], startPoint: .top, endPoint: .bottom)
                )
                .frame(width: size * 0.72, height: size)
            // 上部の白いラベル帯（モルック・スキットルの番号帯を模倣）
            VStack(spacing: 0) {
                Spacer().frame(height: size * 0.20)
                Rectangle()
                    .fill(Color.white.opacity(0.96))
                    .frame(width: size * 0.72, height: size * 0.34)
                    .overlay(
                        Text(number)
                            .font(.system(size: size * 0.26, weight: .black, design: .rounded).monospacedDigit())
                            .foregroundStyle(Theme.ink)
                    )
                Spacer()
            }
            .frame(width: size * 0.72, height: size)
        }
        .frame(width: size * 0.72, height: size)
        .shadow(color: Color.black.opacity(0.18), radius: 4, y: 2)
    }
}

/// ドットグリッドの装飾レイヤー（ヘッダー背景など）
struct DotGrid: View {
    var color: Color
    var spacing: CGFloat = 14
    var dot: CGFloat = 2
    var body: some View {
        Canvas { ctx, size in
            let cols = Int(size.width / spacing) + 1
            let rows = Int(size.height / spacing) + 1
            for r in 0..<rows {
                for c in 0..<cols {
                    let rect = CGRect(
                        x: CGFloat(c) * spacing,
                        y: CGFloat(r) * spacing,
                        width: dot,
                        height: dot
                    )
                    ctx.fill(Path(ellipseIn: rect), with: .color(color))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// 角の一部を切り取った"チケット"風カード
struct TicketCard<Content: View>: View {
    var content: Content
    var accent: Color = Theme.pine
    init(accent: Color = Theme.pine, @ViewBuilder content: () -> Content) {
        self.accent = accent
        self.content = content()
    }
    private var isPad: Bool { UIDevice.isPad }
    var body: some View {
        content
            .padding(isPad ? Theme.Space.xl : Theme.Space.l)
            .background(
                ZStack(alignment: .topLeading) {
                    UnevenRoundedRectangle(
                        topLeadingRadius: Theme.Radius.xLarge,
                        bottomLeadingRadius: Theme.Radius.large,
                        bottomTrailingRadius: Theme.Radius.large,
                        topTrailingRadius: Theme.Radius.large
                    )
                    .fill(Theme.surface)
                    Rectangle()
                        .fill(accent)
                        .frame(width: 6)
                        .clipShape(UnevenRoundedRectangle(
                            topLeadingRadius: Theme.Radius.xLarge,
                            bottomLeadingRadius: Theme.Radius.large,
                            bottomTrailingRadius: 0,
                            topTrailingRadius: 0
                        ))
                }
            )
            .overlay(
                UnevenRoundedRectangle(
                    topLeadingRadius: Theme.Radius.xLarge,
                    bottomLeadingRadius: Theme.Radius.large,
                    bottomTrailingRadius: Theme.Radius.large,
                    topTrailingRadius: Theme.Radius.large
                )
                .stroke(Theme.ink.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: Theme.ink.opacity(0.06), radius: 12, y: 6)
    }
}

/// セクション見出し（数字番号付き）
struct SectionHeader: View {
    let number: Int
    let title: String
    var trailing: AnyView? = nil
    private var isPad: Bool { UIDevice.isPad }
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Space.s) {
            Text(title)
                .font(.system(isPad ? .title : .title3, design: .rounded).weight(.heavy))
                .foregroundStyle(Theme.ink)
            Spacer()
            trailing
        }
    }
}

/// 統一のプライマリボタン形状
struct PrimaryActionStyle: ButtonStyle {
    var fill: AnyShapeStyle = AnyShapeStyle(Theme.accentGradient)
    var shadowColor: Color = Theme.pine.opacity(0.35)
    func makeBody(configuration: Configuration) -> some View {
        let isPad = UIDevice.isPad
        return configuration.label
            .padding(.horizontal, Theme.Space.l)
            .frame(maxWidth: .infinity, minHeight: isPad ? 84 : 60)
            .background(
                UnevenRoundedRectangle(
                    topLeadingRadius: Theme.Radius.large,
                    bottomLeadingRadius: Theme.Radius.small,
                    bottomTrailingRadius: Theme.Radius.large,
                    topTrailingRadius: Theme.Radius.small
                )
                .fill(fill)
            )
            .foregroundStyle(.white)
            .shadow(color: shadowColor, radius: isPad ? 20 : 14, y: isPad ? 8 : 6)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct GhostActionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, Theme.Space.l)
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(
                UnevenRoundedRectangle(
                    topLeadingRadius: Theme.Radius.large,
                    bottomLeadingRadius: Theme.Radius.small,
                    bottomTrailingRadius: Theme.Radius.large,
                    topTrailingRadius: Theme.Radius.small
                )
                .strokeBorder(Theme.ink.opacity(0.25), lineWidth: 1.5)
            )
            .foregroundStyle(Theme.ink)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Brand wordmark
struct Wordmark: View {
    var size: CGFloat = 32
    var body: some View {
        HStack(spacing: 2) {
            Text("MÖL")
                .font(.system(size: size, weight: .black, design: .rounded))
                .foregroundStyle(Theme.ink)
            Text("KKY")
                .font(.system(size: size, weight: .black, design: .rounded))
                .foregroundStyle(Theme.pine)
            Circle()
                .fill(Theme.berry)
                .frame(width: size * 0.18, height: size * 0.18)
                .offset(y: size * 0.28)
        }
    }
}
