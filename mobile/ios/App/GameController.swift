import SwiftUI
import MathronautsCore

final class GameController: ObservableObject {
    @Published private(set) var session = GameSession()
    @Published private(set) var learningStats = LearningStats()
    @Published var playing = false
    @Published var paused = false
    @Published private(set) var busy = false
    @Published var difficulty: Difficulty = .normal {
        didSet { defaults.set(difficulty.rawValue, forKey: "difficulty") }
    }
    @Published var mode: GameMode = .arcade {
        didSet { defaults.set(mode.rawValue, forKey: "mode") }
    }
    @Published var practiceStage = 0 {
        didSet { defaults.set(practiceStage, forKey: "practiceStage") }
    }
    @Published private(set) var feedback = "Protect the mothership!"
    let scene = GameScene(size: CGSize(width: 390, height: 650))
    private let defaults = UserDefaults.standard

    var arcadeHighScore: Int { defaults.integer(forKey: "arcadeBest.\(difficulty.rawValue)") }

    init() {
        difficulty = Difficulty(rawValue: defaults.string(forKey: "difficulty") ?? "") ?? .normal
        mode = GameMode(rawValue: defaults.string(forKey: "mode") ?? "") ?? .arcade
        practiceStage = min(max(defaults.integer(forKey: "practiceStage"), 0), 4)
        learningStats = LearningStats.restored(from: defaults.data(forKey: "learningStats.v1"))
        scene.onBusyChanged = { [weak self] in self?.busy = $0 }
        scene.onAnswer = { [weak self] answer, id in
            guard let self else { return }
            let previous = self.session.question
            let correct = answer == previous.answer
            guard self.session.resolve(answer: answer, questionID: id) else { return }
            self.learningStats.record(operation: previous.operation, correct: correct,
                streak: self.session.streak, finishedPractice: self.session.isPractice && self.session.isOver)
            self.saveStatistics()
            if !self.session.isPractice {
                let key = "arcadeBest.\(self.session.settings.difficulty.rawValue)"
                self.defaults.set(max(self.defaults.integer(forKey: key), self.session.score), forKey: key)
            }
            self.feedback = correct ? "Correct! +10" : self.session.isPractice ?
                "Keep practicing. Review the solution in your results." : "Wrong answer. One life lost."
            self.scene.present(self.session)
        }
        scene.onExpired = { [weak self] id in
            guard let self, self.session.expire(questionID: id) else { return }
            self.feedback = "Wave reached the defense line. One life lost."
            self.scene.present(self.session)
        }
    }

    func start() {
        session = GameSession(settings: SessionSettings(difficulty: difficulty, mode: mode, practiceStage: practiceStage))
        feedback = session.isPractice ? "Ten questions. Take your time." : "Protect the mothership!"
        paused = false
        busy = false
        scene.resetPlayer()
        scene.present(session)
        playing = true
    }

    func resetStatistics() {
        learningStats = LearningStats()
        saveStatistics()
    }

    private func saveStatistics() {
        if let data = try? learningStats.encoded() { defaults.set(data, forKey: "learningStats.v1") }
    }
}
