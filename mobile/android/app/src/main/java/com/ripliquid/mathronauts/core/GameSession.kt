package com.ripliquid.mathronauts.core

import java.io.Serializable
import kotlin.random.Random

enum class Operation(val symbol: String, val title: String) {
    ADD("+", "Addition"), SUBTRACT("−", "Subtraction"),
    MULTIPLY("×", "Multiplication"), DIVIDE("÷", "Division")
}

enum class Difficulty(val title: String, val additionLimit: Int, val subtractionLimit: Int,
                      val tableLimit: Int, val waveSpeed: Float) {
    EASY("Easy", 10, 20, 5, 7f), NORMAL("Normal", 25, 50, 10, 10f), HARD("Hard", 50, 100, 12, 15f)
}

enum class GameMode(val title: String) { ARCADE("Arcade"), PRACTICE("Practice") }

data class SessionSettings(val difficulty: Difficulty = Difficulty.NORMAL,
                           val mode: GameMode = GameMode.ARCADE,
                           val practiceStage: Int = 0) : Serializable {
    init { require(practiceStage in 0..4) }
}

data class ReviewItem(val question: String, val submitted: Int, val correct: Int) : Serializable

data class Question(
    val id: Long, val first: Int, val second: Int,
    val operation: Operation, val answer: Int, val choices: List<Int>
) : Serializable {
    val text: String get() = "$first ${operation.symbol} $second = ?"
}

object QuestionGenerator {
    fun generate(stage: Int, id: Long, random: Random, difficulty: Difficulty = Difficulty.NORMAL): Question {
        require(stage in 0..4)
        val operation = if (stage == 4) Operation.entries.random(random) else Operation.entries[stage]
        val first: Int
        val second: Int
        val answer: Int
        when (operation) {
            Operation.ADD -> {
                first = random.nextInt(1, difficulty.additionLimit + 1)
                second = random.nextInt(1, difficulty.additionLimit + 1); answer = first + second
            }
            Operation.SUBTRACT -> {
                first = random.nextInt(1, difficulty.subtractionLimit + 1)
                second = random.nextInt(1, first + 1); answer = first - second
            }
            Operation.MULTIPLY -> {
                first = random.nextInt(1, difficulty.tableLimit + 1)
                second = random.nextInt(1, difficulty.tableLimit + 1); answer = first * second
            }
            Operation.DIVIDE -> {
                answer = random.nextInt(1, difficulty.tableLimit + 1)
                second = random.nextInt(1, answer + 1); first = answer * second
            }
        }
        val upper = if (stage <= 1) difficulty.subtractionLimit - 1 else difficulty.tableLimit * difficulty.tableLimit - 1
        val wrong = (1..upper).filter { it != answer }.shuffled(random).take(3)
        return Question(id, first, second, operation, answer, (wrong + answer).shuffled(random))
    }
}

data class GameSnapshot(
    val score: Int, val lives: Int, val stage: Int, val completed: Int,
    val question: Question, val availableAnswers: Set<Int>,
    val settings: SessionSettings, val attempts: Int, val correctAnswers: Int,
    val streak: Int, val bestStreak: Int, val missed: Int, val mistakes: List<ReviewItem>
) : Serializable

class GameSession(private val random: Random = Random.Default, saved: GameSnapshot? = null,
                  settings: SessionSettings = SessionSettings()) {
    val settings = saved?.settings ?: settings
    var score = saved?.score ?: 0
        private set
    var lives = saved?.lives ?: 3
        private set
    var stage = saved?.stage ?: 0
        private set
    var completed = saved?.completed ?: 0
        private set
    var question = saved?.question ?: QuestionGenerator.generate(
        if (this.settings.mode == GameMode.PRACTICE) this.settings.practiceStage else 0,
        1, random, this.settings.difficulty)
        private set
    var availableAnswers = saved?.availableAnswers ?: question.choices.toSet()
        private set
    var attempts = saved?.attempts ?: 0
        private set
    var correctAnswers = saved?.correctAnswers ?: 0
        private set
    var streak = saved?.streak ?: 0
        private set
    var bestStreak = saved?.bestStreak ?: 0
        private set
    var missed = saved?.missed ?: 0
        private set
    var mistakes = saved?.mistakes ?: emptyList()
        private set
    val isPractice: Boolean get() = settings.mode == GameMode.PRACTICE
    val isOver: Boolean get() = if (isPractice) attempts >= 10 else lives == 0
    val accuracy: Int get() = if (attempts == 0) 0 else correctAnswers * 100 / attempts
    val stageTitle: String get() {
        val selected = if (isPractice) settings.practiceStage else stage
        return if (selected == 4) "Mixed operations" else Operation.entries[selected].title
    }

    fun resolve(answer: Int, questionId: Long): Boolean {
        if (isOver || question.id != questionId || answer !in availableAnswers) return false
        attempts++
        if (answer == question.answer) {
            score += 10
            correctAnswers++
            streak++
            bestStreak = maxOf(bestStreak, streak)
            if (!isPractice) {
                completed++
                val limit = listOf(10, 10, 5, 5).getOrNull(stage)
                if (limit != null && completed >= limit) { stage++; completed = 0 }
            }
            if (!isOver) nextQuestion()
        } else {
            streak = 0
            mistakes = (mistakes + ReviewItem(question.text, answer, question.answer)).takeLast(20)
            if (isPractice) {
                if (!isOver) nextQuestion()
            } else {
                lives--
                availableAnswers = availableAnswers - answer
            }
        }
        return true
    }

    fun expire(questionId: Long): Boolean {
        if (isPractice || isOver || question.id != questionId) return false
        lives--
        missed++
        streak = 0
        if (!isOver) nextQuestion()
        return true
    }

    fun snapshot() = GameSnapshot(score, lives, stage, completed, question, availableAnswers,
        settings, attempts, correctAnswers, streak, bestStreak, missed, mistakes)

    private fun nextQuestion() {
        question = QuestionGenerator.generate(if (isPractice) settings.practiceStage else stage,
            question.id + 1, random, settings.difficulty)
        availableAnswers = question.choices.toSet()
    }
}
