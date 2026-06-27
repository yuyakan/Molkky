import SwiftUI
import SwiftData
import UIKit

struct InPlayView: View {
    @Bindable var store: GameSessionStore
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var hSize
    @Environment(\.dismiss) private var dismiss

    @State private var showResult = false
    @State private var savedGame: Game?
    @State private var showExitConfirm = false
    @State private var showFinishConfirm = false

    /// 展開中の行（個人戦は participantIndex、チーム戦は turnIndex）
    @State private var expandedIndices: Set<Int> = []

    private var isPad: Bool { hSize == .regular }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            Group {
                if isPad {
                    // iPad: 左に情報（手番カード+一覧）、右にキーパッド固定
                    HStack(spacing: Theme.Space.l) {
                        scrollingInfo
                            .frame(maxWidth: .infinity)
                        VStack {
                            keypadPanel
                            Spacer(minLength: 0)
                        }
                        .frame(width: 460)
                    }
                    .padding(.horizontal, Theme.Space.l)
                    .padding(.top, Theme.Space.m)
                } else {
                    VStack(spacing: 0) {
                        scrollingInfo
                        keypadPanel
                            .background(
                                Theme.background
                                    .shadow(color: Theme.ink.opacity(0.08), radius: 8, y: -4)
                                    .mask(Rectangle().padding(.top, -20))
                            )
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showExitConfirm = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark")
                        Text("中断")
                    }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.ink)
                }
            }
            ToolbarItem(placement: .principal) {
                Text("対戦中")
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.ink.opacity(0.7))
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showFinishConfirm = true
                } label: {
                    HStack(spacing: 4) {
                        Text("結果へ")
                        Image(systemName: "flag.checkered")
                    }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.pine)
                }
                .disabled(store.events.isEmpty)
                .opacity(store.events.isEmpty ? 0.35 : 1)
            }
        }
        .alert("ゲームを中断しますか？", isPresented: $showExitConfirm) {
            Button("中断（保存しない）", role: .destructive) { dismiss() }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("ここまでのスコアは記録されません。")
        }
        .alert("現在のスコアで結果にしますか？", isPresented: $showFinishConfirm) {
            Button("結果へ進む") { finalizeWithCurrentScores() }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("最高得点のプレイヤー/チームが勝者として記録されます。")
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .onChange(of: store.state.isFinished) { _, finished in
            if finished { persistAndShowResult() }
        }
        .navigationDestination(isPresented: $showResult) {
            if let g = savedGame {
                ResultView(game: g)
                    .navigationBarBackButtonHidden()
            }
        }
    }

    // MARK: - Layout

    private var scrollingInfo: some View {
        ScrollView {
            VStack(spacing: isPad ? Theme.Space.l : Theme.Space.m) {
                currentTurnCard
                    .padding(.top, Theme.Space.s)
                VStack(spacing: isPad ? Theme.Space.m : Theme.Space.s) {
                    ForEach(Array(store.teams.enumerated()), id: \.element.id) { (_, t) in
                        teamRow(t)
                    }
                    ForEach(store.participants, id: \.memberId) { p in
                        participantRow(p)
                    }
                }
            }
            .padding(.horizontal, isPad ? 0 : Theme.Space.l)
            .padding(.bottom, isPad ? Theme.Space.xl : Theme.Space.l)
        }
    }

    private var keypadPanel: some View {
        VStack(spacing: 0) {
            Keypad(
                onTap: { store.record(points: $0) },
                onUndo: { store.undo() },
                canUndo: !store.events.isEmpty,
                isPad: isPad
            )
            .padding(.horizontal, isPad ? 0 : Theme.Space.l)
            .padding(.top, Theme.Space.s)
            .padding(.bottom, isPad ? Theme.Space.l : Theme.Space.s)
        }
    }

    // MARK: - Hero current-turn card

    @ViewBuilder
    private var currentTurnCard: some View {
        switch store.mode {
        case .individual:
            if let p = store.currentParticipant,
               let s = store.participantState(at: p.turnIndex) {
                heroCard(
                    accentIndex: p.turnIndex,
                    title: p.displayName,
                    isGuest: p.isGuest,
                    thrower: nil,
                    score: s.score,
                    misses: s.consecutiveMisses,
                    recentPoints: recentPoints(forParticipantIndex: p.turnIndex, limit: 5)
                )
            }
        case .team:
            if let t = store.currentTeam,
               let s = store.participantState(at: t.turnIndex) {
                heroCard(
                    accentIndex: t.turnIndex,
                    title: t.displayName,
                    isGuest: t.isGuest,
                    thrower: store.currentThrowerName,
                    score: s.score,
                    misses: s.consecutiveMisses,
                    recentPoints: recentPoints(forParticipantIndex: t.turnIndex, limit: 5)
                )
            }
        }
    }

    /// 指定の参加者インデックスの直近の得点を旧→新の順で最大 limit 件返す
    private func recentPoints(forParticipantIndex idx: Int, limit: Int) -> [Int] {
        store.events
            .filter { $0.participantIndex == idx }
            .suffix(limit)
            .map { $0.points }
    }

    /// 最終投擲の得点（参加者ごと）
    private func lastPoints(forParticipantIndex idx: Int) -> Int? {
        store.events.last(where: { $0.participantIndex == idx })?.points
    }

    /// 手番カード内の点数ピル（白系）
    private func pointPill(_ pts: Int) -> some View {
        let isMiss = pts == 0
        return Group {
            if isMiss {
                Text("ミス")
            } else {
                Text("\(pts)")
            }
        }
        .font(.system(.subheadline, design: .rounded).weight(.heavy).monospacedDigit())
        .foregroundStyle(isMiss ? Theme.birch : Theme.ink)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            Capsule().fill(isMiss ? Theme.berry : Theme.birch)
        )
    }

    /// 行内の小さな点数表示（ライト背景）
    private func miniPointBadge(_ pts: Int) -> some View {
        let isMiss = pts == 0
        return Group {
            if isMiss {
                Text("ミス")
            } else {
                Text("+\(pts)")
            }
        }
        .font(.system(.caption, design: .rounded).weight(.heavy).monospacedDigit())
        .foregroundStyle(isMiss ? Theme.berry : Theme.pine)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            Capsule().fill(isMiss ? Theme.berry.opacity(0.12) : Theme.pine.opacity(0.12))
        )
    }

    private func heroCard(accentIndex: Int, title: String, isGuest: Bool, thrower: String?, score: Int, misses: Int, recentPoints: [Int]) -> some View {
        let accent = Theme.participantColor(index: accentIndex)
        return ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Theme.ink)

            // 左辺の色帯
            Rectangle()
                .fill(accent)
                .frame(width: 6)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 24,
                        bottomLeadingRadius: 24,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 0
                    )
                )

            VStack(spacing: isPad ? Theme.Space.l : Theme.Space.m) {
                // 名前と巨大スコアを水平配置
                HStack(alignment: .center, spacing: Theme.Space.m) {
                    VStack(alignment: .leading, spacing: isPad ? 10 : 6) {
                        HStack(spacing: 8) {
                            Text(title)
                                .font(.system(size: Theme.FontSize.heroName(isPad: isPad), weight: .black, design: .rounded))
                                .foregroundStyle(Theme.birch)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                            if isGuest {
                                Text("ゲスト")
                                    .font(.system(isPad ? .subheadline : .caption2, design: .rounded).weight(.bold))
                                    .foregroundStyle(Theme.birch)
                                    .padding(.horizontal, isPad ? 10 : 6).padding(.vertical, isPad ? 4 : 2)
                                    .background(Theme.birch.opacity(0.18))
                                    .clipShape(Capsule())
                            }
                        }
                        if let thrower {
                            HStack(spacing: 6) {
                                Image(systemName: "figure.bowling")
                                Text(thrower)
                            }
                            .font(.system(isPad ? .title3 : .footnote, design: .rounded).weight(.semibold))
                            .foregroundStyle(Theme.ink)
                            .padding(.horizontal, isPad ? 14 : 10)
                            .padding(.vertical, isPad ? 6 : 4)
                            .background(Theme.birch)
                            .clipShape(Capsule())
                        }
                    }
                    Spacer(minLength: Theme.Space.s)
                    Text("\(score)")
                        .font(.system(size: Theme.FontSize.heroScore(isPad: isPad), weight: .black, design: .rounded).monospacedDigit())
                        .foregroundStyle(Theme.birch)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }

                // 直近の投擲履歴
                if !recentPoints.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(Array(recentPoints.enumerated()), id: \.offset) { (i, pts) in
                            if i > 0 {
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Theme.birch.opacity(0.35))
                            }
                            pointPill(pts)
                        }
                        Spacer()
                    }
                }

                // 連続ミス（細い帯として下部に配置）
                if store.config.missPolicy != .none {
                    HStack(spacing: 6) {
                        ForEach(0..<store.config.maxConsecutiveMisses, id: \.self) { i in
                            Capsule()
                                .fill(i < misses ? Theme.berry : Theme.birch.opacity(0.15))
                                .frame(height: 5)
                        }
                    }
                }
            }
            .padding(.vertical, isPad ? Theme.Space.xl : Theme.Space.l)
            .padding(.leading, (isPad ? Theme.Space.xl : Theme.Space.l) + 12)
            .padding(.trailing, isPad ? Theme.Space.xl : Theme.Space.l)
        }
        .shadow(color: Theme.ink.opacity(0.18), radius: isPad ? 18 : 12, y: isPad ? 10 : 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("手番 \(title)、スコア \(score)"))
    }

    // MARK: - Other player rows

    private func participantRow(_ p: PersistedParticipant) -> some View {
        let isCurrent = store.currentParticipant?.memberId == p.memberId
        // 手番中のプレイヤーは上のヒーローカードに表示されるので一覧では非表示
        return Group {
            if !isCurrent {
                row(
                    participantIndex: p.turnIndex,
                    title: p.displayName,
                    isGuest: p.isGuest,
                    state: store.participantState(at: p.turnIndex),
                    lastPoints: lastPoints(forParticipantIndex: p.turnIndex),
                    history: recentPoints(forParticipantIndex: p.turnIndex, limit: 8)
                )
            }
        }
    }

    private func teamRow(_ t: PersistedTeam) -> some View {
        let isCurrent = store.currentTeam?.id == t.id
        return Group {
            if !isCurrent {
                row(
                    participantIndex: t.turnIndex,
                    title: t.displayName,
                    isGuest: t.isGuest,
                    state: store.participantState(at: t.turnIndex),
                    lastPoints: lastPoints(forParticipantIndex: t.turnIndex),
                    history: recentPoints(forParticipantIndex: t.turnIndex, limit: 8)
                )
            }
        }
    }

    private func row(participantIndex: Int, title: String, isGuest: Bool, state s: ParticipantState?, lastPoints: Int?, history: [Int]) -> some View {
        let score = s?.score ?? 0
        let isElim = s?.isEliminated ?? false
        let finishedRank = s?.finishedRank
        let misses = s?.consecutiveMisses ?? 0
        let color = Theme.participantColor(index: participantIndex)
        let isExpanded = expandedIndices.contains(participantIndex)
        let canExpand = !history.isEmpty

        return VStack(spacing: 0) {
            Button {
                guard canExpand else { return }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    if isExpanded {
                        expandedIndices.remove(participantIndex)
                    } else {
                        expandedIndices.insert(participantIndex)
                    }
                }
            } label: {
                HStack(spacing: 0) {
                    // 左：色のサイドバー
                    Rectangle()
                        .fill(isElim ? Color.gray.opacity(0.3) : color)
                        .frame(width: isPad ? 6 : 4)

                    // 中央：名前 + 状態（左寄せ）
                    VStack(alignment: .leading, spacing: isPad ? 6 : 4) {
                        HStack(spacing: 8) {
                            Text(title)
                                .font(.system(size: Theme.FontSize.rowName(isPad: isPad), weight: .bold, design: .rounded))
                                .foregroundStyle(isElim ? Theme.textSecondary : Theme.ink)
                                .strikethrough(isElim)
                                .lineLimit(1)
                            if isGuest {
                                Text("ゲスト")
                                    .font(.system(isPad ? .footnote : .caption2, design: .rounded).weight(.bold))
                                    .foregroundStyle(Theme.berry)
                                    .padding(.horizontal, isPad ? 8 : 5).padding(.vertical, isPad ? 3 : 1)
                                    .background(Theme.berry.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                        }
                        statusLine(misses: misses, isElim: isElim, finishedRank: finishedRank)
                    }
                    .padding(.horizontal, isPad ? Theme.Space.l : Theme.Space.m)

                    Spacer(minLength: Theme.Space.s)

                    // 右：直近の投擲点（左）+ 合計スコア（右、広め）
                    HStack(alignment: .center, spacing: isPad ? Theme.Space.m : Theme.Space.s) {
                        if let lastPoints, !isElim {
                            miniPointBadge(lastPoints)
                        }
                        Text("\(score)")
                            .font(.system(size: Theme.FontSize.rowScore(isPad: isPad), weight: .black, design: .rounded).monospacedDigit())
                            .foregroundStyle(isElim ? Theme.textSecondary : Theme.ink)
                    }
                    .padding(.trailing, isPad ? Theme.Space.s : 6)

                    // 展開インジケーター
                    if canExpand {
                        Image(systemName: "chevron.down")
                            .font(isPad ? .subheadline.bold() : .caption.bold())
                            .foregroundStyle(Theme.ink.opacity(0.35))
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                            .padding(.trailing, isPad ? Theme.Space.m : Theme.Space.s)
                    }
                }
                .frame(minHeight: Theme.KeySize.rowMin(isPad: isPad))
            }
            .buttonStyle(.plain)

            // 展開部：過去の投擲履歴
            if isExpanded && canExpand {
                expandedHistory(history, accent: color)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: isPad ? 18 : 14, style: .continuous)
                .fill(Theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: isPad ? 18 : 14, style: .continuous)
                .stroke(Theme.ink.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: isPad ? 18 : 14, style: .continuous))
    }

    /// 展開時の履歴帯
    private func expandedHistory(_ history: [Int], accent: Color) -> some View {
        // history は旧→新の順で渡される
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            Rectangle()
                .fill(Theme.ink.opacity(0.06))
                .frame(height: 1)
            HStack(spacing: 6) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.caption2)
                    .foregroundStyle(accent)
                Text("投擲履歴")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Text("\(history.count) 投")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(Theme.textSecondary)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(history.enumerated()), id: \.offset) { (i, pts) in
                        historyChip(index: i, points: pts, accent: accent, total: history.count)
                    }
                }
            }
        }
        .padding(.horizontal, Theme.Space.m)
        .padding(.vertical, Theme.Space.s + 2)
    }

    private func historyChip(index i: Int, points pts: Int, accent: Color, total: Int) -> some View {
        let isMiss = pts == 0
        let positionFromEnd = total - i  // 最新が1
        return VStack(spacing: 2) {
            Text("\(positionFromEnd)投前")
                .font(.system(size: 9, design: .rounded).weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
            Group {
                if isMiss {
                    Text("ミス")
                } else {
                    Text("+\(pts)")
                }
            }
            .font(.system(.subheadline, design: .rounded).weight(.heavy).monospacedDigit())
            .foregroundStyle(isMiss ? .white : accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(isMiss ? Theme.berry : accent.opacity(0.12))
            )
        }
    }

    @ViewBuilder
    private func statusLine(misses: Int, isElim: Bool, finishedRank: Int?) -> some View {
        if isElim {
            Text("失格")
                .font(.system(.caption2, design: .rounded).weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Theme.berry)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        } else if let r = finishedRank, r == 1 {
            HStack(spacing: 3) {
                Image(systemName: "trophy.fill")
                    .font(.caption2)
                Text("勝者")
                    .font(.system(.caption2, design: .rounded).weight(.bold))
            }
            .foregroundStyle(Theme.sun)
        } else if let r = finishedRank {
            Text("\(r)位")
                .font(.system(.caption2, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.textSecondary)
        } else if misses > 0 {
            HStack(spacing: 3) {
                ForEach(0..<misses, id: \.self) { _ in
                    Capsule()
                        .fill(Theme.berry)
                        .frame(width: 10, height: 4)
                }
                Text("ミス")
                    .font(.system(.caption2, design: .rounded).weight(.semibold))
                    .foregroundStyle(Theme.berry)
            }
        }
    }

    private func persistAndShowResult() {
        let game = Game(
            targetScore: store.config.targetScore,
            overshootResetTo: store.config.overshootResetTo,
            eliminationEnabled: store.config.eliminationEnabled,
            maxConsecutiveMisses: store.config.maxConsecutiveMisses,
            missPolicy: store.config.missPolicy
        )
        store.saveToGame(game)
        modelContext.insert(game)
        try? modelContext.save()
        savedGame = game
        showResult = true
    }

    /// 「結果へ」ボタン押下時の処理。現在のスコアで強制終了 → 結果画面へ。
    private func finalizeWithCurrentScores() {
        store.forceFinish()
        // onChange の遷移は state.isFinished の変化で発火するが、forceFinish 内で書き換えると
        // observableの伝播タイミングに依存するため明示的に呼ぶ
        if savedGame == nil {
            persistAndShowResult()
        }
    }
}
