import SwiftUI
import UIKit

struct Keypad: View {
    let onTap: (Int) -> Void
    let onUndo: () -> Void
    let canUndo: Bool
    var isPad: Bool = false

    private var spacing: CGFloat { isPad ? 12 : 6 }
    private var keyHeight: CGFloat { Theme.KeySize.keypadKey(isPad: isPad) }
    private var actionHeight: CGFloat { Theme.KeySize.keypadAction(isPad: isPad) }
    private var digitSize: CGFloat { Theme.FontSize.keypadDigit(isPad: isPad) }
    private var actionTextSize: CGFloat { Theme.FontSize.keypadAction(isPad: isPad) }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: spacing), count: 4)
    }

    var body: some View {
        VStack(spacing: spacing) {
            LazyVGrid(columns: columns, spacing: spacing) {
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

            HStack(spacing: spacing) {
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
        let radius: CGFloat = isPad ? 22 : 16
        let radiusSmall: CGFloat = isPad ? 10 : 6
        return ZStack(alignment: .topLeading) {
            UnevenRoundedRectangle(
                topLeadingRadius: radius,
                bottomLeadingRadius: radiusSmall,
                bottomTrailingRadius: radius,
                topTrailingRadius: radiusSmall
            )
            .fill(Theme.surface)
            .overlay(
                UnevenRoundedRectangle(
                    topLeadingRadius: radius,
                    bottomLeadingRadius: radiusSmall,
                    bottomTrailingRadius: radius,
                    topTrailingRadius: radiusSmall
                )
                .strokeBorder(Theme.ink.opacity(0.10), lineWidth: 1)
            )
            // 上左の角のアクセントドット
            Circle()
                .fill(numberAccent(n))
                .frame(width: isPad ? 10 : 6, height: isPad ? 10 : 6)
                .padding(isPad ? 12 : 8)
            Text("\(n)")
                .font(.system(size: digitSize, weight: .black, design: .rounded).monospacedDigit())
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: keyHeight)
        .shadow(color: Theme.ink.opacity(0.05), radius: 3, y: 2)
    }

    private func numberAccent(_ n: Int) -> Color {
        switch n {
        case 1...4: return Theme.pine
        case 5...8: return Theme.sky
        case 9...12: return Theme.berry
        default: return Theme.textSecondary
        }
    }

    private var missKey: some View {
        let radius: CGFloat = isPad ? 28 : 22
        let radiusSmall: CGFloat = isPad ? 12 : 8
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: radius,
            bottomLeadingRadius: radiusSmall,
            bottomTrailingRadius: radius,
            topTrailingRadius: radiusSmall
        )
        return ZStack {
            shape.fill(
                LinearGradient(
                    colors: [Theme.berry, Color(red: 0.75, green: 0.20, blue: 0.30)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            GeometryReader { geo in
                SkittleShape()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: isPad ? 72 : 50, height: isPad ? 108 : 76)
                    .rotationEffect(.degrees(72))
                    .position(x: geo.size.width - (isPad ? 42 : 30), y: geo.size.height - 4)
            }
            .clipShape(shape)
            .allowsHitTesting(false)

            HStack(spacing: isPad ? 12 : 8) {
                Image(systemName: "xmark")
                    .font(.system(size: actionTextSize + 4, weight: .black))
                Text("ミス")
                    .font(.system(size: actionTextSize, weight: .black, design: .rounded))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, isPad ? 26 : 18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: actionHeight)
        .shadow(color: Theme.berry.opacity(0.3), radius: isPad ? 14 : 10, y: isPad ? 6 : 4)
    }

    private var undoKey: some View {
        let radius: CGFloat = isPad ? 28 : 22
        let radiusSmall: CGFloat = isPad ? 12 : 8
        return ZStack {
            UnevenRoundedRectangle(
                topLeadingRadius: radiusSmall,
                bottomLeadingRadius: radius,
                bottomTrailingRadius: radiusSmall,
                topTrailingRadius: radius
            )
            .fill(Theme.ink)
            HStack(spacing: isPad ? 8 : 4) {
                Image(systemName: "arrow.uturn.backward")
                    .font(isPad ? .title2.bold() : .headline.bold())
                Text("取消")
                    .font(.system(size: actionTextSize - 4, weight: .heavy, design: .rounded))
            }
            .foregroundStyle(Theme.birch)
        }
        .frame(width: isPad ? 140 : 100, height: actionHeight)
        .shadow(color: Theme.ink.opacity(0.22), radius: isPad ? 10 : 6, y: isPad ? 5 : 3)
    }
}

private struct KeyPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.18, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
