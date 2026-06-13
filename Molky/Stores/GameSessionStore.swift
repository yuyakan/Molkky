import Foundation
import Observation
import SwiftData

enum GameMode {
    case individual
    case team

    var persisted: GameModeValue {
        switch self {
        case .individual: return .individual
        case .team: return .team
        }
    }
}

@Observable
final class GameSessionStore: Identifiable {
    let id: UUID = UUID()
    let mode: GameMode
    let config: GameConfig
    let participants: [PersistedParticipant]
    let teams: [PersistedTeam]
    private(set) var events: [ThrowEvent] = []
    private(set) var state: GameState

    init(config: GameConfig, participants: [PersistedParticipant]) {
        self.mode = .individual
        self.config = config
        self.participants = participants
        self.teams = []
        self.state = GameEngine.initialState(participantCount: participants.count)
    }

    init(config: GameConfig, teams: [PersistedTeam]) {
        self.mode = .team
        self.config = config
        self.participants = []
        self.teams = teams
        self.state = GameEngine.initialState(participantCount: teams.count)
    }

    var participantCount: Int {
        switch mode {
        case .individual: return participants.count
        case .team: return teams.count
        }
    }

    var currentParticipant: PersistedParticipant? {
        guard mode == .individual,
              let idx = state.currentTurnParticipantIndex,
              participants.indices.contains(idx) else { return nil }
        return participants[idx]
    }

    var currentTeam: PersistedTeam? {
        guard mode == .team,
              let idx = state.currentTurnParticipantIndex,
              teams.indices.contains(idx) else { return nil }
        return teams[idx]
    }

    /// チーム戦における「次に投げるメンバーID」。配下メンバー数で events をカウントしてローテーション。
    var currentThrowerMemberId: UUID? {
        guard mode == .team, let team = currentTeam else { return nil }
        let thrown = events.filter { $0.participantIndex == team.turnIndex }.count
        guard !team.memberIds.isEmpty else { return nil }
        return team.memberIds[thrown % team.memberIds.count]
    }

    var currentThrowerName: String? {
        guard let id = currentThrowerMemberId,
              let team = currentTeam,
              let i = team.memberIds.firstIndex(of: id),
              team.memberNames.indices.contains(i) else { return nil }
        return team.memberNames[i]
    }

    func record(points: Int) {
        guard !state.isFinished else { return }
        guard let idx = state.currentTurnParticipantIndex else { return }
        let throwerId = currentThrowerMemberId
        let ev = ThrowEvent(participantIndex: idx, points: points, throwerMemberId: throwerId)
        events.append(ev)
        recompute()
    }

    func undo() {
        guard !events.isEmpty else { return }
        events.removeLast()
        recompute()
    }

    func reset() {
        events.removeAll()
        recompute()
    }

    /// 現在のスコアで強制的にゲームを終了する。最高得点者を勝者として順位確定。
    /// （途中終了用。50点到達による正規勝利ではないので isFinished と finishedRank を直接書き換える）
    func forceFinish() {
        // 最高得点の参加者を勝者として確定
        let activeIndices = state.participants.indices.filter { !state.participants[$0].isEliminated && state.participants[$0].finishedRank == nil }
        guard !activeIndices.isEmpty else {
            state.isFinished = true
            state.currentTurnParticipantIndex = nil
            return
        }
        // 既に勝者が確定している場合（誰かが50点ぴったり到達など）はそのまま
        if state.winnerIndex != nil {
            state.isFinished = true
            state.currentTurnParticipantIndex = nil
            return
        }
        // 最高得点で順位付け（同点は同じ順位とせず、配列順で前の方を上位とする）
        let sorted = activeIndices.sorted { state.participants[$0].score > state.participants[$1].score }
        for (offset, idx) in sorted.enumerated() {
            state.participants[idx].finishedRank = offset + 1
        }
        if let winner = sorted.first {
            state.winnerIndex = winner
        }
        state.isFinished = true
        state.currentTurnParticipantIndex = nil
    }

    private func recompute() {
        state = GameEngine.reduce(config: config, throws: events, participantCount: participantCount)
    }

    func participantState(at index: Int) -> ParticipantState? {
        guard state.participants.indices.contains(index) else { return nil }
        return state.participants[index]
    }

    func remainingToWin(forParticipantAt index: Int) -> Int {
        guard let p = participantState(at: index) else { return config.targetScore }
        return max(config.targetScore - p.score, 0)
    }

    func nextThrowerName(forTeamIndex teamIdx: Int) -> String? {
        guard mode == .team, teams.indices.contains(teamIdx) else { return nil }
        let team = teams[teamIdx]
        let thrown = events.filter { $0.participantIndex == teamIdx }.count
        guard !team.memberIds.isEmpty else { return nil }
        let i = thrown % team.memberIds.count
        return team.memberNames.indices.contains(i) ? team.memberNames[i] : nil
    }

    func saveToGame(_ game: Game) {
        game.targetScore = config.targetScore
        game.overshootResetTo = config.overshootResetTo
        game.eliminationEnabled = config.eliminationEnabled
        game.maxConsecutiveMisses = config.maxConsecutiveMisses
        game.missPolicy = config.missPolicy
        game.isFinished = state.isFinished
        game.throwEvents = events
        game.mode = mode.persisted

        switch mode {
        case .individual:
            var ps = participants
            for i in ps.indices {
                if let s = participantState(at: i) {
                    ps[i].finalScore = s.score
                    ps[i].finishedRank = s.finishedRank
                    ps[i].isEliminated = s.isEliminated
                }
            }
            game.participants = ps
            game.teams = []
            if let winIdx = state.winnerIndex, ps.indices.contains(winIdx) {
                game.winnerMemberId = ps[winIdx].memberId
            } else {
                game.winnerMemberId = nil
            }
            game.winnerTeamId = nil

        case .team:
            var ts = teams
            for i in ts.indices {
                if let s = participantState(at: i) {
                    ts[i].finalScore = s.score
                    ts[i].finishedRank = s.finishedRank
                    ts[i].isEliminated = s.isEliminated
                }
            }
            game.teams = ts
            game.participants = []
            if let winIdx = state.winnerIndex, ts.indices.contains(winIdx) {
                game.winnerTeamId = ts[winIdx].id
            } else {
                game.winnerTeamId = nil
            }
            game.winnerMemberId = nil
        }
    }
}
