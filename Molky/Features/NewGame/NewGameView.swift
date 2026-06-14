import SwiftUI
import SwiftData

struct NewGameView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Member.createdAt, order: .reverse) private var members: [Member]
    @Query(sort: \Team.createdAt, order: .reverse) private var savedTeams: [Team]

    @AppStorage("default.targetScore") private var defaultTarget: Int = 50
    @AppStorage("default.overshootResetTo") private var defaultOvershoot: Int = 25
    @AppStorage("default.eliminationEnabled") private var defaultElim: Bool = true
    @AppStorage("default.maxConsecutiveMisses") private var defaultMaxMisses: Int = 3
    @AppStorage("default.missPolicy") private var defaultMissPolicyRaw: String = MissPolicy.eliminate.rawValue

    // 前回の編成スナップショット（JSON保存）
    @AppStorage("lastIndividualOrder") private var lastIndividualOrderRaw: String = ""
    @AppStorage("lastIndividualGuests") private var lastIndividualGuestsRaw: String = ""
    @AppStorage("lastTeamDrafts") private var lastTeamDraftsRaw: String = ""

    let initialMode: GameMode
    @State private var mode: GameMode

    init(initialMode: GameMode = .individual) {
        self.initialMode = initialMode
        self._mode = State(initialValue: initialMode)
    }

    @State private var selectedOrder: [UUID] = []
    /// ゲスト参加者の表示名（個人戦用）。memberId は guestParticipants の id を使う
    @State private var guestParticipants: [GuestParticipant] = []
    @State private var teamDrafts: [TeamDraft] = []

    @State private var showNewMember = false
    @State private var newMemberName = ""

    @State private var targetScore: Int = 50
    @State private var overshootResetTo: Int = 25
    @State private var missPolicy: MissPolicy = .eliminate
    @State private var maxConsecutiveMisses: Int = 3
    @State private var didLoadDefaults = false

    @State private var startedSession: GameSessionStore?

    @Environment(\.horizontalSizeClass) private var hSize
    private var isPad: Bool { hSize == .regular }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            if isPad {
                padLayout
            } else {
                phoneLayout
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Group {
                    if mode == .team {
                        Text("チーム戦")
                    } else {
                        Text("個人戦")
                    }
                }
                .font(.system(.subheadline, design: .rounded).weight(.heavy))
                .foregroundStyle(Theme.ink.opacity(0.7))
            }
        }
        .nameInputAlert(
            title: "メンバーを追加",
            isPresented: $showNewMember,
            text: $newMemberName
        ) { name in
            newMemberName = name
            addMember()
        }
        .navigationDestination(item: $startedSession) { store in
            InPlayView(store: store)
                .navigationBarBackButtonHidden()
        }
        .onAppear { loadDefaultsIfNeeded() }
    }

    // MARK: - iPhone レイアウト

    private var phoneLayout: some View {
        ScrollView {
            VStack(spacing: Theme.Space.xl) {
                if mode == .individual {
                    individualSection
                } else {
                    TeamBuilderView(
                        members: members,
                        savedTeams: savedTeams,
                        teams: $teamDrafts,
                        onAddMember: { showNewMember = true }
                    )
                }
                rulesSection
                startButton
            }
            .padding(.horizontal, Theme.Space.l)
            .padding(.bottom, Theme.Space.xxl)
        }
    }

    // MARK: - iPad 2カラムレイアウト

    private var padLayout: some View {
        HStack(alignment: .top, spacing: Theme.Space.xl) {
            // 左カラム: 参加者選択
            ScrollView {
                VStack(spacing: Theme.Space.l) {
                    if mode == .individual {
                        individualSection
                    } else {
                        TeamBuilderView(
                            members: members,
                            savedTeams: savedTeams,
                            teams: $teamDrafts,
                            onAddMember: { showNewMember = true }
                        )
                    }
                }
                .padding(.bottom, Theme.Space.xxl)
            }
            .frame(maxWidth: .infinity)

            // 右カラム: ルール + 開始ボタン
            VStack(spacing: Theme.Space.l) {
                ScrollView {
                    rulesSection
                        .padding(.bottom, Theme.Space.m)
                }
                startButton
            }
            .frame(width: 520)
        }
        .padding(.horizontal, Theme.Space.xl)
        .padding(.top, Theme.Space.m)
    }

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            HStack(spacing: 6) {
                Rectangle().fill(Theme.pine).frame(width: 18, height: 3)
                Text("セットアップ")
                    .font(.system(.subheadline, design: .rounded).weight(.heavy))
                    .foregroundStyle(Theme.textSecondary)
            }
            Group {
                if mode == .team {
                    Text("団体戦")
                } else {
                    Text("個人戦")
                }
            }
            .font(.system(size: 30, weight: .black, design: .rounded))
            .foregroundStyle(Theme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, Theme.Space.s)
    }

    private var modeSelector: some View {
        HStack(spacing: Theme.Space.m) {
            modeCard(.individual, icon: "person.fill", title: "個人戦")
            modeCard(.team, icon: "person.3.fill", title: "チーム戦")
        }
    }

    private func modeCard(_ m: GameMode, icon: String, title: LocalizedStringKey) -> some View {
        let selected = mode == m
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { mode = m }
        } label: {
            ZStack(alignment: .topLeading) {
                UnevenRoundedRectangle(
                    topLeadingRadius: Theme.Radius.large,
                    bottomLeadingRadius: Theme.Radius.small,
                    bottomTrailingRadius: Theme.Radius.large,
                    topTrailingRadius: Theme.Radius.small
                )
                .fill(selected ? AnyShapeStyle(Theme.inkGradient) : AnyShapeStyle(Theme.surface))
                .overlay(
                    UnevenRoundedRectangle(
                        topLeadingRadius: Theme.Radius.large,
                        bottomLeadingRadius: Theme.Radius.small,
                        bottomTrailingRadius: Theme.Radius.large,
                        topTrailingRadius: Theme.Radius.small
                    )
                    .strokeBorder(selected ? Color.clear : Theme.ink.opacity(0.10), lineWidth: 1)
                )
                if selected {
                    Circle().fill(Theme.sun).frame(width: 8, height: 8).padding(12)
                }
                VStack(alignment: .leading, spacing: Theme.Space.m) {
                    Spacer().frame(height: 4)
                    Image(systemName: icon)
                        .font(.title)
                        .foregroundStyle(selected ? Theme.birch : Theme.ink)
                    Text(title)
                        .font(.system(.title3, design: .rounded).weight(.heavy))
                        .foregroundStyle(selected ? Theme.birch : Theme.ink)
                }
                .padding(Theme.Space.l)
            }
            .frame(maxWidth: .infinity, minHeight: 116, alignment: .leading)
            .shadow(color: selected ? Theme.ink.opacity(0.25) : Theme.ink.opacity(0.04), radius: selected ? 14 : 4, y: selected ? 6 : 2)
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var individualSection: some View {
        TicketCard(accent: Theme.pine) {
            VStack(alignment: .leading, spacing: Theme.Space.m) {
                SectionHeader(
                    number: 2,
                    title: "参加メンバー",
                    trailing: AnyView(
                        Button {
                            showNewMember = true
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

                if !orderedEntries.isEmpty {
                    Text("手番順（長押しで並べ替え）")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                    List {
                        ForEach(Array(orderedEntries.enumerated()), id: \.element.id) { (i, e) in
                            selectedRow(index: i, entry: e)
                                .listRowBackground(
                                    RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                                        .fill(Theme.pine.opacity(0.08))
                                        .padding(.vertical, 4)
                                )
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                        }
                        .onMove(perform: moveSelected)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .scrollDisabled(true)
                    .frame(height: CGFloat(orderedEntries.count) * 72)
                    .environment(\.editMode, .constant(.active))
                }

                if !unselectedMembers.isEmpty || !unselectedGuests.isEmpty {
                    if !orderedEntries.isEmpty {
                        Rectangle()
                            .fill(Theme.ink.opacity(0.08))
                            .frame(height: 1)
                            .padding(.vertical, Theme.Space.xs)
                    }
                    Text("参加候補")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                    VStack(spacing: Theme.Space.s) {
                        ForEach(unselectedMembers) { m in
                            candidateRow(name: m.name, isGuest: false) { toggle(m) }
                        }
                        ForEach(unselectedGuests) { g in
                            candidateRow(name: g.name, isGuest: true) { toggleGuest(g) }
                        }
                    }
                }

                if members.isEmpty && guestParticipants.isEmpty {
                    emptyState(text: "メンバーを登録してください")
                }

                Button {
                    addGuest()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "person.crop.circle.badge.questionmark")
                        Text("ゲスト参加者を追加")
                    }
                    .font(.system(.subheadline, design: .rounded).weight(.heavy))
                    .foregroundStyle(Theme.sky)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1.2, dash: [4, 4]))
                            .foregroundStyle(Theme.sky.opacity(0.5))
                    )
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
    }

    private var unselectedMembers: [Member] {
        members.filter { !selectedOrder.contains($0.id) }
    }
    private var unselectedGuests: [GuestParticipant] {
        guestParticipants.filter { !selectedOrder.contains($0.id) }
    }

    private func selectedRow(index i: Int, entry e: OrderedEntry) -> some View {
        HStack(spacing: Theme.Space.m) {
            Text("\(i + 1)")
                .font(.system(.title3, design: .rounded).weight(.heavy).monospacedDigit())
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(Circle().fill(Theme.participantColor(index: i)))
            HStack(spacing: 6) {
                Text(e.name)
                    .font(.system(.body, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.ink)
                if e.isGuest {
                    Text("ゲスト")
                        .font(.system(.caption2, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.berry)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Theme.berry.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
            Spacer()
            Button {
                removeFromSelection(entry: e)
            } label: {
                Image(systemName: "minus")
                    .font(.subheadline.bold())
                    .frame(width: 32, height: 32)
                    .background(Theme.berry.opacity(0.12))
                    .foregroundStyle(Theme.berry)
                    .clipShape(Circle())
            }
            .buttonStyle(PressableButtonStyle())
        }
        .padding(.horizontal, Theme.Space.m)
        .padding(.vertical, Theme.Space.s)
        .frame(minHeight: 56)
    }

    private func moveSelected(from source: IndexSet, to destination: Int) {
        // orderedEntries は selectedOrder と同順なので、selectedOrder 自体を並び替え
        selectedOrder.move(fromOffsets: source, toOffset: destination)
    }


    private func candidateRow(name: String, isGuest: Bool, onAdd: @escaping () -> Void) -> some View {
        Button {
            onAdd()
        } label: {
            HStack(spacing: Theme.Space.m) {
                HStack(spacing: 6) {
                    Text(name)
                        .font(.system(.body, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.ink)
                    if isGuest {
                        Text("ゲスト")
                            .font(.system(.caption2, design: .rounded).weight(.bold))
                            .foregroundStyle(Theme.berry)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Theme.berry.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                    Text("追加")
                }
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(Theme.pine)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Theme.pine.opacity(0.10)))
                .overlay(Capsule().stroke(Theme.pine.opacity(0.35), lineWidth: 1))
            }
            .padding(.horizontal, Theme.Space.m)
            .padding(.vertical, Theme.Space.s)
            .background(Theme.birch.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
    }

    private func removeFromSelection(entry e: OrderedEntry) {
        selectedOrder.removeAll { $0 == e.id }
        if e.isGuest {
            // ゲストは候補に残さず完全削除
            guestParticipants.removeAll { $0.id == e.id }
        }
    }

    private func addGuest() {
        let nextIndex = guestParticipants.count + 1
        let g = GuestParticipant(id: UUID(), name: String(localized: "ゲスト\(nextIndex)"))
        guestParticipants.append(g)
        selectedOrder.append(g.id)
    }

    private func toggleGuest(_ g: GuestParticipant) {
        if let i = selectedOrder.firstIndex(of: g.id) {
            selectedOrder.remove(at: i)
        } else {
            selectedOrder.append(g.id)
        }
    }

    private func arrowButton(systemName: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.subheadline.bold())
                .frame(width: 32, height: 32)
                .background(Theme.surface)
                .foregroundStyle(Theme.ink)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(Theme.ink.opacity(0.08), lineWidth: 1))
        }
        .disabled(disabled)
        .opacity(disabled ? 0.3 : 1)
    }

    private var rulesSection: some View {
        TicketCard(accent: Theme.berry) {
            VStack(alignment: .leading, spacing: isPad ? Theme.Space.l : Theme.Space.m) {
                SectionHeader(number: mode == .individual && selectedOrder.count >= 2 ? 4 : 3, title: "ルール")
                presetChips
                Rectangle()
                    .fill(Theme.ink.opacity(0.06))
                    .frame(height: 1)
                VStack(spacing: isPad ? Theme.Space.m : Theme.Space.s) {
                    stepperRow(icon: "target", iconColor: Theme.pine, label: "目標点", value: targetScore, range: 10...100, step: 5, binding: $targetScore)
                    stepperRow(icon: "arrow.uturn.down", iconColor: Theme.sky, label: "超過時", value: overshootResetTo, range: 0...targetScore, step: 5, binding: $overshootResetTo)
                    missPolicyPicker
                    if missPolicy != .none {
                        stepperRow(
                            icon: "number",
                            iconColor: Theme.berry,
                            label: "連続ミスしきい値",
                            value: maxConsecutiveMisses,
                            range: 2...10,
                            step: 1,
                            binding: $maxConsecutiveMisses
                        )
                    }
                }
            }
        }
    }

    private var presetChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: isPad ? Theme.Space.m : Theme.Space.s) {
                ForEach(RulePreset.allCases) { preset in
                    Button {
                        applyPreset(preset)
                    } label: {
                        VStack(alignment: .leading, spacing: isPad ? 4 : 2) {
                            Text(preset.name)
                                .font(.system(isPad ? .title3 : .subheadline, design: .rounded).weight(.heavy))
                            Text(preset.shortInfo)
                                .font(.system(isPad ? .subheadline : .caption2, design: .rounded).weight(.semibold))
                        }
                        .foregroundStyle(isCurrent(preset) ? .white : Theme.ink)
                        .padding(.horizontal, isPad ? Theme.Space.l : Theme.Space.m)
                        .padding(.vertical, isPad ? Theme.Space.m : Theme.Space.s)
                        .background(
                            RoundedRectangle(cornerRadius: isPad ? 16 : 12, style: .continuous)
                                .fill(isCurrent(preset) ? AnyShapeStyle(Theme.inkGradient) : AnyShapeStyle(Theme.surface))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: isPad ? 16 : 12, style: .continuous)
                                .stroke(isCurrent(preset) ? Color.clear : Theme.ink.opacity(0.10), lineWidth: 1)
                        )
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var missPolicyPicker: some View {
        VStack(alignment: .leading, spacing: isPad ? 10 : 6) {
            HStack(spacing: Theme.Space.s) {
                Image(systemName: "xmark.octagon.fill")
                    .font(isPad ? .title3 : .body)
                    .foregroundStyle(missPolicy == .none ? Theme.textSecondary : Theme.berry)
                    .frame(width: isPad ? 32 : 22)
                Text("連続ミス時")
                    .font(.system(isPad ? .title3 : .subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.ink)
                Spacer()
            }
            HStack(spacing: isPad ? 8 : 6) {
                ForEach(MissPolicy.allCases, id: \.self) { p in
                    Button {
                        missPolicy = p
                    } label: {
                        Text(p.label)
                            .font(.system(isPad ? .subheadline : .caption, design: .rounded).weight(.heavy))
                            .foregroundStyle(missPolicy == p ? .white : Theme.ink)
                            .padding(.horizontal, isPad ? 14 : 10).padding(.vertical, isPad ? 10 : 6)
                            .background(
                                Capsule().fill(missPolicy == p ? Theme.berry : Theme.surface)
                            )
                            .overlay(
                                Capsule().stroke(missPolicy == p ? Color.clear : Theme.ink.opacity(0.15), lineWidth: 1)
                            )
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
            Text(missPolicy.shortDescription)
                .font(.system(isPad ? .subheadline : .caption2, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
                .padding(.leading, isPad ? 40 : 30)
        }
    }

    private func isCurrent(_ preset: RulePreset) -> Bool {
        preset.matches(target: targetScore, overshoot: overshootResetTo, maxMisses: maxConsecutiveMisses)
    }

    private func applyPreset(_ preset: RulePreset) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            targetScore = preset.targetScore
            overshootResetTo = preset.overshootResetTo
            maxConsecutiveMisses = preset.maxConsecutiveMisses
            // missPolicy はプリセットに含めない（ユーザの選択を保持）
        }
    }

    private func stepperRow(icon: String, iconColor: Color, label: LocalizedStringKey, value: Int, range: ClosedRange<Int>, step: Int, binding: Binding<Int>) -> some View {
        HStack(spacing: Theme.Space.s) {
            Image(systemName: icon)
                .font(isPad ? .title3 : .body)
                .foregroundStyle(iconColor)
                .frame(width: isPad ? 32 : 22)
            Text(label)
                .font(.system(isPad ? .title3 : .subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.ink)
            Spacer()
            HStack(spacing: isPad ? 8 : 4) {
                Text("\(value)")
                    .font(.system(isPad ? .largeTitle : .title3, design: .rounded).weight(.heavy).monospacedDigit())
                    .frame(minWidth: isPad ? 56 : 36)
                    .foregroundStyle(Theme.ink)
                Stepper("", value: binding, in: range, step: step)
                    .labelsHidden()
                    .scaleEffect(isPad ? 1.15 : 1.0)
            }
        }
        .padding(.vertical, isPad ? 8 : 4)
    }

    private var startButton: some View {
        Button {
            start()
        } label: {
            HStack(spacing: Theme.Space.s) {
                Image(systemName: "play.fill")
                    .font(isPad ? .title2 : .headline)
                Text(startButtonTitle)
                    .font(.system(isPad ? .title : .title3, design: .rounded).weight(.heavy))
            }
            .padding(.vertical, isPad ? 6 : 0)
        }
        .buttonStyle(PrimaryActionStyle(
            fill: AnyShapeStyle(canStart ? AnyShapeStyle(Theme.inkGradient) : AnyShapeStyle(Theme.ink.opacity(0.25))),
            shadowColor: canStart ? Theme.ink.opacity(0.3) : .clear
        ))
        .disabled(!canStart)
    }

    private func emptyState(text: LocalizedStringKey) -> some View {
        VStack(spacing: Theme.Space.s) {
            HStack(spacing: 4) {
                ForEach(0..<5) { _ in
                    SkittleShape().fill(Theme.wood.opacity(0.5)).frame(width: 10, height: 16)
                }
            }
            Text(text)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 80)
    }

    // MARK: helpers

    private var startButtonTitle: String {
        switch mode {
        case .individual:
            return selectedOrder.count >= 2
                ? String(localized: "\(selectedOrder.count)人でゲーム開始")
                : String(localized: "2人以上を選択")
        case .team:
            return startableTeams.count >= 2
                ? String(localized: "\(startableTeams.count)チームでゲーム開始")
                : String(localized: "2チーム以上を追加")
        }
    }
    private var canStart: Bool {
        switch mode {
        case .individual: return selectedOrder.count >= 2
        case .team: return startableTeams.count >= 2
        }
    }
    /// 個人戦の参加候補。Member or GuestParticipant。
    private struct OrderedEntry {
        let id: UUID
        let name: String
        let isGuest: Bool
    }

    private var orderedEntries: [OrderedEntry] {
        selectedOrder.compactMap { id in
            if let m = members.first(where: { $0.id == id }) {
                return OrderedEntry(id: m.id, name: m.name, isGuest: false)
            }
            if let g = guestParticipants.first(where: { $0.id == id }) {
                return OrderedEntry(id: g.id, name: g.name, isGuest: true)
            }
            return nil
        }
    }

    private var orderedSelected: [Member] {
        selectedOrder.compactMap { id in members.first(where: { $0.id == id }) }
    }
    private func toggle(_ m: Member) {
        if let i = selectedOrder.firstIndex(of: m.id) {
            selectedOrder.remove(at: i)
        } else {
            selectedOrder.append(m.id)
        }
    }
    private func moveUp(at i: Int) {
        guard i > 0 else { return }
        selectedOrder.swapAt(i, i - 1)
    }
    private func moveDown(at i: Int) {
        guard i < selectedOrder.count - 1 else { return }
        selectedOrder.swapAt(i, i + 1)
    }
    private func addMember() {
        let name = newMemberName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let m = Member(name: name)
        modelContext.insert(m)
        try? modelContext.save()
        if mode == .individual { selectedOrder.append(m.id) }
        newMemberName = ""
    }
    private func loadDefaultsIfNeeded() {
        guard !didLoadDefaults else { return }
        targetScore = defaultTarget
        overshootResetTo = defaultOvershoot
        maxConsecutiveMisses = defaultMaxMisses
        // 既存の defaultMissPolicy（新キー）が無ければ defaultElim から決定
        if let policy = MissPolicy(rawValue: defaultMissPolicyRaw) {
            missPolicy = policy
        } else {
            missPolicy = defaultElim ? .eliminate : .none
        }
        restoreLastComposition()
        didLoadDefaults = true
    }

    /// 前回の編成を復元（個人戦/チーム戦のモードごと）
    private func restoreLastComposition() {
        switch mode {
        case .individual:
            // ゲスト復元
            if let data = lastIndividualGuestsRaw.data(using: .utf8),
               let guests = try? JSONDecoder().decode([GuestParticipant].self, from: data) {
                guestParticipants = guests
            }
            // 手番順復元（実在するメンバー/ゲストのみ）
            if let data = lastIndividualOrderRaw.data(using: .utf8),
               let ids = try? JSONDecoder().decode([UUID].self, from: data) {
                let memberIds = Set(members.map { $0.id })
                let guestIds = Set(guestParticipants.map { $0.id })
                selectedOrder = ids.filter { memberIds.contains($0) || guestIds.contains($0) }
            }
        case .team:
            if let data = lastTeamDraftsRaw.data(using: .utf8),
               let drafts = try? JSONDecoder().decode([TeamDraft].self, from: data) {
                // 既に削除されているメンバーIDを除去
                let memberIds = Set(members.map { $0.id })
                teamDrafts = drafts.map { draft in
                    var d = draft
                    d.memberIds = d.memberIds.filter { memberIds.contains($0) }
                    d.absentMemberIds = d.absentMemberIds.intersection(memberIds)
                    return d
                }
            }
        }
    }

    /// 現在の編成をスナップショット保存
    private func saveLastComposition() {
        switch mode {
        case .individual:
            if let data = try? JSONEncoder().encode(selectedOrder), let json = String(data: data, encoding: .utf8) {
                lastIndividualOrderRaw = json
            }
            if let data = try? JSONEncoder().encode(guestParticipants), let json = String(data: data, encoding: .utf8) {
                lastIndividualGuestsRaw = json
            }
        case .team:
            if let data = try? JSONEncoder().encode(teamDrafts), let json = String(data: data, encoding: .utf8) {
                lastTeamDraftsRaw = json
            }
        }
    }
    private func start() {
        saveLastComposition()
        let cfg = GameConfig(
            targetScore: targetScore,
            overshootResetTo: overshootResetTo,
            maxConsecutiveMisses: maxConsecutiveMisses,
            missPolicy: missPolicy
        )
        switch mode {
        case .individual:
            let parts = orderedEntries.enumerated().map { (i, e) in
                PersistedParticipant(
                    memberId: e.id,
                    name: e.name,
                    turnIndex: i,
                    finalScore: 0,
                    finishedRank: nil,
                    isEliminated: false,
                    isGuest: e.isGuest
                )
            }
            startedSession = GameSessionStore(config: cfg, participants: parts)
        case .team:
            let teams: [PersistedTeam] = startableTeams.enumerated().map { (i, t) in
                // 欠席者を除いたメンバーのみで開始
                let activeIds = t.activeMemberIds
                let names = activeIds.compactMap { id in members.first(where: { $0.id == id })?.name }
                return PersistedTeam(
                    id: t.id, name: t.name, turnIndex: i,
                    memberIds: activeIds, memberNames: names,
                    finalScore: 0, finishedRank: nil, isEliminated: false,
                    isGuest: t.isGuest || t.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
            }
            startedSession = GameSessionStore(config: cfg, teams: teams)
        }
    }

    /// 開始可能なチーム（追加されているチーム全て。メンバー未割当・名前空欄でも可）
    private var startableTeams: [TeamDraft] {
        teamDrafts
    }
}

extension GameSessionStore: Hashable {
    static func == (lhs: GameSessionStore, rhs: GameSessionStore) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct GuestParticipant: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
}

/// 新規ゲーム作成時のルールプリセット。目標点が異なるものだけを並べる。
/// 連続ミス時の挙動は「ルール」セクション内で独立して選ぶ。
enum RulePreset: String, CaseIterable, Identifiable {
    case standard  // 標準: 50/25/3連続
    case short     // ショート: 30/15/3連続
    case long      // ロング: 70/35/4連続

    var id: String { rawValue }

    var name: String {
        switch self {
        case .standard: return String(localized: "標準")
        case .short: return String(localized: "ショート")
        case .long: return String(localized: "ロング")
        }
    }

    var shortInfo: String {
        switch self {
        case .standard: return String(localized: "50点")
        case .short: return String(localized: "30点")
        case .long: return String(localized: "70点")
        }
    }

    var targetScore: Int {
        switch self {
        case .standard: return 50
        case .short: return 30
        case .long: return 70
        }
    }

    var overshootResetTo: Int {
        switch self {
        case .standard: return 25
        case .short: return 15
        case .long: return 35
        }
    }

    var maxConsecutiveMisses: Int {
        switch self {
        case .standard, .short: return 3
        case .long: return 4
        }
    }

    /// 連続ミス挙動はプリセットでは決めない（独立選択）。一致判定にも使わない。
    func matches(target: Int, overshoot: Int, maxMisses: Int) -> Bool {
        target == targetScore
            && overshoot == overshootResetTo
            && maxMisses == maxConsecutiveMisses
    }
}

