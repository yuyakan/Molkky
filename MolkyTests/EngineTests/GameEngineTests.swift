import XCTest
@testable import Molky

final class GameEngineTests: XCTestCase {

    func test_48plus2_wins_at_50() {
        let cfg = GameConfig()
        let events: [ThrowEvent] = [
            .init(participantIndex: 0, points: 12),
            .init(participantIndex: 1, points: 0),
            .init(participantIndex: 0, points: 12),
            .init(participantIndex: 1, points: 0),
            .init(participantIndex: 0, points: 12),
            .init(participantIndex: 1, points: 0),
            .init(participantIndex: 0, points: 12),
            .init(participantIndex: 1, points: 1),
            .init(participantIndex: 0, points: 2),
        ]
        let state = GameEngine.reduce(config: cfg, throws: events, participantCount: 2)
        XCTAssertTrue(state.isFinished)
        XCTAssertEqual(state.winnerIndex, 0)
        XCTAssertEqual(state.participants[0].score, 50)
        XCTAssertEqual(state.participants[0].finishedRank, 1)
    }

    func test_48plus5_resets_to_25() {
        let cfg = GameConfig()
        let events: [ThrowEvent] = [
            .init(participantIndex: 0, points: 12),
            .init(participantIndex: 1, points: 0),
            .init(participantIndex: 0, points: 12),
            .init(participantIndex: 1, points: 0),
            .init(participantIndex: 0, points: 12),
            .init(participantIndex: 1, points: 0),
            .init(participantIndex: 0, points: 12),
            .init(participantIndex: 1, points: 1),
            .init(participantIndex: 0, points: 5),
        ]
        let state = GameEngine.reduce(config: cfg, throws: events, participantCount: 2)
        XCTAssertFalse(state.isFinished)
        XCTAssertEqual(state.participants[0].score, 25)
    }

    func test_three_consecutive_misses_eliminate() {
        let cfg = GameConfig()
        let events: [ThrowEvent] = [
            .init(participantIndex: 0, points: 0),
            .init(participantIndex: 1, points: 3),
            .init(participantIndex: 0, points: 0),
            .init(participantIndex: 1, points: 3),
            .init(participantIndex: 0, points: 0),
        ]
        let state = GameEngine.reduce(config: cfg, throws: events, participantCount: 2)
        XCTAssertTrue(state.participants[0].isEliminated)
        XCTAssertTrue(state.isFinished)
        XCTAssertEqual(state.winnerIndex, 1)
    }

    func test_consecutive_misses_reset_on_score() {
        let cfg = GameConfig()
        let events: [ThrowEvent] = [
            .init(participantIndex: 0, points: 0),
            .init(participantIndex: 1, points: 3),
            .init(participantIndex: 0, points: 0),
            .init(participantIndex: 1, points: 3),
            .init(participantIndex: 0, points: 5),
            .init(participantIndex: 1, points: 3),
            .init(participantIndex: 0, points: 0),
            .init(participantIndex: 1, points: 3),
            .init(participantIndex: 0, points: 0),
        ]
        let state = GameEngine.reduce(config: cfg, throws: events, participantCount: 2)
        XCTAssertFalse(state.participants[0].isEliminated)
        XCTAssertEqual(state.participants[0].consecutiveMisses, 2)
    }

    func test_four_players_three_eliminated_winner_is_remaining() {
        let cfg = GameConfig()
        // 0,1,2 が全員3連続ミス → 3 が勝者
        let events: [ThrowEvent] = [
            .init(participantIndex: 0, points: 0),
            .init(participantIndex: 1, points: 0),
            .init(participantIndex: 2, points: 0),
            .init(participantIndex: 3, points: 5),
            .init(participantIndex: 0, points: 0),
            .init(participantIndex: 1, points: 0),
            .init(participantIndex: 2, points: 0),
            .init(participantIndex: 3, points: 5),
            .init(participantIndex: 0, points: 0),
            .init(participantIndex: 1, points: 0),
            .init(participantIndex: 2, points: 0),
        ]
        let state = GameEngine.reduce(config: cfg, throws: events, participantCount: 4)
        XCTAssertTrue(state.isFinished)
        XCTAssertEqual(state.winnerIndex, 3)
        XCTAssertEqual(state.participants[3].finishedRank, 1)
        XCTAssertTrue(state.participants[0].isEliminated)
        XCTAssertTrue(state.participants[1].isEliminated)
        XCTAssertTrue(state.participants[2].isEliminated)
    }

    func test_undo_is_reduce_minus_last() {
        let cfg = GameConfig()
        let events: [ThrowEvent] = [
            .init(participantIndex: 0, points: 7),
            .init(participantIndex: 1, points: 3),
            .init(participantIndex: 0, points: 4),
            .init(participantIndex: 1, points: 0),
        ]
        let afterAll = GameEngine.reduce(config: cfg, throws: events, participantCount: 2)
        let afterUndo = GameEngine.reduce(config: cfg, throws: Array(events.dropLast()), participantCount: 2)
        XCTAssertNotEqual(afterAll, afterUndo)
        XCTAssertEqual(afterUndo.participants[1].consecutiveMisses, 0)
        XCTAssertEqual(afterAll.participants[1].consecutiveMisses, 1)
    }

    func test_turn_rotation_skips_eliminated() {
        let cfg = GameConfig()
        let events: [ThrowEvent] = [
            .init(participantIndex: 0, points: 0),
            .init(participantIndex: 1, points: 5),
            .init(participantIndex: 2, points: 5),
            .init(participantIndex: 0, points: 0),
            .init(participantIndex: 1, points: 5),
            .init(participantIndex: 2, points: 5),
            .init(participantIndex: 0, points: 0),
        ]
        let state = GameEngine.reduce(config: cfg, throws: events, participantCount: 3)
        XCTAssertTrue(state.participants[0].isEliminated)
        // 0が失格になったので次は2を終えたあと1に戻る、最後のイベントは0の3度目ミスでそこで失格処理、次手番は1
        XCTAssertEqual(state.currentTurnParticipantIndex, 1)
    }

    func test_custom_target_and_overshoot() {
        let cfg = GameConfig(targetScore: 30, overshootResetTo: 10)
        let events: [ThrowEvent] = [
            .init(participantIndex: 0, points: 12),
            .init(participantIndex: 1, points: 0),
            .init(participantIndex: 0, points: 12),
            .init(participantIndex: 1, points: 0),
            .init(participantIndex: 0, points: 10),
        ]
        let state = GameEngine.reduce(config: cfg, throws: events, participantCount: 2)
        // 24 + 10 = 34 > 30 → 10 に戻る
        XCTAssertEqual(state.participants[0].score, 10)
        XCTAssertFalse(state.isFinished)
    }
}
