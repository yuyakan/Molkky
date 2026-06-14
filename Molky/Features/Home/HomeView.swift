import SwiftUI
import SwiftData

struct HomeView: View {
    @Query(sort: \Game.date, order: .reverse) private var recentGames: [Game]
    @Query(sort: \Member.createdAt, order: .reverse) private var members: [Member]
    @Query(sort: \Team.createdAt, order: .reverse) private var teams: [Team]

    @Bindable private var coordinator = NavigationCoordinator.shared
    @Environment(\.horizontalSizeClass) private var hSize
    private var isPad: Bool { hSize == .regular }

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            ZStack(alignment: .top) {
                Theme.background.ignoresSafeArea()
                if isPad {
                    padBody
                } else {
                    phoneBody
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var phoneBody: some View {
        ScrollView {
            VStack(spacing: Theme.Space.xl) {
                brandHeader
                heroCTA
                menuStrip
                if !recentGames.isEmpty {
                    recentSection
                } else {
                    firstTimePrompt
                }
            }
            .padding(.horizontal, Theme.Space.l)
            .padding(.bottom, Theme.Space.xxl)
        }
    }

    /// iPad: 上部にブランド、下にゲーム開始CTAを巨大に、その下にメニューと最近のゲームを横並び
    private var padBody: some View {
        ScrollView {
            VStack(spacing: Theme.Space.xxl) {
                brandHeader
                    .padding(.top, Theme.Space.s)

                // ヒーローCTA: iPad では画面幅を活かして横長カードを2枚
                heroCTA

                // 下段: メニューと最近のゲームを横並び
                HStack(alignment: .top, spacing: Theme.Space.l) {
                    menuStrip
                        .frame(maxWidth: .infinity)
                    if !recentGames.isEmpty {
                        recentSection
                            .frame(maxWidth: .infinity)
                    } else {
                        firstTimePrompt
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.bottom, Theme.Space.xl)
            }
            .padding(.horizontal, Theme.Space.xl)
        }
    }

    private var brandHeader: some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            HStack(alignment: .bottom) {
                Wordmark(size: 30)
                Spacer()
                NavigationLink {
                    SettingsView()
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.title3)
                        .foregroundStyle(Theme.ink.opacity(0.7))
                        .frame(width: 40, height: 40)
                        .background(Theme.surface)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Theme.ink.opacity(0.08), lineWidth: 1))
                }
            }
            // 装飾的スキットル列
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(1...12, id: \.self) { i in
                    SkittleShape()
                        .fill(i <= 4 ? Theme.wood : Theme.wood.opacity(0.35))
                        .frame(width: 12, height: CGFloat(14 + (i % 3) * 6))
                        .overlay(
                            Rectangle()
                                .fill(i <= 4 ? Color.white.opacity(0.85) : Color.white.opacity(0.5))
                                .frame(width: 12, height: 4)
                                .offset(y: -CGFloat(14 + (i % 3) * 6) * 0.25)
                        )
                }
                Spacer()
            }
        }
        .padding(.top, Theme.Space.m)
    }

    private var heroCTA: some View {
        HStack(spacing: Theme.Space.m) {
            NavigationLink {
                NewGameView(initialMode: .individual)
            } label: {
                modeHeroCard(
                    title: "個人戦",
                    subtitle: "1人ずつ得点",
                    icon: "person.fill",
                    background: AnyShapeStyle(Theme.inkGradient),
                    foreground: Theme.birch,
                    badge: Theme.sun
                )
            }
            .buttonStyle(PressableButtonStyle())

            NavigationLink {
                NewGameView(initialMode: .team)
            } label: {
                modeHeroCard(
                    title: "チーム戦",
                    subtitle: "チームで合算",
                    icon: "person.3.fill",
                    background: AnyShapeStyle(
                        LinearGradient(colors: [Theme.berry, Color(red: 0.72, green: 0.20, blue: 0.32)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    ),
                    foreground: .white,
                    badge: Theme.sun
                )
            }
            .buttonStyle(PressableButtonStyle())
        }
    }

    private func modeHeroCard(title: String, subtitle: String, icon: String, background: AnyShapeStyle, foreground: Color, badge: Color) -> some View {
        ZStack(alignment: .topTrailing) {
            UnevenRoundedRectangle(
                topLeadingRadius: Theme.Radius.xLarge,
                bottomLeadingRadius: Theme.Radius.medium,
                bottomTrailingRadius: Theme.Radius.xLarge,
                topTrailingRadius: Theme.Radius.medium
            )
            .fill(background)
            DotGrid(color: foreground.opacity(0.08))
                .clipShape(UnevenRoundedRectangle(
                    topLeadingRadius: Theme.Radius.xLarge,
                    bottomLeadingRadius: Theme.Radius.medium,
                    bottomTrailingRadius: Theme.Radius.xLarge,
                    topTrailingRadius: Theme.Radius.medium
                ))
            SkittleShape()
                .fill(foreground.opacity(0.12))
                .frame(width: isPad ? 100 : 60, height: isPad ? 150 : 90)
                .rotationEffect(.degrees(14))
                .offset(x: isPad ? 40 : 20, y: isPad ? 50 : 30)
                .clipShape(UnevenRoundedRectangle(
                    topLeadingRadius: Theme.Radius.xLarge,
                    bottomLeadingRadius: Theme.Radius.medium,
                    bottomTrailingRadius: Theme.Radius.xLarge,
                    topTrailingRadius: Theme.Radius.medium
                ))

            VStack(alignment: .leading, spacing: isPad ? Theme.Space.m : Theme.Space.s) {
                Image(systemName: icon)
                    .font(isPad ? .system(size: 48).bold() : .title2.bold())
                    .foregroundStyle(foreground)
                Spacer()
                Text(title)
                    .font(.system(size: isPad ? 44 : 22, weight: .black, design: .rounded))
                    .foregroundStyle(foreground)
                Text(subtitle)
                    .font(.system(isPad ? .title3 : .caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(foreground.opacity(0.75))
                HStack {
                    Spacer()
                    ZStack {
                        Circle().fill(badge).frame(width: isPad ? 64 : 36, height: isPad ? 64 : 36)
                        Image(systemName: "play.fill")
                            .font(isPad ? .title.bold() : .subheadline.bold())
                            .foregroundStyle(Theme.ink)
                            .offset(x: isPad ? 2 : 1)
                    }
                    .shadow(color: badge.opacity(0.45), radius: isPad ? 12 : 8, y: isPad ? 6 : 4)
                }
            }
            .padding(isPad ? Theme.Space.xxl : Theme.Space.l)
        }
        .frame(height: isPad ? 280 : 200)
        .shadow(color: Theme.ink.opacity(0.18), radius: isPad ? 22 : 16, y: isPad ? 12 : 8)
    }

    private var menuStrip: some View {
        HStack(spacing: Theme.Space.s) {
            NavigationLink { MembersView() } label: {
                menuTile(symbol: "person.2.fill", number: nil, label: "メンバー", accent: Theme.pine)
            }
            .buttonStyle(PressableButtonStyle())

            NavigationLink { TeamsView() } label: {
                menuTile(symbol: "person.3.fill", number: nil, label: "チーム", accent: Theme.sky)
            }
            .buttonStyle(PressableButtonStyle())

            NavigationLink { HistoryView() } label: {
                menuTile(symbol: "clock.fill", number: nil, label: "履歴", accent: Theme.berry)
            }
            .buttonStyle(PressableButtonStyle())
        }
    }

    private func menuTile(symbol: String, number: Int?, label: String, accent: Color) -> some View {
        ZStack(alignment: .topTrailing) {
            UnevenRoundedRectangle(
                topLeadingRadius: Theme.Radius.large,
                bottomLeadingRadius: Theme.Radius.xLarge,
                bottomTrailingRadius: Theme.Radius.medium,
                topTrailingRadius: Theme.Radius.large
            )
            .fill(Theme.surface)
            .overlay(
                UnevenRoundedRectangle(
                    topLeadingRadius: Theme.Radius.large,
                    bottomLeadingRadius: Theme.Radius.xLarge,
                    bottomTrailingRadius: Theme.Radius.medium,
                    topTrailingRadius: Theme.Radius.large
                )
                .stroke(Theme.ink.opacity(0.08), lineWidth: 1)
            )
            // 装飾ストライプ
            Rectangle()
                .fill(accent)
                .frame(width: isPad ? 56 : 36, height: isPad ? 6 : 4)
                .offset(x: isPad ? -24 : -16, y: isPad ? 26 : 18)
            VStack(alignment: .leading, spacing: isPad ? Theme.Space.l : Theme.Space.m) {
                Spacer().frame(height: isPad ? 16 : 8)
                Image(systemName: symbol)
                    .font(.system(size: isPad ? 56 : 28).weight(.bold))
                    .foregroundStyle(accent)
                if let number {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(number)")
                            .font(.system(size: isPad ? 56 : 32, weight: .black, design: .rounded).monospacedDigit())
                            .foregroundStyle(Theme.ink)
                        Text(label)
                            .font(.system(isPad ? .title3 : .subheadline, design: .rounded).weight(.bold))
                            .foregroundStyle(Theme.textSecondary)
                    }
                } else {
                    Text(label)
                        .font(.system(size: isPad ? 32 : 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .padding(isPad ? Theme.Space.xl : Theme.Space.l)
        }
        .frame(maxWidth: .infinity, minHeight: isPad ? 200 : 140, alignment: .leading)
        .shadow(color: Theme.ink.opacity(0.06), radius: isPad ? 14 : 10, y: isPad ? 6 : 4)
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: isPad ? Theme.Space.l : Theme.Space.m) {
            HStack {
                Text("前回のゲーム")
                    .font(.system(isPad ? .title2 : .subheadline, design: .rounded).weight(.heavy))
                    .foregroundStyle(isPad ? Theme.ink : Theme.textSecondary)
                Spacer()
            }
            if let latest = recentGames.first {
                NavigationLink {
                    GameDetailView(game: latest)
                } label: {
                    latestGameCard(latest)
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
    }

    private func latestGameCard(_ g: Game) -> some View {
        let winnerName: String? = {
            if g.mode == .team {
                return g.teams.first(where: { $0.finishedRank == 1 })?.displayName
            } else {
                return g.participants.first(where: { $0.finishedRank == 1 })?.displayName
            }
        }()
        let winnerScore: Int? = {
            if g.mode == .team {
                return g.teams.first(where: { $0.finishedRank == 1 })?.finalScore
            } else {
                return g.participants.first(where: { $0.finishedRank == 1 })?.finalScore
            }
        }()
        let count = g.mode == .team ? g.teams.count : g.participants.count

        return VStack(alignment: .leading, spacing: isPad ? Theme.Space.l : Theme.Space.m) {
            HStack(spacing: 6) {
                Text(g.mode == .team ? "チーム戦" : "個人戦")
                    .font(.system(isPad ? .subheadline : .caption, design: .rounded).weight(.heavy))
                    .padding(.horizontal, isPad ? 12 : 8).padding(.vertical, isPad ? 6 : 3)
                    .foregroundStyle(g.mode == .team ? Theme.berry : Theme.pine)
                    .background((g.mode == .team ? Theme.berry : Theme.pine).opacity(0.12))
                    .clipShape(Capsule())
                Text(homeJpDate(g.date))
                    .font(.system(isPad ? .subheadline : .caption, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
            }

            if let winnerName {
                HStack(alignment: .firstTextBaseline, spacing: Theme.Space.m) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Image(systemName: "trophy.fill")
                                .font(isPad ? .title3 : .body)
                                .foregroundStyle(Theme.sun)
                            Text("勝者")
                                .font(.system(isPad ? .subheadline : .caption, design: .rounded).weight(.heavy))
                                .foregroundStyle(Theme.textSecondary)
                        }
                        Text(winnerName)
                            .font(.system(size: isPad ? 44 : 28, weight: .black, design: .rounded))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    Spacer()
                    if let winnerScore {
                        VStack(alignment: .trailing, spacing: -4) {
                            Text("\(winnerScore)")
                                .font(.system(size: isPad ? 72 : 44, weight: .black, design: .rounded).monospacedDigit())
                                .foregroundStyle(Theme.pine)
                            Text("点")
                                .font(.system(isPad ? .subheadline : .caption, design: .rounded).weight(.bold))
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
            } else {
                Text("\(count) \(g.mode == .team ? "チーム" : "人")参加 · 未完了")
                    .font(.system(isPad ? .title3 : .subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
            }

            HStack(spacing: 4) {
                Spacer()
                Text("詳細を見る")
                    .font(.system(isPad ? .subheadline : .caption, design: .rounded).weight(.heavy))
                Image(systemName: "arrow.right")
                    .font(isPad ? .subheadline.bold() : .caption2.bold())
            }
            .foregroundStyle(Theme.pine)
        }
        .padding(isPad ? Theme.Space.xl : Theme.Space.l)
        .frame(minHeight: isPad ? 280 : 0)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous)
                .stroke(Theme.ink.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Theme.ink.opacity(0.05), radius: 8, y: 3)
    }

    private var firstTimePrompt: some View {
        VStack(spacing: Theme.Space.m) {
            HStack(spacing: 4) {
                ForEach(0..<5) { _ in
                    SkittleShape()
                        .fill(Theme.wood)
                        .frame(width: 14, height: 22)
                }
            }
            Text("最初のゲームを始めましょう")
                .font(.headline.weight(.heavy))
                .foregroundStyle(Theme.ink)
            Text("メンバーを登録するか、新規ゲームから始めて記録を残せます。")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(Theme.Space.xl)
        .frame(maxWidth: .infinity)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                .foregroundStyle(Theme.ink.opacity(0.18))
        )
    }

    private func homeJpDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "M月d日(E) HH:mm"
        return f.string(from: d)
    }
}
