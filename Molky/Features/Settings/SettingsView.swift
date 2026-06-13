import SwiftUI

struct SettingsView: View {
    @AppStorage("default.targetScore") private var defaultTarget: Int = 50
    @AppStorage("default.overshootResetTo") private var defaultOvershoot: Int = 25
    @AppStorage("default.maxConsecutiveMisses") private var defaultMaxMisses: Int = 3
    @AppStorage("default.missPolicy") private var defaultMissPolicyRaw: String = MissPolicy.eliminate.rawValue

    private var defaultMissPolicy: MissPolicy {
        MissPolicy(rawValue: defaultMissPolicyRaw) ?? .eliminate
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: Theme.Space.l) {
                    defaultRulesCard
                    aboutCard
                }
                .padding(.horizontal, Theme.Space.l)
                .padding(.top, Theme.Space.s)
                .padding(.bottom, Theme.Space.xl)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("設定")
                    .font(.system(.subheadline, design: .rounded).weight(.heavy))
                    .foregroundStyle(Theme.ink.opacity(0.7))
            }
        }
    }

    private var defaultRulesCard: some View {
        TicketCard(accent: Theme.pine) {
            VStack(alignment: .leading, spacing: Theme.Space.m) {
                SectionHeader(number: 1, title: "既定のルール")
                VStack(spacing: Theme.Space.m) {
                    stepperRow(icon: "target", iconColor: Theme.pine, label: "目標点", value: defaultTarget, range: 10...100, step: 5, binding: $defaultTarget)
                    divider
                    stepperRow(icon: "arrow.uturn.down", iconColor: Theme.sky, label: "超過時", value: defaultOvershoot, range: 0...defaultTarget, step: 5, binding: $defaultOvershoot)
                    divider
                    missPolicyPicker
                    if defaultMissPolicy != .none {
                        divider
                        stepperRow(icon: "number", iconColor: Theme.berry, label: "連続ミスしきい値", value: defaultMaxMisses, range: 2...10, step: 1, binding: $defaultMaxMisses)
                    }
                }
                Text("これらの値は新規ゲーム作成時の初期値として使用されます。")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private var aboutCard: some View {
        TicketCard(accent: Theme.berry) {
            VStack(spacing: Theme.Space.m) {
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(0..<5) { i in
                        SkittleShape()
                            .fill(i == 2 ? Theme.berry : Theme.wood)
                            .frame(width: 14, height: CGFloat(20 + (i % 2) * 8))
                    }
                }
                Wordmark(size: 26)
                Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                    .font(.system(.caption, design: .monospaced).weight(.heavy))
                    .foregroundStyle(Theme.textSecondary)
                Text("モルックの公式ルールに沿ったスコアアプリ。屋外でも見やすい大きな数字表示と、メンバー登録による戦績管理が特長です。")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func stepperRow(icon: String, iconColor: Color, label: String, value: Int, range: ClosedRange<Int>, step: Int, binding: Binding<Int>) -> some View {
        HStack(spacing: Theme.Space.s) {
            Image(systemName: icon).foregroundStyle(iconColor).frame(width: 22)
            Text(label)
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.ink)
            Spacer()
            HStack(spacing: 4) {
                Text("\(value)")
                    .font(.system(.title3, design: .rounded).weight(.heavy).monospacedDigit())
                    .frame(minWidth: 36)
                    .foregroundStyle(Theme.ink)
                Stepper("", value: binding, in: range, step: step)
                    .labelsHidden()
            }
        }
    }

    private var missPolicyPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: Theme.Space.s) {
                Image(systemName: "xmark.octagon.fill")
                    .foregroundStyle(defaultMissPolicy == .none ? Theme.textSecondary : Theme.berry)
                    .frame(width: 22)
                Text("連続ミス時")
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.ink)
                Spacer()
            }
            HStack(spacing: 6) {
                ForEach(MissPolicy.allCases, id: \.self) { p in
                    Button {
                        defaultMissPolicyRaw = p.rawValue
                    } label: {
                        Text(p.label)
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(defaultMissPolicy == p ? .white : Theme.ink)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(
                                Capsule().fill(defaultMissPolicy == p ? Theme.berry : Theme.surface)
                            )
                            .overlay(
                                Capsule().stroke(defaultMissPolicy == p ? Color.clear : Theme.ink.opacity(0.15), lineWidth: 1)
                            )
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
            Text(defaultMissPolicy.shortDescription)
                .font(.caption2)
                .foregroundStyle(Theme.textSecondary)
                .padding(.leading, 30)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Theme.ink.opacity(0.08))
            .frame(height: 1)
    }
}
