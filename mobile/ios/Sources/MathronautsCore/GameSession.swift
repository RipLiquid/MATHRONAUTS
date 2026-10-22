import Foundation

public enum MathOperation: String, Codable, CaseIterable {
    case addition, subtraction, multiplication, division
    public var title: String {
        switch self {
        case .addition: return "Addition"
        case .subtraction: return "Subtraction"
        case .multiplication: return "Multiplication"
        case .division: return "Division"
        }
    }
    public var symbol: String {
        switch self {
        case .addition: return "+"
        case .subtraction: return "−"
        case .multiplication: return "×"
        case .division: return "÷"
        }
    }
}

public enum Difficulty: String, Codable, CaseIterable {
    case easy = "Easy", normal = "Normal", hard = "Hard"
    public var additionLimit: Int { self == .easy ? 10 : self == .normal ? 25 : 50 }
    public var subtractionLimit: Int { additionLimit * 2 }
    public var tableLimit: Int { self == .easy ? 5 : self == .normal ? 10 : 12 }
    public var waveSpeed: Double { self == .easy ? 14 : self == .normal ? 20 : 30 }
}

public enum GameMode: String, Codable, CaseIterable { case arcade = "Arcade", practice = "Practice" }

public struct SessionSettings: Equatable {
    public var difficulty: Difficulty
    public var mode: GameMode
    public var practiceStage: Int
    public init(difficulty: Difficulty = .normal, mode: GameMode = .arcade, practiceStage: Int = 0) {
        self.difficulty = difficulty
        self.mode = mode
        self.practiceStage = min(max(practiceStage, 0), 4)
    }
}

public struct Question: Equatable {
    public let id: UUID
    public let first: Int
    public let second: Int
    public let operation: MathOperation
    public let choices: [Int]
    public var answer: Int {
        switch operation {
        case .addition: return first + second
        case .subtraction: return first - second
        case .multiplication: return first * second
        case .division: return first / second
        }
    }
    public var text: String { "\(first) \(operation.symbol) \(second) = ?" }

    public static func addition<R: RandomNumberGenerator>(using random: inout R) -> Question {
        generate(stage: 0, difficulty: .normal, using: &random)
    }

    public static func generate<R: RandomNumberGenerator>(stage: Int, difficulty: Difficulty,
                                                         using random: inout R) -> Question {
        let operation = stage == 4 ? MathOperation.allCases.randomElement(using: &random)! :
            MathOperation.allCases[min(max(stage, 0), 3)]
        let first: Int
        let second: Int
        let answer: Int
        switch operation {
        case .addition:
            first = Int.random(in: 1...difficulty.additionLimit, using: &random)
            second = Int.random(in: 1...difficulty.additionLimit, using: &random)
            answer = first + second
        case .subtraction:
            first = Int.random(in: 1...difficulty.subtractionLimit, using: &random)
            second = Int.random(in: 1...first, using: &random)
            answer = first - second
        case .multiplication:
            first = Int.random(in: 1...difficulty.tableLimit, using: &random)
            second = Int.random(in: 1...difficulty.tableLimit, using: &random)
            answer = first * second
        case .division:
            answer = Int.random(in: 1...difficulty.tableLimit, using: &random)
            second = Int.random(in: 1...answer, using: &random)
            first = answer * second
        }
        let limit = stage <= 1 ? difficulty.subtractionLimit - 1 : difficulty.tableLimit * difficulty.tableLimit - 1
        let wrong = (1...limit).filter { $0 != answer }.shuffled(using: &random).prefix(3)
        return Question(id: UUID(), first: first, second: second, operation: operation,
                        choices: (Array(wrong) + [answer]).shuffled(using: &random))
    }
}

public struct ReviewItem: Equatable {
    public let question: String
    public let submitted: Int
    public let correct: Int
}

public struct GameSession {
    public let settings: SessionSettings
    public private(set) var score = 0
    public private(set) var lives = 3
    public private(set) var stage = 0
    public private(set) var completed = 0
    public private(set) var attempts = 0
    public private(set) var correctAnswers = 0
    public private(set) var streak = 0
    public private(set) var bestStreak = 0
    public private(set) var missed = 0
    public private(set) var mistakes: [ReviewItem] = []
    public private(set) var question: Question
    public private(set) var availableAnswers: Set<Int>
    public var isPractice: Bool { settings.mode == .practice }
    public var isOver: Bool { isPractice ? attempts >= 10 : lives == 0 }
    public var accuracy: Int { attempts == 0 ? 0 : correctAnswers * 100 / attempts }
    public var stageTitle: String {
        let selected = isPractice ? settings.practiceStage : stage
        return selected == 4 ? "Mixed operations" : MathOperation.allCases[selected].title
    }

    public init(settings: SessionSettings = SessionSettings()) {
        self.settings = settings
        var random = SystemRandomNumberGenerator()
        let stage = settings.mode == .practice ? settings.practiceStage : 0
        let question = Question.generate(stage: stage, difficulty: settings.difficulty, using: &random)
        self.question = question
        self.availableAnswers = Set(question.choices)
    }

    @discardableResult
    public mutating func resolve(answer: Int, questionID: UUID) -> Bool {
        guard !isOver, question.id == questionID, availableAnswers.contains(answer) else { return false }
        attempts += 1
        if answer == question.answer {
            score += 10
            correctAnswers += 1
            streak += 1
            bestStreak = max(bestStreak, streak)
            if !isPractice {
                completed += 1
                let limits = [10, 10, 5, 5]
                if stage < 4 && completed >= limits[stage] { stage += 1; completed = 0 }
            }
            if !isOver { nextQuestion() }
        } else {
            streak = 0
            mistakes.append(ReviewItem(question: question.text, submitted: answer, correct: question.answer))
            mistakes = Array(mistakes.suffix(20))
            if isPractice {
                if !isOver { nextQuestion() }
            } else {
                lives -= 1
                availableAnswers.remove(answer)
            }
        }
        return true
    }

    @discardableResult
    public mutating func expire(questionID: UUID) -> Bool {
        guard !isPractice, !isOver, question.id == questionID else { return false }
        lives -= 1
        missed += 1
        streak = 0
        if !isOver { nextQuestion() }
        return true
    }

    private mutating func nextQuestion() {
        var random = SystemRandomNumberGenerator()
        question = Question.generate(stage: isPractice ? settings.practiceStage : stage,
                                     difficulty: settings.difficulty, using: &random)
        availableAnswers = Set(question.choices)
    }
}
