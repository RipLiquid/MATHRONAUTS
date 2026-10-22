import Foundation

public struct Question: Equatable {
    public let id = UUID()
    public let first: Int
    public let second: Int
    public let choices: [Int]
    public var answer: Int { first + second }
    public var text: String { "\(first) + \(second) = ?" }

    public static func addition<R: RandomNumberGenerator>(using random: inout R) -> Question {
        let first = Int.random(in: 1...25, using: &random)
        let second = Int.random(in: 1...25, using: &random)
        let answer = first + second
        // Sampling without replacement guarantees exactly one correct choice.
        let wrong = (1...50).filter { $0 != answer }.shuffled(using: &random).prefix(3)
        let choices = (Array(wrong) + [answer]).shuffled(using: &random)
        return Question(first: first, second: second, choices: choices)
    }
}

public struct GameSession {
    public private(set) var score = 0
    public private(set) var lives = 3
    public private(set) var question: Question
    public private(set) var availableAnswers: Set<Int>
    public var isOver: Bool { lives == 0 }

    public init() {
        var random = SystemRandomNumberGenerator()
        let question = Question.addition(using: &random)
        self.question = question
        self.availableAnswers = Set(question.choices)
    }

    @discardableResult
    public mutating func resolve(answer: Int, questionID: UUID) -> Bool {
        guard !isOver, question.id == questionID, availableAnswers.contains(answer) else { return false }
        if answer == question.answer {
            score += 10
            nextQuestion()
        } else {
            lives -= 1
            availableAnswers.remove(answer)
        }
        return true
    }

    @discardableResult
    public mutating func expire(questionID: UUID) -> Bool {
        guard !isOver, question.id == questionID else { return false }
        // A wave reaching the defense line costs one life, not one per meteor.
        lives -= 1
        if !isOver { nextQuestion() }
        return true
    }

    private mutating func nextQuestion() {
        var random = SystemRandomNumberGenerator()
        question = Question.addition(using: &random)
        availableAnswers = Set(question.choices)
    }
}
