import SwiftUI
import SwiftData

struct TeamDraft: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var memberIds: [UUID]
    /// 「相手チーム」等の名前未入力枠（ゲスト扱い）
    var isGuest: Bool = false
    /// 今回のゲームでは欠席するメンバー（保存チーム側の構成には影響しない）
    var absentMemberIds: Set<UUID> = []

    /// 今回参加するメンバーID（memberIds から欠席を除く）
    var activeMemberIds: [UUID] {
        memberIds.filter { !absentMemberIds.contains($0) }
    }

    // 既存データとの後方互換のためのCodable実装
    private enum CodingKeys: String, CodingKey {
        case id, name, memberIds, isGuest, absentMemberIds
    }

    init(id: UUID, name: String, memberIds: [UUID], isGuest: Bool = false, absentMemberIds: Set<UUID> = []) {
        self.id = id
        self.name = name
        self.memberIds = memberIds
        self.isGuest = isGuest
        self.absentMemberIds = absentMemberIds
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.name = try c.decode(String.self, forKey: .name)
        self.memberIds = try c.decode([UUID].self, forKey: .memberIds)
        self.isGuest = try c.decodeIfPresent(Bool.self, forKey: .isGuest) ?? false
        self.absentMemberIds = try c.decodeIfPresent(Set<UUID>.self, forKey: .absentMemberIds) ?? []
    }
}

struct TeamBuilderView: View {
    let members: [Member]
    let savedTeams: [Team]
    @Binding var teams: [TeamDraft]
    var onAddMember: () -> Void

    private let teamLabels = ["A", "B", "C", "D", "E", "F"]

    @State private var pickingForIndex: Int? = nil
    @State private var showAddSheet = false
    @State private var addPickerIndex: Int? = nil

    var body: some View {
        VStack(spacing: Theme.Space.l) {
            teamsCard
            addRow
        }
        .sheet(item: Binding(
            get: { pickingForIndex.map { IndexBox(value: $0) } },
            set: { pickingForIndex = $0?.value }
        )) { box in
            TeamEditSheet(
                team: $teams[box.value],
                allMembers: members,
                savedTeams: savedTeams,
                onAddNewMember: onAddMember
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showAddSheet) {
            AddTeamSheet(
                savedTeams: savedTeams,
                existingIds: Set(teams.map { $0.id }),
                onPickSaved: { t in
                    appendSaved(t)
                    showAddSheet = false
                },
                onCreateEmpty: {
                    appendEmpty()
                    showAddSheet = false
                }
            )
            .presentationDetents([.medium])
        }
    }

    // MARK: - Teams card

    private var teamsCard: some View {
        TicketCard(accent: Theme.pine) {
            VStack(alignment: .leading, spacing: Theme.Space.m) {
                SectionHeader(
                    number: 2,
                    title: "参加チーム",
                    trailing: AnyView(
                        Text("\(teams.count)")
                            .font(.system(.subheadline, design: .monospaced).weight(.heavy))
                            .foregroundStyle(Theme.textSecondary)
                    )
                )
                if teams.isEmpty {
                    Text("チームを追加してください")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 60)
                } else {
                    VStack(spacing: Theme.Space.s) {
                        ForEach(Array(teams.enumerated()), id: \.element.id) { (i, t) in
                            teamRow(at: i)
                        }
                    }
                }
            }
        }
    }

