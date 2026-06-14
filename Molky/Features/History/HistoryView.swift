import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var hSize
    @Query(sort: \Game.date, order: .reverse) private var games: [Game]

    @State private var selectedGameId: UUID?
    private var isPad: Bool { hSize == .regular }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            if isPad {
                padBody
            } else {
                phoneBody
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("履歴")
                    .font(.system(.subheadline, design: .rounded).weight(.heavy))
                    .foregroundStyle(Theme.ink.opacity(0.7))
            }
        }
    }

    private var phoneBody: some View {
        ScrollView {
            if games.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: Theme.Space.s) {
                    ForEach(games) { g in
                        NavigationLink {
                            GameDetailView(game: g)
                        } label: {
                            row(g, selected: false)
                        }
                        .buttonStyle(PressableButtonStyle())
                        .swipeActions {
                            Button(role: .destructive) {
                                delete(g)
                            } label: {
                                Label("削除", systemImage: "trash")
                            }
                        }
                    }
                }
                .padding(.horizontal, Theme.Space.l)
                .padding(.top, Theme.Space.s)
                .padding(.bottom, Theme.Space.xl)
            }
        }
    }

    private var padBody: some View {
        HStack(alignment: .top, spacing: 0) {
            ScrollView {
                if games.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: Theme.Space.s) {
                        ForEach(games) { g in
                            Button {
                                selectedGameId = g.id
                            } label: {
                                row(g, selected: selectedGameId == g.id)
                            }
                            .buttonStyle(PressableButtonStyle())
                            .swipeActions {
                                Button(role: .destructive) {
                                    if selectedGameId == g.id { selectedGameId = nil }
                                    delete(g)
                                } label: {
                                    Label("削除", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding(.horizontal, Theme.Space.l)
                    .padding(.top, Theme.Space.s)
                    .padding(.bottom, Theme.Space.xl)
                }
            }
            .frame(width: 400)

            Rectangle()
                .fill(Theme.ink.opacity(0.08))
                .frame(width: 1)

            Group {
                if let selected = games.first(where: { $0.id == selectedGameId }) {
                    GameDetailView(game: selected)
                } else {
                    detailPlaceholder
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            if selectedGameId == nil, let first = games.first {
                selectedGameId = first.id
            }
        }
    }

    private var detailPlaceholder: some View {
        VStack(spacing: Theme.Space.m) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 72))
                .foregroundStyle(Theme.ink.opacity(0.2))
            Text("左から試合を選択")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Space.l) {
            HStack(spacing: 6) {
                ForEach(0..<7) { i in
                    SkittleShape()
                        .fill(i == 3 ? Theme.berry : Theme.wood)
                        .frame(width: 16, height: 28)
                }
            }
            VStack(spacing: 6) {
                Text("履歴はまだありません")
                    .font(.system(.title3, design: .rounded).weight(.heavy))
                    .foregroundStyle(Theme.ink)
                Text("ゲームを完了するとここに表示されます。")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(.top, 80)
        .frame(maxWidth: .infinity)
    }

    private func row(_ g: Game, selected: Bool) -> some View {
        let winnerName: String? = {
            if g.mode == .team {
                return g.teams.first(where: { $0.finishedRank == 1 })?.displayName
            }
            return g.participants.first(where: { $0.finishedRank == 1 })?.displayName
        }()
        return HStack(spacing: Theme.Space.m) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(jpDate(g.date))
                        .font(.system(.subheadline, design: .rounded).weight(.heavy))
                        .foregroundStyle(Theme.ink)
                    Group {
                        if g.mode == .team {
                            Text("チーム戦")
                        } else {
                            Text("個人戦")
                        }
                    }
                    .font(.system(.caption2, design: .rounded).weight(.heavy))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .foregroundStyle(g.mode == .team ? Theme.berry : Theme.pine)
                    .background((g.mode == .team ? Theme.berry : Theme.pine).opacity(0.12))
                    .clipShape(Capsule())
                }
                if let winnerName {
                    Text("勝者 \(winnerName)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                } else {
                    Text("未完了")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            Spacer()
            if !isPad {
                Image(systemName: "chevron.right")
                    .foregroundStyle(Theme.ink.opacity(0.3))
            }
        }
        .padding(Theme.Space.m)
        .background(selected ? Theme.pine.opacity(0.10) : Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                .stroke(selected ? Theme.pine : Theme.ink.opacity(0.06), lineWidth: selected ? 2 : 1)
        )
    }

    private func jpDate(_ d: Date) -> String {
        d.formatted(.dateTime.month().day().weekday(.abbreviated).hour().minute())
    }

    private func delete(_ g: Game) {
        modelContext.delete(g)
        try? modelContext.save()
    }
}

struct GameDetailView: View {
    @Bindable var game: Game

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: Theme.Space.l) {
                    resultsCard
                    settingsCard
                    throwLogCard
                }
                .padding(.horizontal, Theme.Space.l)
                .padding(.top, Theme.Space.s)
                .padding(.bottom, Theme.Space.xl)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private var resultsCard: some View {
        TicketCard(accent: Theme.pine) {
            VStack(alignment: .leading, spacing: Theme.Space.m) {
                SectionHeader(number: 1, title: "最終順位")
                VStack(spacing: Theme.Space.s) {
                    switch game.mode {
                    case .individual:
                        ForEach(rankedParticipants, id: \.memberId) { p in
                            resultRow(rank: p.finishedRank, badge: "\(p.turnIndex + 1)", title: p.displayName, subtitle: nil, score: p.finalScore, isElim: p.isEliminated, colorIndex: p.turnIndex)
                        }
                    case .team:
                        let letters = ["A","B","C","D","E","F"]
                        ForEach(rankedTeams, id: \.id) { t in
                            let badge = letters.indices.contains(t.turnIndex) ? letters[t.turnIndex] : "\(t.turnIndex + 1)"
                            resultRow(rank: t.finishedRank, badge: badge, title: t.displayName, subtitle: t.memberNames.joined(separator: " · "), score: t.finalScore, isElim: t.isEliminated, colorIndex: t.turnIndex)
                        }
                    }
                }
            }
        }
    }

    private func resultRow(rank: Int?, badge: String, title: String, subtitle: String?, score: Int, isElim: Bool, colorIndex: Int) -> some View {
        let isWinner = rank == 1
        return HStack(spacing: Theme.Space.m) {
            ZStack {
                if isWinner {
                    Image(systemName: "trophy.fill").font(.title3).foregroundStyle(Theme.sun)
                } else if let r = rank {
                    Text("\(r)").font(.system(.headline, design: .rounded).weight(.heavy).monospacedDigit()).foregroundStyle(Theme.textSecondary)
                } else {
                    Text("—").foregroundStyle(Theme.textSecondary)
                }
            }
            .frame(width: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(.subheadline, design: .rounded).weight(.heavy))
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle).font(.caption2).foregroundStyle(Theme.textSecondary).lineLimit(1)
                }
            }
            Spacer()
            Text("\(score)").font(.system(.title3, design: .rounded).weight(.heavy).monospacedDigit())
                .foregroundStyle(isWinner ? Theme.pine : Theme.ink)
            if isElim {
                Text("失格")
                    .font(.system(.caption2, design: .rounded).weight(.heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(Theme.berry)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            }
        }
        .padding(.horizontal, Theme.Space.s)
        .padding(.vertical, 6)
    }

    private var settingsCard: some View {
        TicketCard(accent: Theme.sky) {
            VStack(alignment: .leading, spacing: Theme.Space.m) {
                SectionHeader(number: 2, title: "設定")
                VStack(spacing: Theme.Space.s) {
                    settingRow(label: "モード", value: game.mode == .team ? String(localized: "チーム戦") : String(localized: "個人戦"))
                    settingRow(label: "目標点", value: "\(game.targetScore)")
                    settingRow(label: "超過時", value: "\(game.overshootResetTo)")
                    settingRow(label: "連続ミス時", value: missPolicyDescription(for: game))
                    settingRow(label: "日時", value: detailJpDate(game.date))
                }
            }
        }
    }

    private func settingRow(label: LocalizedStringKey, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.ink)
            Spacer()
            Text(value)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private var throwLogCard: some View {
        TicketCard(accent: Theme.berry) {
            VStack(alignment: .leading, spacing: Theme.Space.m) {
                SectionHeader(
                    number: 3, title: "投擲ログ",
                    trailing: AnyView(
                        Text("\(game.throwEvents.count) 投")
                            .font(.system(.caption, design: .rounded).weight(.heavy))
                            .foregroundStyle(Theme.textSecondary)
                    )
                )
                VStack(spacing: 4) {
                    ForEach(Array(game.throwEvents.enumerated()), id: \.element.id) { (i, ev) in
                        throwLogRow(index: i, event: ev)
                    }
                }
            }
        }
    }

    private func throwLogRow(index i: Int, event ev: ThrowEvent) -> some View {
        let (participantName, colorIndex): (String, Int) = {
            switch game.mode {
            case .individual:
                let p = game.participants.first(where: { $0.turnIndex == ev.participantIndex })
                return (p?.displayName ?? "?", p?.turnIndex ?? 0)
            case .team:
                let t = game.teams.first(where: { $0.turnIndex == ev.participantIndex })
                return (t?.displayName ?? "?", t?.turnIndex ?? 0)
            }
        }()
        let throwerName: String? = {
            guard game.mode == .team, let tid = ev.throwerMemberId else { return nil }
            for t in game.teams {
                if let idx = t.memberIds.firstIndex(of: tid), t.memberNames.indices.contains(idx) {
                    return t.memberNames[idx]
                }
            }
            return nil
        }()
        return HStack(spacing: Theme.Space.s) {
            Text(String(format: "%02d", i + 1))
                .font(.system(.caption2, design: .monospaced).weight(.heavy))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 26, alignment: .trailing)
            Rectangle()
                .fill(Theme.participantColor(index: colorIndex))
                .frame(width: 3, height: 24)
                .clipShape(Capsule())
            VStack(alignment: .leading, spacing: 1) {
                Text(participantName).font(.system(.subheadline, design: .rounded).weight(.bold))
                if let throwerName {
                    HStack(spacing: 3) {
                        Image(systemName: "figure.bowling").font(.caption2)
                        Text(throwerName).font(.caption2)
                    }
                    .foregroundStyle(Theme.textSecondary)
                }
            }
            Spacer()
            if ev.points == 0 {
                Text("ミス")
                    .font(.system(.caption, design: .rounded).weight(.heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Theme.berry)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                Text("+\(ev.points)")
                    .font(.system(.subheadline, design: .rounded).weight(.heavy).monospacedDigit())
                    .foregroundStyle(Theme.pine)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Theme.pine.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
        .padding(.vertical, 2)
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

    private func missPolicyDescription(for g: Game) -> String {
        switch g.missPolicy {
        case .eliminate: return String(localized: "\(g.maxConsecutiveMisses)回連続で失格")
        case .resetToZero: return String(localized: "\(g.maxConsecutiveMisses)回連続で0リセット")
        case .none: return String(localized: "ペナルティなし")
        }
    }

    private func detailJpDate(_ d: Date) -> String {
        d.formatted(.dateTime.year().month().day().weekday(.abbreviated).hour().minute())
    }
}
