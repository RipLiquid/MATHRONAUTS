import SwiftUI
import SpriteKit
import MathronautsCore

struct ContentView: View {
    @StateObject private var game = GameController()
    @Environment(\.scenePhase) private var phase
    @State private var showStatistics = false

    var body: some View {
        VStack(spacing: 10) {
            if game.playing && game.session.isOver {
                results
            } else if game.playing {
                HStack {
                    Text("Score \(game.session.score)")
                    Spacer()
                    Text(game.session.isPractice ? "\(game.session.attempts + 1)/10" : "Lives \(game.session.lives)")
                    Button(game.paused ? "Resume" : "Pause") { game.paused.toggle() }
                }
                Text("\(game.session.stageTitle) · \(game.session.settings.difficulty.rawValue)").font(.caption)
                Text(game.session.question.text).font(.largeTitle.bold())
                    .accessibilityIdentifier("question")
                    .accessibilityValue(game.session.question.id.uuidString)
                ZStack {
                    SpriteView(scene: game.scene, isPaused: game.paused)
                        .aspectRatio(390.0 / 650.0, contentMode: .fit)
                        .allowsHitTesting(!game.paused)
                    if game.paused {
                        VStack(spacing: 16) {
                            Button("Resume mission") { game.paused = false }
                            Button("Main menu") { game.playing = false }
                        }
                        .padding().background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 16))
                    }
                }
                HStack {
                    ForEach(game.session.question.choices, id: \.self) { answer in
                        Button(String(answer)) { game.scene.fire(answer: answer) }
                            .buttonStyle(.bordered).frame(maxWidth: .infinity)
                            .accessibilityIdentifier("answer.\(answer)")
                            .disabled(game.paused || game.busy || !game.session.availableAnswers.contains(answer))
                    }
                }
                Text(game.feedback).font(.callout).multilineTextAlignment(.center)
                Text("Drag on the left to move. Tap an answer meteor to fire.")
                    .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            } else {
                Spacer()
                ScrollView {
                    VStack(spacing: 16) {
                        Image(systemName: "sparkles").font(.system(size: 44)).foregroundStyle(.cyan)
                        Text("MATHRONAUTS").font(.largeTitle.bold()).minimumScaleFactor(0.5)
                        Text("An arithmetic mission in space").foregroundStyle(.secondary)
                        Picker("Mode", selection: $game.mode) {
                            ForEach(GameMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }.pickerStyle(.segmented)
                        Picker("Difficulty", selection: $game.difficulty) {
                            ForEach(Difficulty.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }.pickerStyle(.segmented)
                        if game.mode == .practice {
                            Picker("Operation", selection: $game.practiceStage) {
                                ForEach(0..<5) { index in
                                    Text(index == 4 ? "Mixed operations" : MathOperation.allCases[index].title).tag(index)
                                }
                            }
                            Text("10 questions · No timer · No life loss").font(.caption)
                        } else {
                            Text("3 lives · Five stages · Best: \(game.arcadeHighScore)").font(.caption)
                        }
                        Text("Easy uses smaller numbers and slower meteors; Hard uses larger numbers and faster meteors.")
                            .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        Button(game.mode == .practice ? "Start practice" : "Launch mission") { game.start() }
                            .buttonStyle(.borderedProminent).controlSize(.large)
                        Button("Learning statistics") { showStatistics = true }
                    }
                }.fixedSize(horizontal: false, vertical: true)
                Spacer()
            }
        }
        .padding()
        .background(Color(red: 0.025, green: 0.04, blue: 0.10))
        .sheet(isPresented: $showStatistics) { StatisticsView(game: game) }
        .onChange(of: phase) { newPhase in
            if newPhase != .active && game.playing { game.paused = true }
        }
    }

    private var results: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(game.session.isPractice ? "Practice complete" : "Mission over").font(.largeTitle.bold())
                Text("\(game.session.correctAnswers)/\(game.session.attempts) correct · \(game.session.accuracy)% accuracy")
                Text("Score \(game.session.score) · Best streak \(game.session.bestStreak)")
                if game.session.missed > 0 { Text("Missed waves: \(game.session.missed)") }
                Text("Answer review").font(.title2.bold())
                if game.session.mistakes.isEmpty { Text("No incorrect answers to review.") }
                ForEach(Array(game.session.mistakes.enumerated()), id: \.offset) { _, item in
                    VStack(alignment: .leading) {
                        Text(item.question).font(.headline)
                        Text("Your answer: \(item.submitted) · Correct: \(item.correct)")
                    }.padding().frame(maxWidth: .infinity, alignment: .leading)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
                Button("Play again") { game.start() }.buttonStyle(.borderedProminent)
                Button("Learning statistics") { showStatistics = true }
                Button("Main menu") { game.playing = false }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct StatisticsView: View {
    @ObservedObject var game: GameController
    @Environment(\.dismiss) private var dismiss
    @State private var confirmReset = false
    var body: some View {
        NavigationStack {
            List {
                Section("All answers on this device") {
                    Text("\(game.learningStats.correct)/\(game.learningStats.attempts) correct · \(game.learningStats.accuracy)% accuracy")
                    Text("Best streak: \(game.learningStats.bestStreak)")
                    Text("Practice rounds: \(game.learningStats.practiceRounds)")
                }
                Section("Accuracy by operation") {
                    ForEach(MathOperation.allCases, id: \.self) { operation in
                        let progress = game.learningStats.operations[operation] ?? OperationProgress()
                        VStack(alignment: .leading) {
                            Text("\(operation.title): \(progress.correct)/\(progress.attempts) (\(progress.accuracy)%)")
                            ProgressView(value: Double(progress.accuracy), total: 100)
                        }
                    }
                }
                Section {
                    Text("Saved locally. No account, network connection or cloud service required.")
                    Button("Reset statistics", role: .destructive) { confirmReset = true }
                }
            }
            .navigationTitle("Learning statistics")
            .toolbar { Button("Done") { dismiss() } }
            .confirmationDialog("Reset learning statistics? Arcade best scores stay saved.", isPresented: $confirmReset) {
                Button("Reset", role: .destructive) { game.resetStatistics() }
            }
        }
    }
}