    private func teamRow(at i: Int) -> some View {
        let t = teams[i]
        let isEmptyName = t.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let displayName = isEmptyName ? "\(teamLabels[min(i, teamLabels.count - 1)])チーム" : t.name
        let assignedMembers = t.memberIds.compactMap { id in members.first(where: { $0.id == id }) }

        return VStack(alignment: .leading, spacing: Theme.Space.s) {
            // ヘッダー: 順番バッジ + 上下ボタン + チーム名 + 編集 + 削除
            HStack(spacing: Theme.Space.m) {
                SkittleBadge(number: teamLabels[min(i, teamLabels.count - 1)], color: Theme.participantColor(index: i), size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(displayName)
                            .font(.system(.headline, design: .rounded).weight(.heavy))
                            .foregroundStyle(Theme.ink)
                        if isEmptyName || t.isGuest {
                            Text("未登録")
                                .font(.system(.caption2, design: .rounded).weight(.bold))
                                .foregroundStyle(Theme.berry)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Theme.berry.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                    Text("\(i + 1)番手")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                VStack(spacing: 4) {
                    teamMoveButton(systemName: "chevron.up", disabled: i == 0) { moveTeamUp(i) }
                    teamMoveButton(systemName: "chevron.down", disabled: i == teams.count - 1) { moveTeamDown(i) }
                }
                Button {
                    pickingForIndex = i
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.title3)
                        .foregroundStyle(Theme.pine)
                }
                .buttonStyle(PressableButtonStyle())
                Button {
                    removeAt(i)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Theme.ink.opacity(0.3))
                }
                .buttonStyle(.plain)
            }

            if !assignedMembers.isEmpty {
                Text("投擲順（長押しで並べ替え）")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                List {
                    ForEach(Array(assignedMembers.enumerated()), id: \.element.id) { (_, m) in
                        memberOrderRow(teamIndex: i, member: m)
                            .listRowBackground(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Theme.surface)
                                    .padding(.vertical, 3)
                            )
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 3, leading: 0, bottom: 3, trailing: 0))
                    }
                    .onMove { source, destination in
                        moveMember(inTeam: i, from: source, to: destination)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollDisabled(true)
                .frame(height: CGFloat(assignedMembers.count) * 56)
                .environment(\.editMode, .constant(.active))
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle.fill")
                        .font(.caption2)
                    Text("メンバーなしでも開始できます（相手チーム扱い）")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(Theme.Space.m)
        .background(Theme.birch.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
    }

    private func memberOrderRow(teamIndex: Int, member m: Member) -> some View {
        let team = teams[teamIndex]
        let isAbsent = team.absentMemberIds.contains(m.id)
        // 出席者だけで連番（欠席者は順番なし）
        let activeOrder: Int? = {
            if isAbsent { return nil }
            return team.activeMemberIds.firstIndex(of: m.id)
        }()
        return HStack(spacing: Theme.Space.s) {
            if let pos = activeOrder {
                Text("\(pos + 1)")
                    .font(.system(.caption, design: .rounded).weight(.heavy).monospacedDigit())
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Theme.participantColor(index: teamIndex)))
            } else {
                Image(systemName: "minus")
                    .font(.caption2.bold())
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Theme.ink.opacity(0.08)))
            }
            Text(m.name)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(isAbsent ? Theme.textSecondary : Theme.ink)
                .strikethrough(isAbsent)
            if isAbsent {
                Text("欠席")
                    .font(.system(.caption2, design: .rounded).weight(.heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(Theme.textSecondary))
            }
            Spacer()
            Button {
                toggleAbsence(teamIndex: teamIndex, memberId: m.id)
            } label: {
                Text(isAbsent ? "復帰" : "欠席")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(isAbsent ? Theme.pine : Theme.berry)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(
                        Capsule().fill(isAbsent ? Theme.pine.opacity(0.12) : Theme.berry.opacity(0.12))
                    )
                    .overlay(
                        Capsule().stroke(isAbsent ? Theme.pine.opacity(0.35) : Theme.berry.opacity(0.35), lineWidth: 1)
                    )
            }
            .buttonStyle(PressableButtonStyle())
        }
        .padding(.horizontal, Theme.Space.s)
        .padding(.vertical, 6)
    }

    private func toggleAbsence(teamIndex: Int, memberId: UUID) {
        var ids = teams[teamIndex].absentMemberIds
        if ids.contains(memberId) {
            ids.remove(memberId)
        } else {
            ids.insert(memberId)
        }
        teams[teamIndex].absentMemberIds = ids
    }

    private func moveMember(inTeam i: Int, from source: IndexSet, to destination: Int) {
        var ids = teams[i].memberIds
        ids.move(fromOffsets: source, toOffset: destination)
        teams[i].memberIds = ids
    }

    private func teamMoveButton(systemName: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.caption.bold())
                .frame(width: 26, height: 22)
                .background(Theme.surface)
                .foregroundStyle(Theme.ink)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Theme.ink.opacity(0.10), lineWidth: 1)
                )
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(disabled)
        .opacity(disabled ? 0.3 : 1)
    }

    private func moveTeamUp(_ i: Int) {
        guard i > 0 else { return }
        teams.swapAt(i, i - 1)
    }

    private func moveTeamDown(_ i: Int) {
        guard i < teams.count - 1 else { return }
        teams.swapAt(i, i + 1)
    }

    // MARK: - Add row

    private var addRow: some View {
        Button {
            showAddSheet = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                Text("チームを追加")
                    .font(.system(.subheadline, design: .rounded).weight(.heavy))
            }
            .foregroundStyle(Theme.pine)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    .foregroundStyle(Theme.pine.opacity(0.5))
            )
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(teams.count >= 6)
        .opacity(teams.count >= 6 ? 0.4 : 1)
    }

    // MARK: - Mutations

    private func appendSaved(_ t: Team) {
        teams.append(TeamDraft(id: t.id, name: t.name, memberIds: t.memberIds, isGuest: false))
    }
    private func appendEmpty() {
        teams.append(TeamDraft(id: UUID(), name: "", memberIds: [], isGuest: false))
    }
    private func removeAt(_ i: Int) {
        teams.remove(at: i)
    }
}

