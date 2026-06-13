import SwiftUI
import UIKit

struct Keypad: View {
    let onTap: (Int) -> Void
    let onUndo: () -> Void
    let canUndo: Bool

    private let columns = [
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6)
    ]

    var body: some View {
        VStack(spacing: 6) {
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(1...12, id: \.self) { n in
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onTap(n)
                    } label: {
                        numberKey(n)
                    }
                    .buttonStyle(KeyPressStyle())
                    .accessibilityLabel(Text("\(n)点"))
                }
            }

            HStack(spacing: 6) {
                Button {
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                    onTap(0)
                } label: {
                    missKey
                }
                .buttonStyle(KeyPressStyle())
                .accessibilityLabel(Text("ミス、0点"))

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onUndo()
                } label: {
                    undoKey
                }
                .buttonStyle(KeyPressStyle())
                .disabled(!canUndo)
                .opacity(canUndo ? 1 : 0.45)
                .accessibilityLabel(Text("元に戻す"))
            }
        }
    }

    private func numberKey(_ n: Int) -> some View {
        ZStack(alignment: .topLeading) {
            UnevenRoundedRectangle(
                topLeadingRadius: 16,
                bottomLeadingRadius: 6,
                bottomTrailingRadius: 16,
                topTrailingRadius: 6
            )
            .fill(Theme.surface)
            .overlay(
                UnevenRoundedRectangle(
                    topLeadingRadius: 16,
                    bottomLeadingRadius: 6,
                    bottomTrailingRadius: 16,
                    topTrailingRadius: 6
                )
                .strokeBorder(Theme.ink.opacity(0.10), lineWidth: 1)
            )
            // 上左の角に小さなドット（独自アクセント）
            Circle()
                .fill(numberAccent(n))
                .frame(width: 6, height: 6)
                .padding(8)
            Text("\(n)")
                .font(.system(size: 32, weight: .black, design: .rounded).monospacedDigit())
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: 60)
        .shadow(color: Theme.ink.opacity(0.05), radius: 3, y: 2)
    }

    private func numberAccent(_ n: Int) -> Color {
        // 視覚的グルーピング: 低/中/高で色分け
        switch n {
        case 1...4: return Theme.pine
        case 5...8: return Theme.sky
        case 9...12: return Theme.berry
        default: return Theme.textSecondary
        }
    }

    private var missKey: some View {
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: 22,
            bottomLeadingRadius: 8,
            bottomTrailingRadius: 22,
            topTrailingRadius: 8
        )
        return ZStack {
            shape.fill(
                LinearGradient(
                    colors: [Theme.berry, Color(red: 0.75, green: 0.20, blue: 0.30)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            // 装飾の倒れたスキットル（右下に流す）
            GeometryReader { geo in
                SkittleShape()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 50, height: 76)
                    .rotationEffect(.degrees(72))
                    .position(x: geo.size.width - 30, y: geo.size.height - 4)
            }
            .clipShape(shape)
            .allowsHitTesting(false)

            // テキストは中央配置
            HStack(spacing: 8) {
                Image(systemName: "xmark")
                    .font(.system(size: 22, weight: .black))
                Text("ミス")
                    .font(.system(size: 20, weight: .black, design: .rounded))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 60)
        .shadow(color: Theme.berry.opacity(0.3), radius: 10, y: 4)
    }

    private var undoKey: some View {
        ZStack {
            UnevenRoundedRectangle(
                topLeadingRadius: 8,
                bottomLeadingRadius: 22,
                bottomTrailingRadius: 8,
                topTrailingRadius: 22
            )
            .fill(Theme.ink)
            HStack(spacing: 4) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.headline.bold())
                Text("取消")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
            }
            .foregroundStyle(Theme.birch)
        }
        .frame(width: 100, height: 60)
        .shadow(color: Theme.ink.opacity(0.22), radius: 6, y: 3)
    }
}

private struct KeyPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.18, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
