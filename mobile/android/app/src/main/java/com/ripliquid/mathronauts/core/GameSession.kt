package com.ripliquid.mathronauts.core

import java.io.Serializable
import kotlin.random.Random

enum class Operation(val symbol: String, val title: String) {
    ADD("+", "Addition"), SUBTRACT("−", "Subtraction"),
    MULTIPLY("×", "Multiplication"), DIVIDE("÷", "Division")
}

data class Question(
    val id: Long, val first: Int, val second: Int,
    val operation: Operation, val answer: Int, val choices: List<Int>
) : Serializable {
    val text: String get() = "$first ${operation.symbol} $second = ?"
}

object QuestionGenerator {
    fun generate(stage: Int, id: Long, random: Random): Question {
        require(stage in 0..4)
        val operation = if (stage == 4) Operation.entries.random(random) else Operation.entries[stage]
        val first: Int
        val second: Int
        val answer: Int
        when (operation) {
            Operation.ADD -> {
                first = random.nextInt(1, 26); second = random.nextInt(1, 26); answer = first + second
            }
            Operation.SUBTRACT -> {
                first = random.nextInt(1, 51); second = random.nextInt(1, first + 1); answer = first - second
            }
            Operation.MULTIPLY -> {
                first = random.nextInt(1, 11); second = random.nextInt(1, 11); answer = first * second
            }
            Operation.DIVIDE -> {
                answer = random.nextInt(1, 11); second = random.nextInt(1, answer + 1); first = answer * second
            }
        }
        val upper = if (stage <= 1) 49 else 99
        val wrong = (1..upper).filter { it != answer }.shuffled(random).take(3)
        return Question(id, first, second, operation, answer, (wrong + answer).shuffled(random))
    }
}

data class GameSnapshot(
    val score: Int, val lives: Int, val stage: Int, val completed: Int,
    val question: Question, val availableAnswers: Set<Int>
) : Serializable

class GameSession(private val random: Random = Random.Default, saved: GameSnapshot? = null) {
    var score = saved?.score ?: 0
        private set
    var lives = saved?.lives ?: 3
        private set
    var stage = saved?.stage ?: 0
        private set
    var completed = saved?.completed ?: 0
        private set
    var question = saved?.question ?: QuestionGenerator.generate(0, 1, random)
        private set
    var availableAnswers = saved?.availableAnswers ?: question.choices.toSet()
        private set
    val isOver: Boolean get() = lives == 0
    val stageTitle: String get() = if (stage == 4) "Mixed operations" else Operation.entries[stage].title

    fun resolve(answer: Int, questionId: Long): Boolean {
        if (isOver || question.id != questionId || answer !in availableAnswers) return false
        if (answer == question.answer) {
            score += 10
            completed++
            val limit = listOf(10, 10, 5, 5).getOrNull(stage)
            if (limit != null && completed >= limit) { stage++; completed = 0 }
            nextQuestion()
        } else {
            lives--
            availableAnswers = availableAnswers - answer
        }
        return true
    }

    fun expire(questionId: Long): Boolean {
        if (isOver || question.id != questionId) return false
        lives--
        if (!isOver) nextQuestion()
        return true
    }

    fun snapshot() = GameSnapshot(score, lives, stage, completed, question, availableAnswers)

    private fun nextQuestion() {
        question = QuestionGenerator.generate(stage, question.id + 1, random)
        availableAnswers = question.choices.toSet()
    }
}
