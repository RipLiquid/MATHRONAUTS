import SpriteKit
import MathronautsCore

final class GameScene: SKScene {
    var onAnswer: ((Int, UUID) -> Void)?
    var onExpired: ((UUID) -> Void)?
    var onBusyChanged: ((Bool) -> Void)?
    private let ship = SKSpriteNode(imageNamed: "spaceship4")
    private var meteors: [SKSpriteNode] = []
    private var questionID: UUID?
    private var shotInFlight = false
    private var activeShot: SKNode?
    private var previousTime: TimeInterval?
    private var movementTouch: UITouch?
    private var waveSpeed: CGFloat = 10
    private var practice = false

    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .aspectFit
        backgroundColor = .black
        let background = SKSpriteNode(imageNamed: "space")
        background.size = size
        background.position = CGPoint(x: size.width / 2, y: size.height / 2)
        background.zPosition = -10
        addChild(background)
        ship.size = CGSize(width: 48, height: 48)
        ship.position = CGPoint(x: 48, y: size.height / 2)
        addChild(ship)
        let defense = SKShapeNode(rectOf: CGSize(width: 2, height: size.height))
        defense.position = CGPoint(x: 82, y: size.height / 2)
        defense.fillColor = .cyan
        defense.strokeColor = .clear
        defense.alpha = 0.3
        addChild(defense)
    }

    required init?(coder: NSCoder) { fatalError("Use init(size:)") }

    func resetPlayer() {
        ship.position = CGPoint(x: 48, y: size.height / 2)
        movementTouch = nil
        previousTime = nil
    }

    func present(_ session: GameSession) {
        waveSpeed = CGFloat(session.settings.difficulty.waveSpeed)
        practice = session.isPractice
        let newWave = questionID != session.question.id
        if newWave {
            activeShot?.removeAllActions()
            activeShot?.removeFromParent()
            activeShot = nil
            meteors.forEach { $0.removeFromParent() }
            meteors = []
            questionID = session.question.id
            shotInFlight = false
            for (index, answer) in session.question.choices.enumerated() {
                let meteor = SKSpriteNode(imageNamed: "meteor1")
                meteor.name = String(answer)
                meteor.size = CGSize(width: 62, height: 62)
                meteor.position = CGPoint(x: 340, y: 110 + CGFloat(index) * 140)
                let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
                label.text = String(answer)
                label.fontSize = 25
                label.fontColor = .white
                label.verticalAlignmentMode = .center
                label.zPosition = 1
                meteor.addChild(label)
                meteors.append(meteor)
                addChild(meteor)
            }
        }
        for meteor in meteors where !session.availableAnswers.contains(Int(meteor.name ?? "") ?? -1) {
            meteor.removeFromParent()
        }
        meteors.removeAll { $0.parent == nil }
        if session.isOver {
            activeShot?.removeAllActions()
            activeShot?.removeFromParent()
            activeShot = nil
            movementTouch = nil
        }
        previousTime = nil
    }

    override func update(_ currentTime: TimeInterval) {
        defer { previousTime = currentTime }
        guard let previousTime, let questionID, !shotInFlight, !practice else { return }
        let delta = CGFloat(min(max(currentTime - previousTime, 0), 1.0 / 15))
        for meteor in meteors { meteor.position.x -= waveSpeed * delta }
        if meteors.contains(where: { $0.position.x <= 110 }) {
            onExpired?(questionID)
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let point = touch.location(in: self)
            if point.x < 85 {
                if movementTouch == nil { movementTouch = touch; moveShip(to: point.y) }
            } else if let meteor = meteors.first(where: { $0.contains(point) }) {
                fire(at: meteor)
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches where touch === movementTouch { moveShip(to: touch.location(in: self).y) }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if touches.contains(where: { $0 === movementTouch }) { movementTouch = nil }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }

    private func moveShip(to y: CGFloat) { ship.position.y = min(max(y, 30), size.height - 30) }

    func fire(answer: Int) {
        if let meteor = meteors.first(where: { $0.name == String(answer) }) { fire(at: meteor) }
    }

    private func fire(at meteor: SKSpriteNode) {
        guard !shotInFlight, let id = questionID, let answer = Int(meteor.name ?? "") else { return }
        shotInFlight = true
        onBusyChanged?(true)
        // Freeze the wave during this shot so its selected target stays under the impact.
        let shot = SKShapeNode(circleOfRadius: 5)
        shot.fillColor = .cyan
        shot.strokeColor = .white
        shot.position = ship.position
        shot.zPosition = 2
        addChild(shot)
        activeShot = shot
        let travel = SKAction.move(to: meteor.position, duration: 0.3)
        shot.run(.sequence([travel, .run { [weak self, weak shot] in
            shot?.removeFromParent()
            guard let self else { return }
            self.activeShot = nil
            self.shotInFlight = false
            self.onBusyChanged?(false)
            self.previousTime = nil
            self.onAnswer?(answer, id)
        }]))
    }
}
