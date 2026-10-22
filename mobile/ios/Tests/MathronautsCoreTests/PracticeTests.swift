import XCTest
@testable import MathronautsCore

final class PracticeTests: XCTestCase {
    func testAllDifficultyOperationRangesAndUniqueChoices() {
        var random = GameSessionTests.SeededRandom()
        for difficulty in Difficulty.allCases {
            for stage in 0...4 {
                for _ in 0..<200 {
                    let q = Question.generate(stage: stage, difficulty: difficulty, using: &random)
                    XCTAssertEqual(Set(q.choices).count, 4)
                    XCTAssertEqual(q.choices.filter { $0 == q.answer }.count, 1)
                    switch q.operation {
                    case .addition:
                        XCTAssertTrue((1...difficulty.additionLimit).contains(q.first))
                        XCTAssertTrue((1...difficulty.additionLimit).contains(q.second))
                    case .subtraction:
                        XCTAssertTrue((1...difficulty.subtractionLimit).contains(q.first))
                        XCTAssertTrue((1...q.first).contains(q.second))
                    case .multiplication:
                        XCTAssertTrue((1...difficulty.tableLimit).contains(q.first))
                        XCTAssertTrue((1...difficulty.tableLimit).contains(q.second))
                    case .division:
                        XCTAssertTrue((1...difficulty.tableLimit).contains(q.answer))
                        XCTAssertGreaterThan(q.second, 0)
                        XCTAssertEqual(q.first % q.second, 0)
                    }
                }
            }
        }
        XCTAssertLessThan(Difficulty.easy.waveSpeed, Difficulty.normal.waveSpeed)
        XCTAssertLessThan(Difficulty.normal.waveSpeed, Difficulty.hard.waveSpeed)
    }

    func testPracticeEndsAfterTenAnswersWithReviewAndNoLifeLoss() {
        var game = GameSession(settings: SessionSettings(difficulty: .easy, mode: .practice, practiceStage: 3))
        for index in 0..<10 {
            XCTAssertFalse(game.isOver)
            let q = game.question
            XCTAssertEqual(q.operation, .division)
            XCTAssertFalse(game.expire(questionID: q.id))
            let answer = index % 2 == 0 ? q.answer : q.choices.first { $0 != q.answer }!
            XCTAssertTrue(game.resolve(answer: answer, questionID: q.id))
            XCTAssertFalse(game.resolve(answer: answer, questionID: q.id))
        }
        XCTAssertTrue(game.isOver)
        XCTAssertEqual(game.lives, 3)
        XCTAssertEqual(game.score, 50)
        XCTAssertEqual(game.accuracy, 50)
        XCTAssertEqual(game.mistakes.count, 5)
    }

    func testReviewPreservesOriginalQuestionAndCorrectAnswer() {
        var game = GameSession(settings: SessionSettings(mode: .practice))
        let q = game.question
        let wrong = q.choices.first { $0 != q.answer }!
        game.resolve(answer: wrong, questionID: q.id)
        XCTAssertEqual(game.mistakes.first, ReviewItem(question: q.text, submitted: wrong, correct: q.answer))
        XCTAssertNotEqual(game.question.id, q.id)
    }

    func testArcadeProgressionMatchesFiveStageOriginal() {
        var game = GameSession()
        for (stage, limit) in [10, 10, 5, 5].enumerated() {
            for _ in 0..<(limit - 1) { game.resolve(answer: game.question.answer, questionID: game.question.id) }
            XCTAssertEqual(game.stage, stage)
            game.resolve(answer: game.question.answer, questionID: game.question.id)
            XCTAssertEqual(game.stage, stage + 1)
        }
        for _ in 0..<50 { game.resolve(answer: game.question.answer, questionID: game.question.id) }
        XCTAssertEqual(game.stage, 4)
        XCTAssertEqual(game.score, 800)
    }

    func testStatisticsRoundTripAndMalformedStorage() throws {
        var stats = LearningStats()
        stats.record(operation: .addition, correct: true, streak: 1, finishedPractice: false)
        stats.record(operation: .addition, correct: false, streak: 0, finishedPractice: false)
        stats.record(operation: .division, correct: true, streak: 3, finishedPractice: true)
        XCTAssertEqual(stats.accuracy, 66)
        XCTAssertEqual(stats.operations[.addition]?.accuracy, 50)
        XCTAssertEqual(stats.bestStreak, 3)
        XCTAssertEqual(stats.practiceRounds, 1)
        XCTAssertEqual(LearningStats.restored(from: try stats.encoded()), stats)
        XCTAssertEqual(LearningStats.restored(from: Data("broken".utf8)), LearningStats())
        XCTAssertEqual(LearningStats.restored(from: nil).accuracy, 0)
    }
}
