import SwiftUI
import MathronautsCore

final class GameController: ObservableObject {
    @Published private(set) var session = GameSession()
    @Published var playing = false
    @Published var paused = false
    @Published private(set) var feedback = "Protect the mothership!"
    let scene = GameScene(size: CGSize(width: 390, height: 650))

    init() {
        scene.onAnswer = { [weak self] answer, id in
            guard let self else { return }
            let correct = answer == self.session.question.answer
            guard self.session.resolve(answer: answer, questionID: id) else { return }
            self.feedback = correct ? "Correct! +10" : "Wrong answer. One life lost."
            self.scene.present(self.session)
        }
        scene.onExpired = { [weak self] id in
            guard let self, self.session.expire(questionID: id) else { return }
            self.feedback = "Wave reached the defense line. One life lost."
            self.scene.present(self.session)
        }
    }

    func start() {
        session = GameSession()
        feedback = "Protect the mothership!"
        paused = false
        scene.resetPlayer()
        scene.present(session)
        playing = true
    }
}
