import SwiftUI

/// iPad で使う名前入力シート。iPhone は引き続き `.alert` を使う想定。
struct NameInputSheet: View {
    let title: String
    let placeholder: String
    let confirmLabel: String
    let onConfirm: (String) -> Void
    let onCancel: () -> Void

    @State private var text: String = ""
    @FocusState private var focused: Bool

    init(
        title: String,
        placeholder: String = "名前",
        confirmLabel: String = "追加",
        onConfirm: @escaping (String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.title = title
        self.placeholder = placeholder
        self.confirmLabel = confirmLabel
        self.onConfirm = onConfirm
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                VStack(spacing: Theme.Space.l) {
                    TextField(placeholder, text: $text)
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .padding(.horizontal, Theme.Space.l)
                        .padding(.vertical, Theme.Space.l)
                        .background(Theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous)
                                .stroke(Theme.ink.opacity(0.10), lineWidth: 1)
                        )
                        .focused($focused)
                        .submitLabel(.done)
                        .onSubmit { confirm() }

                    Button {
                        confirm()
                    } label: {
                        Text(confirmLabel)
                            .font(.system(.title2, design: .rounded).weight(.heavy))
                    }
                    .buttonStyle(PrimaryActionStyle(
                        fill: AnyShapeStyle(canConfirm ? AnyShapeStyle(Theme.inkGradient) : AnyShapeStyle(Theme.ink.opacity(0.25))),
                        shadowColor: canConfirm ? Theme.ink.opacity(0.3) : .clear
                    ))
                    .disabled(!canConfirm)

                    Spacer()
                }
                .padding(Theme.Space.xl)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(.system(.title3, design: .rounded).weight(.heavy))
                        .foregroundStyle(Theme.ink)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("キャンセル") { onCancel() }
                }
            }
            .onAppear {
                // 自動でキーボードを開く
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    focused = true
                }
            }
        }
    }

    private var canConfirm: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func confirm() {
        let name = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        onConfirm(name)
    }
}

// MARK: - View 拡張: iPad=シート / iPhone=alert の出し分け

extension View {
    /// 名前入力のダイアログ。iPad ではカスタムシート、iPhone では `.alert` を表示する。
    /// `text` は呼び出し側で `@State` として保持する一時バッファ。
    /// 「追加」が押されたら `onConfirm` が呼ばれ、`text` の trim 後の値が渡される。
    func nameInputAlert(
        title: String,
        isPresented: Binding<Bool>,
        text: Binding<String>,
        placeholder: String = "名前",
        confirmLabel: String = "追加",
        onConfirm: @escaping (String) -> Void
    ) -> some View {
        modifier(
            NameInputAlertModifier(
                title: title,
                isPresented: isPresented,
                text: text,
                placeholder: placeholder,
                confirmLabel: confirmLabel,
                onConfirm: onConfirm
            )
        )
    }
}

private struct NameInputAlertModifier: ViewModifier {
    let title: String
    @Binding var isPresented: Bool
    @Binding var text: String
    let placeholder: String
    let confirmLabel: String
    let onConfirm: (String) -> Void

    private var isPad: Bool { UIDevice.isPad }

    func body(content: Content) -> some View {
        if isPad {
            content
                .sheet(isPresented: $isPresented) {
                    NameInputSheet(
                        title: title,
                        placeholder: placeholder,
                        confirmLabel: confirmLabel,
                        onConfirm: { name in
                            text = name
                            onConfirm(name)
                            text = ""
                            isPresented = false
                        },
                        onCancel: {
                            text = ""
                            isPresented = false
                        }
                    )
                    .presentationDetents([.medium])
                }
        } else {
            content
                .alert(title, isPresented: $isPresented) {
                    TextField(placeholder, text: $text)
                    Button(confirmLabel) {
                        let name = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !name.isEmpty {
                            onConfirm(name)
                        }
                        text = ""
                    }
                    Button("キャンセル", role: .cancel) {
                        text = ""
                    }
                }
        }
    }
}
