import SwiftUI

/// 初回起動時に「最初の広告枠」の代わりに表示するカスタムのレビュー誘導ダイアログ。
/// StoreKit の標準ダイアログは表示が OS 任せで確実に出ないため、
/// 自前の UI を確実に表示し、「レビューを書く」から App Store のレビュー投稿画面へ誘導する。
struct ReviewPromptView: View {
    /// 「レビューを書く」を押したとき（App Store を開く）
    let onWriteReview: () -> Void
    /// 「あとで」を押した、または背景タップで閉じたとき
    let onDismiss: () -> Void

    @State private var appear = false
    private var isPad: Bool { UIDevice.isPad }

    var body: some View {
        ZStack {
            // 背景の暗幕（タップで閉じる）
            Color.black.opacity(appear ? 0.45 : 0)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            card
                .scaleEffect(appear ? 1 : 0.9)
                .opacity(appear ? 1 : 0)
                .padding(.horizontal, Theme.Space.xl)
                .frame(maxWidth: isPad ? 460 : 360)
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                appear = true
            }
        }
    }

    private var card: some View {
        VStack(spacing: isPad ? Theme.Space.xl : Theme.Space.l) {
            // ⭐️ 5つ星
            HStack(spacing: isPad ? 8 : 6) {
                ForEach(0..<5, id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .font(.system(size: isPad ? 34 : 26, weight: .black))
                        .foregroundStyle(Theme.sunGradient)
                }
            }
            .shadow(color: Theme.sun.opacity(0.35), radius: 6, y: 3)

            VStack(spacing: Theme.Space.s) {
                Wordmark(size: isPad ? 34 : 28)
                Text("楽しんでいただけていますか？")
                    .font(.system(isPad ? .title2 : .title3, design: .rounded).weight(.heavy))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                Text("レビューであなたの感想を聞かせてください。アプリの改善にとても役立ちます。")
                    .font(.system(isPad ? .body : .subheadline, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: Theme.Space.s) {
                Button {
                    onWriteReview()
                } label: {
                    HStack(spacing: Theme.Space.s) {
                        Image(systemName: "square.and.pencil")
                            .font(isPad ? .title3 : .headline)
                        Text("レビューを書く")
                            .font(.system(isPad ? .title3 : .headline, design: .rounded).weight(.heavy))
                    }
                }
                .buttonStyle(PrimaryActionStyle(
                    fill: AnyShapeStyle(Theme.sunGradient),
                    shadowColor: Theme.sun.opacity(0.4)
                ))

                Button {
                    onDismiss()
                } label: {
                    Text("あとで")
                        .font(.system(isPad ? .body : .subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: isPad ? 52 : 44)
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
        .padding(isPad ? Theme.Space.xxl : Theme.Space.xl)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.xLarge, style: .continuous)
                .fill(Theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.xLarge, style: .continuous)
                .stroke(Theme.ink.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: Theme.ink.opacity(0.25), radius: 24, y: 12)
    }
}
