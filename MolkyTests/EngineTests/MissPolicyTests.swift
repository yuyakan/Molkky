import XCTest
@testable import Molky

final class MissPolicyTests: XCTestCase {

    /// 既定 (.eliminate): 3連続ミスで失格
    func test_eliminate_default() {
        let cfg = GameConfig(targetScore: 50, overshootResetTo: 25, maxConsecutiveMisses: 3, missPolicy: .eliminate)
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

    /// .resetToZero: 3連続ミスでスコアが0に戻り、ゲーム継続
    func test_resetToZero_resets_score_and_continues() {
        let cfg = GameConfig(targetScore: 50, overshootResetTo: 25, maxConsecutiveMisses: 3, missPolicy: .resetToZero)
        let events: [ThrowEvent] = [
            // p0: 10点まで稼ぐ
            .init(participantIndex: 0, points: 10),
            .init(participantIndex: 1, points: 5),
            // p0: 3連続ミス → 0点リセット
            .init(participantIndex: 0, points: 0),
            .init(participantIndex: 1, points: 5),
            .init(participantIndex: 0, points: 0),
            .init(participantIndex: 1, points: 5),
            .init(participantIndex: 0, points: 0),
        ]
        let state = GameEngine.reduce(config: cfg, throws: events, participantCount: 2)
        XCTAssertFalse(state.participants[0].isEliminated)
        XCTAssertEqual(state.participants[0].score, 0)
        XCTAssertEqual(state.participants[0].consecutiveMisses, 0)
        XCTAssertFalse(state.isFinished)
    }

    /// .resetToZero: リセット後にまた得点できる
    func test_resetToZero_can_score_again_after_reset() {
        let cfg = GameConfig(targetScore: 50, overshootResetTo: 25, maxConsecutiveMisses: 3, missPolicy: .resetToZero)
        let events: [ThrowEvent] = [
            .init(participantIndex: 0, points: 10),
            .init(participantIndex: 1, points: 5),
            .init(participantIndex: 0, points: 0),
            .init(participantIndex: 1, points: 5),
            .init(participantIndex: 0, points: 0),
            .init(participantIndex: 1, points: 5),
            .init(participantIndex: 0, points: 0), // ここで p0 が 0点リセット
            .init(participantIndex: 1, points: 5),
            .init(participantIndex: 0, points: 7),
        ]
        let state = GameEngine.reduce(config: cfg, throws: events, participantCount: 2)
        XCTAssertEqual(state.participants[0].score, 7)
        XCTAssertEqual(state.participants[0].consecutiveMisses, 0)
    }

    /// .none: 何回ミスしても何も起きない
    func test_none_no_penalty() {
        let cfg = GameConfig(targetScore: 50, overshootResetTo: 25, maxConsecutiveMisses: 3, missPolicy: .none)
        let events: [ThrowEvent] = [
            .init(participantIndex: 0, points: 10),
            .init(participantIndex: 1, points: 5),
            .init(participantIndex: 0, points: 0),
            .init(participantIndex: 1, points: 5),
            .init(participantIndex: 0, points: 0),
            .init(participantIndex: 1, points: 5),
            .init(participantIndex: 0, points: 0),
            .init(participantIndex: 1, points: 5),
            .init(participantIndex: 0, points: 0),
        ]
        let state = GameEngine.reduce(config: cfg, throws: events, participantCount: 2)
        XCTAssertFalse(state.participants[0].isEliminated)
        XCTAssertEqual(state.participants[0].score, 10)
        XCTAssertEqual(state.participants[0].consecutiveMisses, 5)
        XCTAssertFalse(state.isFinished)
    }

    /// 後方互換: 旧 init(eliminationEnabled:) は missPolicy にマップされる
    func test_legacy_init_maps_to_policy() {
        let cfgOn = GameConfig(targetScore: 50, overshootResetTo: 25, eliminationEnabled: true, maxConsecutiveMisses: 3)
        XCTAssertEqual(cfgOn.missPolicy, .eliminate)
        XCTAssertTrue(cfgOn.eliminationEnabled)

        let cfgOff = GameConfig(targetScore: 50, overshootResetTo: 25, eliminationEnabled: false, maxConsecutiveMisses: 3)
        XCTAssertEqual(cfgOff.missPolicy, .none)
        XCTAssertFalse(cfgOff.eliminationEnabled)
    }

    /// 旧 JSON（missPolicy 無し + eliminationEnabled あり）のデコード
    func test_codable_legacy_decoding() throws {
        let json = """
        {"targetScore":50,"overshootResetTo":25,"maxConsecutiveMisses":3,"eliminationEnabled":true}
        """
        let data = Data(json.utf8)
        let cfg = try JSONDecoder().decode(GameConfig.self, from: data)
        XCTAssertEqual(cfg.missPolicy, .eliminate)
    }

    /// 新 JSON（missPolicy あり）のデコード
    func test_codable_new_decoding() throws {
        let json = """
        {"targetScore":50,"overshootResetTo":25,"maxConsecutiveMisses":3,"missPolicy":"resetToZero"}
        """
        let data = Data(json.utf8)
        let cfg = try JSONDecoder().decode(GameConfig.self, from: data)
        XCTAssertEqual(cfg.missPolicy, .resetToZero)
    }
}
