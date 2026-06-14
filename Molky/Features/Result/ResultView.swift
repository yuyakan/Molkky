import SwiftUI
import SwiftData

struct ResultView: View {
    @Bindable var game: Game
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var hSize
    private let coordinator = NavigationCoordinator.shared

    @State private var rematchSession: GameSessionStore?

    private var isPad: Bool { hSize == .regular }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: Theme.Space.xl) {
                        winnerBanner
                        rankingList
                    }
                    .padding(.horizontal, Theme.Space.l)
                    .padding(.bottom, Theme.Space.xl)
                }
                actionBar
                    .padding(.horizontal, Theme.Space.l)
                    .padding(.bottom, Theme.Space.l)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("結果")
                    .font(.system(.subheadline, design: .rounded).weight(.heavy))
                    .foregroundStyle(Theme.ink.opacity(0.7))
            }
        }
        .navigationDestination(item: $rematchSession) { store in
            InPlayView(store: store).navigationBarBackButtonHidden()
        }
    }

    @ViewBuilder
    private var winnerBanner: some View {
        switch game.mode {
        case .individual:
            if let w = game.participants.first(where: { $0.finishedRank == 1 }) {
                winnerView(badge: "\(w.turnIndex + 1)", title: w.displayName, subtitle: nil, score: w.finalScore, colorIndex: w.turnIndex)
            }
        case .team:
            if let w = game.teams.first(where: { $0.finishedRank == 1 }) {
                let letters = ["A","B","C","D","E","F"]
                let badge = letters.indices.contains(w.turnIndex) ? letters[w.turnIndex] : "\(w.turnIndex + 1)"
                winnerView(badge: badge, title: w.displayName, subtitle: w.memberNames.joined(separator: " · "), score: w.finalScore, colorIndex: w.turnIndex)
            }
        }
    }

    private func winnerView(badge: String, title: String, subtitle: String?, score: Int, colorIndex: Int) -> some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Radius.xLarge, style: .continuous)
        return ZStack(alignment: .topLeading) {
            // 背景（金グラデーション）
            shape.fill(
                LinearGradient(
                    colors: [Theme.sun, Color(red: 0.96, green: 0.55, blue: 0.20)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            // ドット装飾
            DotGrid(color: Color.white.opacity(0.18))
                .clipShape(shape)
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: isPad ? Theme.Space.l : Theme.Space.m) {
                HStack(spacing: 8) {
                    Image(systemName: "trophy.fill")
                        .font(isPad ? .title : .body)
                        .foregroundStyle(Theme.ink)
                    Text("優勝")
                        .font(.system(isPad ? .title3 : .subheadline, design: .rounded).weight(.heavy))
                        .foregroundStyle(Theme.ink.opacity(0.75))
                }
                Text(title)
                    .font(.system(size: Theme.FontSize.resultName(isPad: isPad), weight: .black, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.5)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(isPad ? .title3 : .subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(Theme.ink.opacity(0.7))
                }
                Spacer(minLength: Theme.Space.s)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(score)")
                        .font(.system(size: Theme.FontSize.resultScore(isPad: isPad), weight: .black, design: .rounded).monospacedDigit())
                        .foregroundStyle(Theme.ink)
                    Text("点")
                        .font(.system(isPad ? .title : .title3, design: .rounded).weight(.heavy))
                        .foregroundStyle(Theme.ink.opacity(0.5))
                }
            }
            .padding(isPad ? Theme.Space.xxl : Theme.Space.xl)
        }
        .frame(minHeight: isPad ? 420 : 260)
        .clipShape(shape)
        .shadow(color: Theme.sun.opacity(0.3), radius: 22, y: 12)
    }

    private var rankingList: some View {
        TicketCard(accent: Theme.pine) {
            VStack(alignment: .leading, spacing: Theme.Space.m) {
                SectionHeader(number: 1, title: "最終順位")
                VStack(spacing: Theme.Space.s) {
                    switch game.mode {
                    case .individual:
                        ForEach(rankedParticipants, id: \.memberId) { p in
                            rankRow(rank: p.finishedRank, badge: "\(p.turnIndex + 1)", title: p.displayName, subtitle: nil, score: p.finalScore, isElim: p.isEliminated, colorIndex: p.turnIndex)
                        }
                    case .team:
                        let letters = ["A","B","C","D","E","F"]
                        ForEach(rankedTeams, id: \.id) { t in
                            let badge = letters.indices.contains(t.turnIndex) ? letters[t.turnIndex] : "\(t.turnIndex + 1)"
                            rankRow(rank: t.finishedRank, badge: badge, title: t.displayName, subtitle: t.memberNames.joined(separator: " · "), score: t.finalScore, isElim: t.isEliminated, colorIndex: t.turnIndex)
                        }
                    }
                }
            }
        }
    }

    private func rankRow(rank: Int?, badge: String, title: String, subtitle: String?, score: Int, isElim: Bool, colorIndex: Int) -> some View {
        let isWinner = rank == 1
        return HStack(spacing: Theme.Space.m) {
            // ランク表示
            ZStack {
                if isWinner {
                    Image(systemName: "trophy.fill")
                        .font(.title2)
                        .foregroundStyle(Theme.sun)
                } else if let r = rank {
                    Text("\(r)")
                        .font(.system(size: 22, weight: .black, design: .rounded).monospacedDigit())
                        .foregroundStyle(Theme.textSecondary)
                } else {
                    Text("—").foregroundStyle(Theme.textSecondary)
                }
            }
            .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.headline, design: .rounded).weight(.heavy))
                    .foregroundStyle(isElim ? Theme.textSecondary : Theme.ink)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Text("\(score)")
                .font(.system(.title2, design: .rounded).weight(.heavy).monospacedDigit())
                .foregroundStyle(isWinner ? Theme.pine : Theme.ink)
            if isElim {
                Text("失格")
                    .font(.system(.caption2, design: .rounded).weight(.heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(Theme.berry)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            }
        }
        .padding(.horizontal, Theme.Space.m)
        .padding(.vertical, Theme.Space.s)
        .background(isWinner ? Theme.sun.opacity(0.12) : Theme.birch.opacity(0.5))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                .strokeBorder(isWinner ? Theme.sun : Color.clear, lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
    }

    private var actionBar: some View {
        HStack(spacing: Theme.Space.m) {
            Button {
                coordinator.popToRoot()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "house.fill")
                    Text("ホーム").font(.system(.headline, design: .rounded).weight(.heavy))
                }
            }
            .buttonStyle(GhostActionStyle())
            .frame(maxWidth: 140)

            Button {
                rematch()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                    Group {
                        if game.mode == .team {
                            Text("同チームで再戦")
                        } else {
                            Text("再戦")
                        }
                    }
                    .font(.system(.headline, design: .rounded).weight(.heavy))
                }
            }
            .buttonStyle(PrimaryActionStyle())
        }
    }

    private var rankedParticipants: [PersistedParticipant] {
        game.participants.sorted { a, b in
            switch (a.finishedRank, b.finishedRank) {
            case let (l?, r?): return l < r
            case (_?, nil): return true
            case (nil, _?): return false
            default: return a.finalScore > b.finalScore
            }
        }
    }
    private var rankedTeams: [PersistedTeam] {
        game.teams.sorted { a, b in
            switch (a.finishedRank, b.finishedRank) {
            case let (l?, r?): return l < r
            case (_?, nil): return true
            case (nil, _?): return false
            default: return a.finalScore > b.finalScore
            }
        }
    }
    private func rematch() {
        switch game.mode {
        case .individual:
            let parts = game.participants
                .sorted { $0.turnIndex < $1.turnIndex }
                .enumerated()
                .map { (i, p) in
                    PersistedParticipant(memberId: p.memberId, name: p.name, turnIndex: i, finalScore: 0, finishedRank: nil, isEliminated: false, isGuest: p.isGuest)
                }
            rematchSession = GameSessionStore(config: game.config, participants: parts)
        case .team:
            let teams = game.teams
                .sorted { $0.turnIndex < $1.turnIndex }
                .enumerated()
                .map { (i, t) in
                    PersistedTeam(id: UUID(), name: t.name, turnIndex: i, memberIds: t.memberIds, memberNames: t.memberNames, finalScore: 0, finishedRank: nil, isEliminated: false, isGuest: t.isGuest)
                }
            rematchSession = GameSessionStore(config: game.config, teams: teams)
        }
    }
}
