import SwiftUI
import SpriteKit

struct ContentView: View {
    @StateObject private var game = GameController()
    @Environment(\.scenePhase) private var phase

    var body: some View {
        VStack(spacing: 12) {
            if game.playing {
                HStack {
                    Text("Score \(game.session.score)")
                    Spacer()
                    Text("Lives \(game.session.lives)")
                    Button(game.paused ? "Resume" : "Pause") { game.paused.toggle() }
                        .disabled(game.session.isOver)
                }
                Text(game.session.question.text).font(.largeTitle.bold())
                ZStack {
                    SpriteView(scene: game.scene, isPaused: game.paused || game.session.isOver)
                        .aspectRatio(390.0 / 650.0, contentMode: .fit)
                        .allowsHitTesting(!game.paused && !game.session.isOver)
                    if game.session.isOver {
                        VStack(spacing: 16) {
                            Text("Mission over").font(.largeTitle.bold())
                            Text("Final score: \(game.session.score)")
                            Button("Play again") { game.start() }.buttonStyle(.borderedProminent)
                            Button("Main menu") { game.playing = false }
                        }
                        .padding(28).background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 20))
                    } else if game.paused {
                        Button("Resume mission") { game.paused = false }
                            .buttonStyle(.borderedProminent)
                    }
                }
                Text(game.feedback).font(.callout).accessibilityLabel(game.feedback)
                Text("Drag on the left to move. Tap an answer meteor to fire.")
                    .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            } else {
                Spacer()
                Image(systemName: "sparkles").font(.system(size: 64)).foregroundStyle(.cyan)
                Text("MATHRONAUTS").font(.largeTitle.bold()).minimumScaleFactor(0.5)
                Text("An arithmetic mission in space").foregroundStyle(.secondary)
                Button("Launch mission") { game.start() }
                    .buttonStyle(.borderedProminent).controlSize(.large)
                Text("Addition prototype · 3 lives · 10 points per correct answer")
                    .font(.caption).multilineTextAlignment(.center)
                Spacer()
            }
        }
        .padding()
        .background(Color(red: 0.025, green: 0.04, blue: 0.10))
        .onChange(of: phase) { newPhase in
            if newPhase != .active && game.playing { game.paused = true }
        }
    }
}
