import Foundation

public struct ParticipantState: Equatable, Sendable {
    public let index: Int
    public var score: Int
    public var consecutiveMisses: Int
    public var isEliminated: Bool
    public var finishedRank: Int?

    public init(
        index: Int,
        score: Int = 0,
        consecutiveMisses: Int = 0,
        isEliminated: Bool = false,
        finishedRank: Int? = nil
    ) {
        self.index = index
        self.score = score
        self.consecutiveMisses = consecutiveMisses
        self.isEliminated = isEliminated
        self.finishedRank = finishedRank
    }

    public var isActive: Bool { !isEliminated && finishedRank == nil }
}

public struct GameState: Equatable, Sendable {
    public var participants: [ParticipantState]
    public var currentTurnParticipantIndex: Int?
    public var winnerIndex: Int?
    public var isFinished: Bool

    public init(
        participants: [ParticipantState],
        currentTurnParticipantIndex: Int? = nil,
        winnerIndex: Int? = nil,
        isFinished: Bool = false
    ) {
        self.participants = participants
        self.currentTurnParticipantIndex = currentTurnParticipantIndex
        self.winnerIndex = winnerIndex
        self.isFinished = isFinished
    }
}
