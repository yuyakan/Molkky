import XCTest
@testable import Molky

final class TeamModeTests: XCTestCase {

    private func makeTeam(name: String, turnIndex: Int, memberCount: Int) -> PersistedTeam {
        let ids = (0..<memberCount).map { _ in UUID() }
        let names = (0..<memberCount).map { "\(name)-\($0 + 1)" }
        return PersistedTeam(
            id: UUID(),
            name: name,
            turnIndex: turnIndex,
            memberIds: ids,
            memberNames: names,
            finalScore: 0,
            finishedRank: nil,
            isEliminated: false
        )
    }

    func test_team_thrower_rotation() {
        let teamA = makeTeam(name: "A", turnIndex: 0, memberCount: 3)
        let teamB = makeTeam(name: "B", turnIndex: 1, memberCount: 2)
        let store = GameSessionStore(config: GameConfig(), teams: [teamA, teamB])

        // Aチーム1投目 → A-1 が投擲
        XCTAssertEqual(store.currentThrowerMemberId, teamA.memberIds[0])
        store.record(points: 3)
        // 手番がBに移動 → B-1
        XCTAssertEqual(store.currentThrowerMemberId, teamB.memberIds[0])
        store.record(points: 3)
        // Aに戻る → A-2
        XCTAssertEqual(store.currentThrowerMemberId, teamA.memberIds[1])
        store.record(points: 3)
        // Bに移る → B-2
        XCTAssertEqual(store.currentThrowerMemberId, teamB.memberIds[1])
        store.record(points: 3)
        // Aに戻る → A-3
        XCTAssertEqual(store.currentThrowerMemberId, teamA.memberIds[2])
        store.record(points: 3)
        // Bに移る → B-1（一周してローテーション）
        XCTAssertEqual(store.currentThrowerMemberId, teamB.memberIds[0])
        store.record(points: 3)
        // Aに戻る → A-1（一周）
        XCTAssertEqual(store.currentThrowerMemberId, teamA.memberIds[0])
    }

    func test_undo_rolls_back_thrower() {
        let teamA = makeTeam(name: "A", turnIndex: 0, memberCount: 2)
        let teamB = makeTeam(name: "B", turnIndex: 1, memberCount: 2)
        let store = GameSessionStore(config: GameConfig(), teams: [teamA, teamB])

        store.record(points: 3) // A-1 → 投擲
        store.record(points: 3) // B-1
        store.record(points: 3) // A-2
        XCTAssertEqual(store.currentThrowerMemberId, teamB.memberIds[1])

        store.undo() // 直前のA-2投擲を取消、手番はAに戻り次の投擲者はA-2
        XCTAssertEqual(store.currentTeam?.turnIndex, 0)
        XCTAssertEqual(store.currentThrowerMemberId, teamA.memberIds[1])

        store.undo() // B-1取消
        XCTAssertEqual(store.currentTeam?.turnIndex, 1)
        XCTAssertEqual(store.currentThrowerMemberId, teamB.memberIds[0])

        store.undo() // A-1取消、最初に戻る
        XCTAssertEqual(store.currentTeam?.turnIndex, 0)
        XCTAssertEqual(store.currentThrowerMemberId, teamA.memberIds[0])
    }

    func test_team_win() {
        let teamA = makeTeam(name: "A", turnIndex: 0, memberCount: 2)
        let teamB = makeTeam(name: "B", turnIndex: 1, memberCount: 2)
        let store = GameSessionStore(config: GameConfig(), teams: [teamA, teamB])

        // A: 12,12,12,12,2 = 50
        // B: 0 * 4 (失格しないように1回得点する)
        store.record(points: 12) // A
        store.record(points: 3)  // B
        store.record(points: 12) // A
        store.record(points: 3)  // B
        store.record(points: 12) // A
        store.record(points: 3)  // B
        store.record(points: 12) // A → 48
        store.record(points: 3)  // B
        store.record(points: 2)  // A → 50, win

        XCTAssertTrue(store.state.isFinished)
        XCTAssertEqual(store.state.winnerIndex, 0)
        XCTAssertEqual(store.state.participants[0].score, 50)
    }

    func test_save_to_game_team_mode() throws {
        let teamA = makeTeam(name: "A", turnIndex: 0, memberCount: 2)
        let teamB = makeTeam(name: "B", turnIndex: 1, memberCount: 2)
        let store = GameSessionStore(config: GameConfig(), teams: [teamA, teamB])
        store.record(points: 12)
        store.record(points: 3)
        store.record(points: 5)

        let game = Game()
        store.saveToGame(game)

        XCTAssertEqual(game.mode, .team)
        XCTAssertEqual(game.teams.count, 2)
        XCTAssertEqual(game.participants.count, 0)
        XCTAssertEqual(game.throwEvents.count, 3)
        XCTAssertEqual(game.teams[0].finalScore, 17)
        XCTAssertEqual(game.teams[1].finalScore, 3)
        XCTAssertNil(game.winnerMemberId)
        // 投擲者ID が ThrowEvent に記録されている
        XCTAssertEqual(game.throwEvents[0].throwerMemberId, teamA.memberIds[0])
        XCTAssertEqual(game.throwEvents[1].throwerMemberId, teamB.memberIds[0])
        XCTAssertEqual(game.throwEvents[2].throwerMemberId, teamA.memberIds[1])
    }

    func test_persisted_team_roundtrip() throws {
        let team = PersistedTeam(
            id: UUID(),
            name: "Aチーム",
            turnIndex: 0,
            memberIds: [UUID(), UUID()],
            memberNames: ["田中", "佐藤"],
            finalScore: 42,
            finishedRank: 1,
            isEliminated: false
        )
        let data = try JSONEncoder().encode([team])
        let decoded = try JSONDecoder().decode([PersistedTeam].self, from: data)
        XCTAssertEqual(decoded.first, team)
    }

    func test_throwEvent_backward_compatible_decoding() throws {
        // 旧形式（throwerMemberId フィールド無し）の JSON が読めること
        let id = UUID()
        let json = """
        [{"id":"\(id.uuidString)","participantIndex":0,"points":7,"timestamp":697075200}]
        """
        let data = Data(json.utf8)
        let decoder = JSONDecoder()
        let events = try decoder.decode([ThrowEvent].self, from: data)
        XCTAssertEqual(events.count, 1)
        XCTAssertNil(events[0].throwerMemberId)
        XCTAssertEqual(events[0].points, 7)
    }

    func test_team_individual_mode_unchanged() {
        // 個人戦は throwerMemberId が nil のまま動作
        let parts = [
            PersistedParticipant(memberId: UUID(), name: "田中", turnIndex: 0, finalScore: 0, finishedRank: nil, isEliminated: false),
            PersistedParticipant(memberId: UUID(), name: "佐藤", turnIndex: 1, finalScore: 0, finishedRank: nil, isEliminated: false)
        ]
        let store = GameSessionStore(config: GameConfig(), participants: parts)
        store.record(points: 5)
        XCTAssertEqual(store.mode, .individual)
        XCTAssertNil(store.events.first?.throwerMemberId)
        XCTAssertNil(store.currentThrowerMemberId)
    }
}
