import Foundation

public struct ThrowEvent: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let participantIndex: Int
    public let points: Int
    public let timestamp: Date
    public let throwerMemberId: UUID?

    public init(
        id: UUID = UUID(),
        participantIndex: Int,
        points: Int,
        timestamp: Date = Date(),
        throwerMemberId: UUID? = nil
    ) {
        self.id = id
        self.participantIndex = participantIndex
        self.points = points
        self.timestamp = timestamp
        self.throwerMemberId = throwerMemberId
    }

    private enum CodingKeys: String, CodingKey {
        case id, participantIndex, points, timestamp, throwerMemberId
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.participantIndex = try c.decode(Int.self, forKey: .participantIndex)
        self.points = try c.decode(Int.self, forKey: .points)
        self.timestamp = try c.decode(Date.self, forKey: .timestamp)
        self.throwerMemberId = try c.decodeIfPresent(UUID.self, forKey: .throwerMemberId)
    }
}
