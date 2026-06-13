import Foundation

public enum GameEngine {

    public static func initialState(participantCount: Int) -> GameState {
        let parts = (0..<participantCount).map { ParticipantState(index: $0) }
        return GameState(
            participants: parts,
            currentTurnParticipantIndex: parts.isEmpty ? nil : 0,
            winnerIndex: nil,
            isFinished: false
        )
    }

    public static func reduce(config: GameConfig, throws events: [ThrowEvent], participantCount: Int) -> GameState {
        var state = initialState(participantCount: participantCount)
        guard participantCount > 0 else { return state }

        var nextEliminationRank = participantCount

        for ev in events {
            if state.isFinished { break }
            guard state.participants.indices.contains(ev.participantIndex) else { continue }
            var p = state.participants[ev.participantIndex]
            guard p.isActive else { continue }

            if ev.points == 0 {
                p.consecutiveMisses += 1
                if p.consecutiveMisses >= config.maxConsecutiveMisses {
                    switch config.missPolicy {
                    case .eliminate:
                        p.isEliminated = true
                        p.finishedRank = nextEliminationRank
                        nextEliminationRank -= 1
                    case .resetToZero:
                        p.score = 0
                        p.consecutiveMisses = 0
                    case .none:
                        break
                    }
                }
            } else {
                p.consecutiveMisses = 0
                let newScore = p.score + ev.points
                if newScore == config.targetScore {
                    p.score = newScore
                    p.finishedRank = 1
                    state.participants[ev.participantIndex] = p
                    state.winnerIndex = ev.participantIndex
                    state.isFinished = true
                    state.currentTurnParticipantIndex = nil
                    return finalizeRanks(state: state, config: config)
                } else if newScore > config.targetScore {
                    p.score = config.overshootResetTo
                } else {
                    p.score = newScore
                }
            }

            state.participants[ev.participantIndex] = p

            let activeIndices = state.participants.filter { $0.isActive }.map { $0.index }
            if activeIndices.count == 1 && participantCount > 1 {
                let winner = activeIndices[0]
                var w = state.participants[winner]
                w.finishedRank = 1
                state.participants[winner] = w
                state.winnerIndex = winner
                state.isFinished = true
                state.currentTurnParticipantIndex = nil
                return finalizeRanks(state: state, config: config)
            }
            if activeIndices.isEmpty {
                state.isFinished = true
                state.currentTurnParticipantIndex = nil
                return finalizeRanks(state: state, config: config)
            }

            state.currentTurnParticipantIndex = nextActiveIndex(
                after: ev.participantIndex,
                participants: state.participants
            )
        }

        return state
    }

    private static func nextActiveIndex(after current: Int, participants: [ParticipantState]) -> Int? {
        let count = participants.count
        guard count > 0 else { return nil }
        for offset in 1...count {
            let i = (current + offset) % count
            if participants[i].isActive { return i }
        }
        return nil
    }

    private static func finalizeRanks(state: GameState, config: GameConfig) -> GameState {
        var s = state
        let unranked = s.participants.indices.filter { s.participants[$0].finishedRank == nil }
        let sorted = unranked.sorted { s.participants[$0].score > s.participants[$1].score }
        var rank = 2
        for idx in sorted {
            s.participants[idx].finishedRank = rank
            rank += 1
        }
        return s
    }
}
