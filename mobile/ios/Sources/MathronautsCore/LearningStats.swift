import Foundation

public struct OperationProgress: Codable, Equatable {
    public var attempts = 0
    public var correct = 0
    public var accuracy: Int { attempts == 0 ? 0 : correct * 100 / attempts }
    public init() {}
}

public struct LearningStats: Codable, Equatable {
    public private(set) var operations: [MathOperation: OperationProgress] = [:]
    public private(set) var bestStreak = 0
    public private(set) var practiceRounds = 0
    public var attempts: Int { operations.values.reduce(0) { $0 + $1.attempts } }
    public var correct: Int { operations.values.reduce(0) { $0 + $1.correct } }
    public var accuracy: Int { attempts == 0 ? 0 : correct * 100 / attempts }
    public init() {}

    public mutating func record(operation: MathOperation, correct: Bool, streak: Int, finishedPractice: Bool) {
        var progress = operations[operation] ?? OperationProgress()
        progress.attempts += 1
        if correct { progress.correct += 1 }
        operations[operation] = progress
        bestStreak = max(bestStreak, streak)
        if finishedPractice { practiceRounds += 1 }
    }

    public func encoded() throws -> Data { try JSONEncoder().encode(self) }
    public static func restored(from data: Data?) -> LearningStats {
        guard let data, let decoded = try? JSONDecoder().decode(Self.self, from: data),
              decoded.bestStreak >= 0, decoded.practiceRounds >= 0,
              decoded.operations.values.allSatisfy({ $0.attempts >= 0 && $0.correct >= 0 && $0.correct <= $0.attempts })
        else { return LearningStats() }
        return decoded
    }
}
