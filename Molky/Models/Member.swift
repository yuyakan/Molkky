import Foundation
import SwiftData

@Model
final class Member {
    var id: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date()
    var colorTag: String?

    init(id: UUID = UUID(), name: String, createdAt: Date = Date(), colorTag: String? = nil) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.colorTag = colorTag
    }
}
