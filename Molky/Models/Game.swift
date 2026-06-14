import Foundation
import SwiftData

struct PersistedParticipant: Codable, Identifiable, Hashable {
    var id: UUID { memberId }
    let memberId: UUID
    let name: String
    let turnIndex: Int
    var finalScore: Int
    var finishedRank: Int?
    var isEliminated: Bool
    var isGuest: Bool = false

    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? String(localized: "未登録") : trimmed
    }

    private enum CodingKeys: String, CodingKey {
        case memberId, name, turnIndex, finalScore, finishedRank, isEliminated, isGuest
    }

    init(memberId: UUID, name: String, turnIndex: Int, finalScore: Int, finishedRank: Int?, isEliminated: Bool, isGuest: Bool = false) {
        self.memberId = memberId
        self.name = name
        self.turnIndex = turnIndex
        self.finalScore = finalScore
        self.finishedRank = finishedRank
        self.isEliminated = isEliminated
        self.isGuest = isGuest
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.memberId = try c.decode(UUID.self, forKey: .memberId)
        self.name = try c.decode(String.self, forKey: .name)
        self.turnIndex = try c.decode(Int.self, forKey: .turnIndex)
        self.finalScore = try c.decode(Int.self, forKey: .finalScore)
        self.finishedRank = try c.decodeIfPresent(Int.self, forKey: .finishedRank)
        self.isEliminated = try c.decode(Bool.self, forKey: .isEliminated)
        self.isGuest = try c.decodeIfPresent(Bool.self, forKey: .isGuest) ?? false
    }
}

struct PersistedTeam: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let turnIndex: Int
    let memberIds: [UUID]
    let memberNames: [String]
    var finalScore: Int
    var finishedRank: Int?
    var isEliminated: Bool
    var isGuest: Bool = false

    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? defaultLetterName(forTurnIndex: turnIndex) : trimmed
    }

    private func defaultLetterName(forTurnIndex i: Int) -> String {
        let letters = ["A", "B", "C", "D", "E", "F"]
        let label = letters.indices.contains(i) ? letters[i] : "\(i + 1)"
        return String(localized: "\(label)チーム")
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, turnIndex, memberIds, memberNames, finalScore, finishedRank, isEliminated, isGuest
    }

    init(id: UUID, name: String, turnIndex: Int, memberIds: [UUID], memberNames: [String], finalScore: Int, finishedRank: Int?, isEliminated: Bool, isGuest: Bool = false) {
        self.id = id
        self.name = name
        self.turnIndex = turnIndex
        self.memberIds = memberIds
        self.memberNames = memberNames
        self.finalScore = finalScore
        self.finishedRank = finishedRank
        self.isEliminated = isEliminated
        self.isGuest = isGuest
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.name = try c.decode(String.self, forKey: .name)
        self.turnIndex = try c.decode(Int.self, forKey: .turnIndex)
        self.memberIds = try c.decode([UUID].self, forKey: .memberIds)
        self.memberNames = try c.decode([String].self, forKey: .memberNames)
        self.finalScore = try c.decode(Int.self, forKey: .finalScore)
        self.finishedRank = try c.decodeIfPresent(Int.self, forKey: .finishedRank)
        self.isEliminated = try c.decode(Bool.self, forKey: .isEliminated)
        self.isGuest = try c.decodeIfPresent(Bool.self, forKey: .isGuest) ?? false
    }
}

enum GameModeValue: String {
    case individual
    case team
}

@Model
final class Game {
    var id: UUID = UUID()
    var date: Date = Date()
    var targetScore: Int = 50
    var overshootResetTo: Int = 25
    var eliminationEnabled: Bool = true
    var maxConsecutiveMisses: Int = 3
    var isFinished: Bool = false
    var winnerMemberId: UUID?
    var winnerTeamId: UUID?
    var modeRaw: String = GameModeValue.individual.rawValue
    var participantsData: Data = Data()
    var teamsData: Data = Data()
    var throwsData: Data = Data()
    /// 連続ミス時の挙動。MissPolicy.rawValue を保存。未設定（旧データ）は eliminationEnabled から導出。
    var missPolicyRaw: String = MissPolicy.eliminate.rawValue

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        targetScore: Int = 50,
        overshootResetTo: Int = 25,
        eliminationEnabled: Bool = true,
        maxConsecutiveMisses: Int = 3,
        missPolicy: MissPolicy = .eliminate,
        isFinished: Bool = false,
        winnerMemberId: UUID? = nil,
        winnerTeamId: UUID? = nil,
        mode: GameModeValue = .individual,
        participants: [PersistedParticipant] = [],
        teams: [PersistedTeam] = [],
        throws events: [ThrowEvent] = []
    ) {
        self.id = id
        self.date = date
        self.targetScore = targetScore
        self.overshootResetTo = overshootResetTo
        self.eliminationEnabled = eliminationEnabled
        self.maxConsecutiveMisses = maxConsecutiveMisses
        self.missPolicyRaw = missPolicy.rawValue
        self.isFinished = isFinished
        self.winnerMemberId = winnerMemberId
        self.winnerTeamId = winnerTeamId
        self.modeRaw = mode.rawValue
        self.participantsData = (try? JSONEncoder().encode(participants)) ?? Data()
        self.teamsData = (try? JSONEncoder().encode(teams)) ?? Data()
        self.throwsData = (try? JSONEncoder().encode(events)) ?? Data()
    }

    var mode: GameModeValue {
        get { GameModeValue(rawValue: modeRaw) ?? .individual }
        set { modeRaw = newValue.rawValue }
    }

    var participants: [PersistedParticipant] {
        get { (try? JSONDecoder().decode([PersistedParticipant].self, from: participantsData)) ?? [] }
        set { participantsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    var teams: [PersistedTeam] {
        get { (try? JSONDecoder().decode([PersistedTeam].self, from: teamsData)) ?? [] }
        set { teamsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    var throwEvents: [ThrowEvent] {
        get { (try? JSONDecoder().decode([ThrowEvent].self, from: throwsData)) ?? [] }
        set { throwsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    var missPolicy: MissPolicy {
        get {
            if let p = MissPolicy(rawValue: missPolicyRaw) { return p }
            // 旧データのフォールバック
            return eliminationEnabled ? .eliminate : .none
        }
        set { missPolicyRaw = newValue.rawValue }
    }

    var config: GameConfig {
        GameConfig(
            targetScore: targetScore,
            overshootResetTo: overshootResetTo,
            maxConsecutiveMisses: maxConsecutiveMisses,
            missPolicy: missPolicy
        )
    }
}
