import SwiftUI
import SwiftData

struct TeamsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var hSize
    @Query(sort: \Team.createdAt, order: .reverse) private var teams: [Team]
    @Query(sort: \Member.createdAt, order: .reverse) private var members: [Member]

    @State private var showAdd = false
    @State private var newName = ""
    @State private var selectedTeamId: UUID?

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
                Text("チーム")
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
            title: "チームを追加",
            isPresented: $showAdd,
            text: $newName,
            placeholder: "チーム名"
        ) { name in
            newName = name
            add()
        }
    }

    private var phoneBody: some View {
        ScrollView {
            if teams.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: Theme.Space.s) {
                    ForEach(Array(teams.enumerated()), id: \.element.id) { (i, t) in
                        NavigationLink {
                            TeamDetailView(team: t)
                        } label: {
                            row(t, colorIndex: i, selected: false)
                        }
                        .buttonStyle(PressableButtonStyle())
                        .swipeActions {
                            Button(role: .destructive) {
                                delete(t)
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
                if teams.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: Theme.Space.s) {
                        ForEach(Array(teams.enumerated()), id: \.element.id) { (i, t) in
                            Button {
                                selectedTeamId = t.id
                            } label: {
                                row(t, colorIndex: i, selected: selectedTeamId == t.id)
                            }
                            .buttonStyle(PressableButtonStyle())
                            .swipeActions {
                                Button(role: .destructive) {
                                    if selectedTeamId == t.id { selectedTeamId = nil }
                                    delete(t)
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

            Rectangle()
                .fill(Theme.ink.opacity(0.08))
                .frame(width: 1)

            Group {
                if let selected = teams.first(where: { $0.id == selectedTeamId }) {
                    TeamDetailView(team: selected)
                } else {
                    detailPlaceholder
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            if selectedTeamId == nil, let first = teams.first {
                selectedTeamId = first.id
            }
        }
    }

    private var detailPlaceholder: some View {
        VStack(spacing: Theme.Space.m) {
            Image(systemName: "person.3.sequence")
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
                ForEach(0..<3) { i in
                    SkittleBadge(number: ["A","B","C"][i], color: Theme.participantColor(index: i), size: 44)
                }
            }
            VStack(spacing: 6) {
                Text("チームを登録")
                    .font(.system(.title3, design: .rounded).weight(.heavy))
                    .foregroundStyle(Theme.ink)
                Text("よく使う編成を保存すると、ゲーム開始時にタップだけで再現できます。")
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

    private func row(_ t: Team, colorIndex: Int, selected: Bool) -> some View {
        let names = t.memberIds.compactMap { id in members.first(where: { $0.id == id })?.name }
        return HStack(spacing: Theme.Space.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text(t.name.isEmpty ? "未命名チーム" : t.name)
                    .font(.system(.headline, design: .rounded).weight(.heavy))
                    .foregroundStyle(Theme.ink)
                if names.isEmpty {
                    Text("メンバー未割当")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.warning)
                } else {
                    Text(names.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Text("\(t.memberIds.count)")
                .font(.system(.title3, design: .rounded).weight(.heavy).monospacedDigit())
                .foregroundStyle(Theme.textSecondary)
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
        modelContext.insert(Team(name: name, memberIds: []))
        try? modelContext.save()
        newName = ""
    }

    private func delete(_ t: Team) {
        modelContext.delete(t)
        try? modelContext.save()
    }
}

struct TeamDetailView: View {
    @Bindable var team: Team
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Member.createdAt, order: .reverse) private var members: [Member]

    @State private var showAddMember = false
    @State private var newMemberName = ""
    @State private var showMemberPicker = false
    @State private var showDeleteConfirm = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: Theme.Space.l) {
                    nameCard
                    membersCard
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
            "\(team.name.isEmpty ? "このチーム" : team.name) を削除しますか？",
            isPresented: $showDeleteConfirm
        ) {
            Button("削除", role: .destructive) {
                modelContext.delete(team)
                try? modelContext.save()
                dismiss()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("チームの登録が削除されます。所属メンバーは削除されません。対戦履歴は残ります。")
        }
        .nameInputAlert(
            title: "新しいメンバーを追加",
            isPresented: $showAddMember,
            text: $newMemberName
        ) { name in
            newMemberName = name
            addNewMember()
        }
        .sheet(isPresented: $showMemberPicker) {
            MemberPickerSheet(
                allMembers: members,
                excludedIds: Set(team.memberIds),
                onPick: { m in
                    add(m)
                    showMemberPicker = false
                },
                onAddNew: {
                    showMemberPicker = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showAddMember = true
                    }
                }
            )
            .presentationDetents([.large])
        }
    }

    private var deleteButton: some View {
        Button {
            showDeleteConfirm = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "trash.fill")
                Text("このチームを削除")
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

    private var nameCard: some View {
        TicketCard(accent: Theme.pine) {
            VStack(alignment: .leading, spacing: Theme.Space.m) {
                SectionHeader(number: 1, title: "チーム名")
                TextField("チーム名", text: $team.name)
                    .font(.system(.title3, design: .rounded).weight(.heavy))
                    .padding(.horizontal, Theme.Space.m)
                    .padding(.vertical, Theme.Space.s)
                    .background(Theme.birch.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
            }
        }
    }

    private var membersCard: some View {
        let assigned = team.memberIds.compactMap { id in members.first(where: { $0.id == id }) }
        return TicketCard(accent: Theme.sky) {
            VStack(alignment: .leading, spacing: Theme.Space.m) {
                SectionHeader(
                    number: 2,
                    title: "所属メンバー",
                    trailing: AnyView(
                        Button {
                            showMemberPicker = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                Text("追加")
                            }
                            .font(.subheadline.weight(.heavy))
                            .foregroundStyle(Theme.pine)
                        }
                    )
                )
                Text("手番順は対戦開始時に決定します")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                if assigned.isEmpty {
                    Text("メンバー未割当")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 60)
                } else {
                    VStack(spacing: Theme.Space.s) {
                        ForEach(assigned) { m in
                            assignedRow(m)
                        }
                    }
                }
            }
        }
    }

    private func assignedRow(_ m: Member) -> some View {
        HStack(spacing: Theme.Space.m) {
            Text(m.name)
                .font(.system(.body, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.ink)
            Spacer()
            Button {
                remove(m)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "minus")
                    Text("削除")
                }
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(Theme.berry)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Theme.berry.opacity(0.10)))
                .overlay(Capsule().stroke(Theme.berry.opacity(0.35), lineWidth: 1))
            }
            .buttonStyle(PressableButtonStyle())
        }
        .padding(.horizontal, Theme.Space.m)
        .padding(.vertical, Theme.Space.s + 2)
        .background(Theme.pine.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
    }

    private func add(_ m: Member) {
        guard !team.memberIds.contains(m.id) else { return }
        var ids = team.memberIds
        ids.append(m.id)
        team.memberIds = ids
    }

    private func remove(_ m: Member) {
        var ids = team.memberIds
        ids.removeAll { $0 == m.id }
        team.memberIds = ids
    }

    private func addNewMember() {
        let name = newMemberName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let m = Member(name: name)
        modelContext.insert(m)
        try? modelContext.save()
        // 新規追加したメンバーは自動的にこのチームへ追加
        var ids = team.memberIds
        ids.append(m.id)
        team.memberIds = ids
        newMemberName = ""
    }

}

// MARK: - Member picker sheet

private struct MemberPickerSheet: View {
    let allMembers: [Member]
    let excludedIds: Set<UUID>
    let onPick: (Member) -> Void
    let onAddNew: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: Theme.Space.s) {
                        if available.isEmpty {
                            VStack(spacing: Theme.Space.s) {
                                Text("追加できるメンバーがいません")
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.textSecondary)
                                Button {
                                    onAddNew()
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "plus")
                                        Text("新しいメンバーを追加")
                                    }
                                    .font(.subheadline.weight(.heavy))
                                    .foregroundStyle(Theme.pine)
                                }
                                .buttonStyle(PressableButtonStyle())
                            }
                            .frame(maxWidth: .infinity, minHeight: 120)
                        } else {
                            ForEach(available) { m in
                                Button {
                                    onPick(m)
                                } label: {
                                    HStack(spacing: Theme.Space.m) {
                                        Text(m.name)
                                            .font(.system(.body, design: .rounded).weight(.bold))
                                            .foregroundStyle(Theme.ink)
                                        Spacer()
                                        Image(systemName: "plus.circle.fill")
                                            .foregroundStyle(Theme.pine)
                                            .font(.title3)
                                    }
                                    .padding(Theme.Space.m)
                                    .background(Theme.surface)
                                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                                            .stroke(Theme.ink.opacity(0.08), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(PressableButtonStyle())
                            }
                            Button {
                                onAddNew()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus")
                                    Text("新しいメンバーを追加")
                                }
                                .font(.system(.subheadline, design: .rounded).weight(.heavy))
                                .foregroundStyle(Theme.pine)
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .background(
                                    RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                                        .strokeBorder(style: StrokeStyle(lineWidth: 1.2, dash: [4, 4]))
                                        .foregroundStyle(Theme.pine.opacity(0.5))
                                )
                            }
                            .buttonStyle(PressableButtonStyle())
                            .padding(.top, Theme.Space.s)
                        }
                    }
                    .padding(.horizontal, Theme.Space.l)
                    .padding(.top, Theme.Space.s)
                    .padding(.bottom, Theme.Space.xl)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("メンバーを追加")
                        .font(.system(.subheadline, design: .rounded).weight(.heavy))
                        .foregroundStyle(Theme.ink)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    private var available: [Member] {
        allMembers.filter { !excludedIds.contains($0.id) }
    }
}
