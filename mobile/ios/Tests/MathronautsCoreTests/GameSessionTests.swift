import XCTest
@testable import MathronautsCore

final class GameSessionTests: XCTestCase {
    struct SeededRandom: RandomNumberGenerator {
        var state: UInt64 = 42
        mutating func next() -> UInt64 {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return state
        }
    }

    func testGeneratedQuestionsHaveFourUniqueValidChoices() {
        var random = SeededRandom()
        for _ in 0..<1000 {
            let question = Question.addition(using: &random)
            XCTAssertTrue((1...25).contains(question.first))
            XCTAssertTrue((1...25).contains(question.second))
            XCTAssertEqual(Set(question.choices).count, 4)
            XCTAssertEqual(question.choices.filter { $0 == question.answer }.count, 1)
            XCTAssertTrue(question.choices.allSatisfy { (1...50).contains($0) })
        }
    }

    func testCorrectAnswerScoresOnceAndAdvances() {
        var game = GameSession()
        let previous = game.question
        XCTAssertTrue(game.resolve(answer: previous.answer, questionID: previous.id))
        XCTAssertEqual(game.score, 10)
        XCTAssertEqual(game.lives, 3)
        XCTAssertNotEqual(game.question.id, previous.id)
        XCTAssertFalse(game.resolve(answer: previous.answer, questionID: previous.id))
        XCTAssertEqual(game.score, 10)
    }

    func testWrongMeteorCannotCostTwoLives() {
        var game = GameSession()
        let question = game.question
        let wrong = question.choices.first { $0 != question.answer }!
        XCTAssertTrue(game.resolve(answer: wrong, questionID: question.id))
        XCTAssertFalse(game.resolve(answer: wrong, questionID: question.id))
        XCTAssertEqual(game.lives, 2)
        XCTAssertEqual(game.question.id, question.id)
        XCTAssertEqual(game.score, 0)
    }

    func testInvalidChoiceIsIgnored() {
        var game = GameSession()
        XCTAssertFalse(game.resolve(answer: -1, questionID: game.question.id))
        XCTAssertEqual(game.lives, 3)
    }

    func testExpiredWaveCostsOneLifeAndRejectsStaleEvents() {
        var game = GameSession()
        let id = game.question.id
        XCTAssertTrue(game.expire(questionID: id))
        XCTAssertFalse(game.expire(questionID: id))
        XCTAssertEqual(game.lives, 2)
    }

    func testGameOverRejectsFurtherInputAndNewSessionResets() {
        var game = GameSession()
        let question = game.question
        for wrong in question.choices.filter({ $0 != question.answer }) {
            XCTAssertTrue(game.resolve(answer: wrong, questionID: question.id))
        }
        XCTAssertTrue(game.isOver)
        XCTAssertFalse(game.resolve(answer: question.answer, questionID: question.id))
        XCTAssertFalse(game.expire(questionID: question.id))
        XCTAssertEqual(game.lives, 0)
        game = GameSession()
        XCTAssertFalse(game.isOver)
        XCTAssertEqual(game.score, 0)
        XCTAssertEqual(game.lives, 3)
    }
}