// MARK: - Identifiable wrapper for sheet

private struct IndexBox: Identifiable {
    var id: Int { value }
    let value: Int
}

// MARK: - Add team sheet

private struct AddTeamSheet: View {
    let savedTeams: [Team]
    let existingIds: Set<UUID>
    let onPickSaved: (Team) -> Void
    let onCreateEmpty: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Member.createdAt, order: .reverse) private var members: [Member]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: Theme.Space.l) {
                        if !availableTeams.isEmpty {
                            TicketCard(accent: Theme.pine) {
                                VStack(alignment: .leading, spacing: Theme.Space.m) {
                                    SectionHeader(number: 1, title: "保存済みチームから")
                                    VStack(spacing: Theme.Space.s) {
                                        ForEach(availableTeams) { t in
                                            Button { onPickSaved(t) } label: {
                                                savedTeamRow(t)
                                            }
                                            .buttonStyle(PressableButtonStyle())
                                        }
                                    }
                                }
                            }
                        }
                        TicketCard(accent: Theme.sky) {
                            VStack(alignment: .leading, spacing: Theme.Space.m) {
                                SectionHeader(number: 2, title: "新規")
                                Button { onCreateEmpty() } label: {
                                    createOptionRow(
                                        icon: "plus.rectangle.fill",
                                        title: "新しいチームを作る",
                                        subtitle: "名前は後から入力可（空欄でも開始可）"
                                    )
                                }
                                .buttonStyle(PressableButtonStyle())
                            }
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
                    Text("チームを追加")
                        .font(.system(.subheadline, design: .rounded).weight(.heavy))
                        .foregroundStyle(Theme.ink)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    private var availableTeams: [Team] {
        savedTeams.filter { !existingIds.contains($0.id) }
    }

    private func savedTeamRow(_ t: Team) -> some View {
        let names = t.memberIds.compactMap { id in members.first(where: { $0.id == id })?.name }
        return HStack(spacing: Theme.Space.m) {
            SkittleBadge(number: String(t.name.prefix(1).isEmpty ? "?" : String(t.name.prefix(1))), color: Theme.pine, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(t.name.isEmpty ? "未命名チーム" : t.name)
                    .font(.system(.body, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.ink)
                if !names.isEmpty {
                    Text(names.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Image(systemName: "arrow.right.circle.fill")
                .foregroundStyle(Theme.pine)
        }
        .padding(.horizontal, Theme.Space.m)
        .padding(.vertical, Theme.Space.s)
        .background(Theme.birch.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
    }

    private func createOptionRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: Theme.Space.m) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Theme.sky)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.subheadline, design: .rounded).weight(.heavy))
                    .foregroundStyle(Theme.ink)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(Theme.ink.opacity(0.3))
        }
        .padding(.horizontal, Theme.Space.m)
        .padding(.vertical, Theme.Space.m)
        .background(Theme.birch.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
    }
}

// MARK: - Team edit sheet

private struct TeamEditSheet: View {
    @Binding var team: TeamDraft
    let allMembers: [Member]
    let savedTeams: [Team]
    let onAddNewMember: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var showSaveConfirm = false
    @State private var showMemberPicker = false
    @State private var showNewMemberAlert = false
    @State private var newMemberName = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: Theme.Space.l) {
                        nameCard
                        membersCard
                        saveButton
                    }
                    .padding(.horizontal, Theme.Space.l)
                    .padding(.top, Theme.Space.s)
                    .padding(.bottom, Theme.Space.xl)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("チームの編集")
                        .font(.system(.subheadline, design: .rounded).weight(.heavy))
                        .foregroundStyle(Theme.ink)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完了") { dismiss() }
                }
            }
            .alert("保存しました", isPresented: $showSaveConfirm) {
                Button("OK", role: .cancel) {}
            }
            .sheet(isPresented: $showMemberPicker) {
                MemberPickerSheetInline(
                    allMembers: allMembers,
                    excludedIds: Set(team.memberIds),
                    onPick: { m in
                        add(m)
                        showMemberPicker = false
                    },
                    onAddNew: {
                        showMemberPicker = false
                        // 次の runloop でアラートを開く（シート閉鎖との競合回避）
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showNewMemberAlert = true
                        }
                    }
                )
                .presentationDetents([.medium, .large])
            }
            .alert("新しいメンバーを追加", isPresented: $showNewMemberAlert) {
                TextField("名前", text: $newMemberName)
                Button("追加") { commitNewMember() }
                Button("キャンセル", role: .cancel) { newMemberName = "" }
            }
        }
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

    private func commitNewMember() {
        let name = newMemberName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let m = Member(name: name)
        modelContext.insert(m)
        try? modelContext.save()
        var ids = team.memberIds
        ids.append(m.id)
        team.memberIds = ids
        newMemberName = ""
    }

    private var nameCard: some View {
        TicketCard(accent: Theme.pine) {
            VStack(alignment: .leading, spacing: Theme.Space.s) {
                SectionHeader(number: 1, title: "チーム名")
                TextField("（未入力で「相手チーム」扱い）", text: $team.name)
                    .font(.system(.title3, design: .rounded).weight(.heavy))
                    .padding(.horizontal, Theme.Space.m)
                    .padding(.vertical, Theme.Space.s)
                    .background(Theme.birch.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
                    .onChange(of: team.name) { _, new in
                        if !new.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            team.isGuest = false
                        }
                    }
            }
        }
    }

    private var membersCard: some View {
        let assigned = team.memberIds.compactMap { id in allMembers.first(where: { $0.id == id }) }
        return TicketCard(accent: Theme.sky) {
            VStack(alignment: .leading, spacing: Theme.Space.m) {
                SectionHeader(
                    number: 2,
                    title: "メンバー",
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
                Text("投擲順は対戦中にローテーションされます")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                if assigned.isEmpty {
                    VStack(spacing: 4) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(Theme.textSecondary)
                        Text("メンバーなしでも開始できます")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.textSecondary)
                        Text("相手チームとして扱われます")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
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

    private var saveButton: some View {
        let isExisting = savedTeams.contains(where: { $0.id == team.id })
        let nameTrimmed = team.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let canSave = !nameTrimmed.isEmpty
        return Button {
            saveToLibrary(isExisting: isExisting, trimmedName: nameTrimmed)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isExisting ? "tray.and.arrow.down.fill" : "bookmark.fill")
                Text(isExisting ? "保存済みチームを更新" : "このチームを保存")
                    .font(.system(.subheadline, design: .rounded).weight(.heavy))
            }
        }
        .buttonStyle(GhostActionStyle())
        .disabled(!canSave)
        .opacity(canSave ? 1 : 0.4)
    }

    private func saveToLibrary(isExisting: Bool, trimmedName: String) {
        if isExisting, let existing = savedTeams.first(where: { $0.id == team.id }) {
            existing.name = trimmedName
            existing.memberIds = team.memberIds
        } else {
            let t = Team(id: team.id, name: trimmedName, memberIds: team.memberIds)
            modelContext.insert(t)
        }
        try? modelContext.save()
        showSaveConfirm = true
    }
}

// MARK: - Member picker (inline duplicate to keep TeamsView's private)

private struct MemberPickerSheetInline: View {
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
