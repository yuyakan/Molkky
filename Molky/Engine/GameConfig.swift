import Foundation

/// 連続ミス時の挙動
public enum MissPolicy: String, Codable, CaseIterable, Sendable {
    /// 連続ミスでその参加者/チームが失格（残り1人になったら勝者）
    case eliminate
    /// 連続ミスでスコアを0に戻して継続
    case resetToZero
    /// 連続ミスのペナルティなし（しきい値到達しても何も起きない）
    case none

    public var label: String {
        switch self {
        case .eliminate: return "失格"
        case .resetToZero: return "スコア0リセット"
        case .none: return "ペナルティなし"
        }
    }

    public var shortDescription: String {
        switch self {
        case .eliminate: return "その人/チームが脱落"
        case .resetToZero: return "スコアを0に戻して継続"
        case .none: return "連続ミスでも何も起きない"
        }
    }
}

public struct GameConfig: Codable, Equatable, Sendable {
    public var targetScore: Int
    public var overshootResetTo: Int
    public var maxConsecutiveMisses: Int
    public var missPolicy: MissPolicy

    public init(
        targetScore: Int = 50,
        overshootResetTo: Int = 25,
        maxConsecutiveMisses: Int = 3,
        missPolicy: MissPolicy = .eliminate
    ) {
        self.targetScore = targetScore
        self.overshootResetTo = overshootResetTo
        self.maxConsecutiveMisses = maxConsecutiveMisses
        self.missPolicy = missPolicy
    }

    /// 後方互換: 旧い eliminationEnabled 引数で初期化
    public init(
        targetScore: Int,
        overshootResetTo: Int,
        eliminationEnabled: Bool,
        maxConsecutiveMisses: Int
    ) {
        self.targetScore = targetScore
        self.overshootResetTo = overshootResetTo
        self.maxConsecutiveMisses = maxConsecutiveMisses
        self.missPolicy = eliminationEnabled ? .eliminate : .none
    }

    /// 旧APIとの互換のため。失格ルール（eliminate）が有効か。
    public var eliminationEnabled: Bool {
        missPolicy == .eliminate
    }

    public static let `default` = GameConfig()

    // MARK: - Codable (後方互換: 旧 eliminationEnabled の読み込み)
    private enum CodingKeys: String, CodingKey {
        case targetScore, overshootResetTo, maxConsecutiveMisses, missPolicy, eliminationEnabled
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.targetScore = try c.decode(Int.self, forKey: .targetScore)
        self.overshootResetTo = try c.decode(Int.self, forKey: .overshootResetTo)
        self.maxConsecutiveMisses = try c.decode(Int.self, forKey: .maxConsecutiveMisses)
        if let policy = try c.decodeIfPresent(MissPolicy.self, forKey: .missPolicy) {
            self.missPolicy = policy
        } else if let legacy = try c.decodeIfPresent(Bool.self, forKey: .eliminationEnabled) {
            self.missPolicy = legacy ? .eliminate : .none
        } else {
            self.missPolicy = .eliminate
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(targetScore, forKey: .targetScore)
        try c.encode(overshootResetTo, forKey: .overshootResetTo)
        try c.encode(maxConsecutiveMisses, forKey: .maxConsecutiveMisses)
        try c.encode(missPolicy, forKey: .missPolicy)
    }
}
