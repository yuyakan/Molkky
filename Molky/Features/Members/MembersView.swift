import SwiftUI
import SwiftData

struct MembersView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var hSize
    @Query(sort: \Member.createdAt, order: .reverse) private var members: [Member]

    @State private var showAdd = false
    @State private var newName = ""
    @State private var selectedMemberId: UUID?

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
                Text("メンバー")
                    .font(.system(.subheadline, design: .rounded).weight(.heavy))
                    .foregroundStyle(Theme.ink.opacity(0.7))
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAdd = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Theme.pine)
                }
            }
        }
        .nameInputAlert(
            title: "メンバーを追加",
            isPresented: $showAdd,
            text: $newName
        ) { name in
            newName = name
            add()
        }
    }

    private var phoneBody: some View {
        ScrollView {
            if members.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: Theme.Space.s) {
                    ForEach(Array(members.enumerated()), id: \.element.id) { (i, m) in
                        NavigationLink {
                            MemberDetailView(member: m)
                        } label: {
                            row(m, colorIndex: i, selected: false)
                        }
                        .buttonStyle(PressableButtonStyle())
                        .swipeActions {
                            Button(role: .destructive) {
                                delete(m)
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

    /// iPad: 左に一覧、右に詳細を同時表示
    private var padBody: some View {
        HStack(alignment: .top, spacing: 0) {
            // 左：一覧
            ScrollView {
                if members.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: Theme.Space.s) {
                        ForEach(Array(members.enumerated()), id: \.element.id) { (i, m) in
                            Button {
                                selectedMemberId = m.id
                            } label: {
                                row(m, colorIndex: i, selected: selectedMemberId == m.id)
                            }
                            .buttonStyle(PressableButtonStyle())
                            .swipeActions {
                                Button(role: .destructive) {
                                    if selectedMemberId == m.id { selectedMemberId = nil }
                                    delete(m)
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
            .frame(width: 360)

            // 区切り
            Rectangle()
                .fill(Theme.ink.opacity(0.08))
                .frame(width: 1)

            // 右：詳細
            Group {
                if let selected = members.first(where: { $0.id == selectedMemberId }) {
                    MemberDetailView(member: selected)
                } else {
                    detailPlaceholder
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            if selectedMemberId == nil, let first = members.first {
                selectedMemberId = first.id
            }
        }
    }

    private var detailPlaceholder: some View {
        VStack(spacing: Theme.Space.m) {
            Image(systemName: "person.crop.circle.dashed")
                .font(.system(size: 72))
                .foregroundStyle(Theme.ink.opacity(0.2))
            Text("左から選択")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Space.l) {
            HStack(spacing: 6) {
                ForEach(0..<5) { i in
                    SkittleBadge(number: "\(i + 1)", color: Theme.participantColor(index: i), size: 40)
                }
            }
            VStack(spacing: 6) {
                Text("メンバーを登録")
                    .font(.system(.title3, design: .rounded).weight(.heavy))
                    .foregroundStyle(Theme.ink)
                Text("登録するとゲームの度に名前入力が不要になります。")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            Button {
                showAdd = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                    Text("追加する").font(.system(.headline, design: .rounded).weight(.heavy))
                }
            }
            .buttonStyle(PrimaryActionStyle())
            .padding(.horizontal, 60)
            .padding(.top, Theme.Space.s)
        }
        .padding(.top, 60)
        .padding(.horizontal, Theme.Space.xl)
    }

    private func row(_ m: Member, colorIndex: Int, selected: Bool) -> some View {
        HStack(spacing: Theme.Space.m) {
            Text(m.name)
                .font(.system(.headline, design: .rounded).weight(.heavy))
                .foregroundStyle(Theme.ink)
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

    private func add() {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        modelContext.insert(Member(name: name))
        try? modelContext.save()
        newName = ""
    }
    private func delete(_ m: Member) {
        modelContext.delete(m)
        try? modelContext.save()
    }
}

struct MemberDetailView: View {
    @Bindable var member: Member
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var games: [Game]

    @State private var showDeleteConfirm = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: Theme.Space.l) {
                    profileBanner
                    historyCard
                    deleteButton
                }
                .padding(.horizontal, Theme.Space.l)
                .padding(.top, Theme.Space.s)
                .padding(.bottom, Theme.Space.xl)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { try? modelContext.save() }
        .alert(
            "\(member.name) を削除しますか？",
            isPresented: $showDeleteConfirm
        ) {
            Button("削除", role: .destructive) {
                modelContext.delete(member)
                try? modelContext.save()
                dismiss()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("このメンバーは登録から削除されます。対戦履歴は残ります。")
        }
    }

    private var deleteButton: some View {
        Button {
            showDeleteConfirm = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "trash.fill")
                Text("このメンバーを削除")
            }
            .font(.system(.subheadline, design: .rounded).weight(.heavy))
            .foregroundStyle(Theme.berry)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(Theme.berry.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                    .stroke(Theme.berry.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(PressableButtonStyle())
        .padding(.top, Theme.Space.m)
    }

    private var profileBanner: some View {
        TicketCard(accent: Theme.pine) {
            TextField("名前", text: $member.name)
                .font(.system(.title2, design: .rounded).weight(.heavy))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, Theme.Space.m)
                .padding(.vertical, Theme.Space.s)
                .background(Theme.birch.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
        }
    }

    private var historyCard: some View {
        let mine = games
            .filter { game in
                switch game.mode {
                case .individual:
                    return game.participants.contains(where: { $0.memberId == member.id })
                case .team:
                    return game.teams.contains(where: { $0.memberIds.contains(member.id) })
                }
            }
            .sorted { $0.date > $1.date }
        return TicketCard(accent: Theme.berry) {
            VStack(alignment: .leading, spacing: Theme.Space.m) {
                SectionHeader(
                    number: 1, title: "対戦履歴",
                    trailing: AnyView(
                        Text("\(mine.count)")
                            .font(.system(.subheadline, design: .monospaced).weight(.heavy))
                            .foregroundStyle(Theme.textSecondary)
                    )
                )
                if mine.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(0..<5) { _ in
                            SkittleShape().fill(Theme.wood.opacity(0.4)).frame(width: 8, height: 14)
                        }
                        Text("対戦履歴なし")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Space.s)
                } else {
                    VStack(spacing: Theme.Space.s) {
                        ForEach(mine) { g in
                            NavigationLink {
                                GameDetailView(game: g)
                            } label: {
                                historyRow(game: g)
                            }
                            .buttonStyle(PressableButtonStyle())
                        }
                    }
                }
            }
        }
    }

    private func historyRow(game g: Game) -> some View {
        HStack(spacing: Theme.Space.m) {
            Text(memberJpDate(g.date))
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.ink)
            Spacer()
            Text(g.mode == .team ? "チーム戦" : "個人戦")
                .font(.system(.caption2, design: .rounded).weight(.heavy))
                .padding(.horizontal, 6).padding(.vertical, 2)
                .foregroundStyle(g.mode == .team ? Theme.berry : Theme.pine)
                .background((g.mode == .team ? Theme.berry : Theme.pine).opacity(0.12))
                .clipShape(Capsule())
            Image(systemName: "chevron.right").foregroundStyle(Theme.ink.opacity(0.3))
        }
        .padding(Theme.Space.m)
        .background(Theme.birch.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
    }

    private func memberJpDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "M月d日(E) HH:mm"
        return f.string(from: d)
    }
}
