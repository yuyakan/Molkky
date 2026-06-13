import Foundation
import SwiftData

@Model
final class Team {
    var id: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date()
    /// 所属メンバーIDの順序付き配列（投擲ローテーション順）
    var memberIdsData: Data = Data()

    init(id: UUID = UUID(), name: String, memberIds: [UUID] = [], createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.memberIdsData = (try? JSONEncoder().encode(memberIds)) ?? Data()
    }

    var memberIds: [UUID] {
        get { (try? JSONDecoder().decode([UUID].self, from: memberIdsData)) ?? [] }
        set { memberIdsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }
}
