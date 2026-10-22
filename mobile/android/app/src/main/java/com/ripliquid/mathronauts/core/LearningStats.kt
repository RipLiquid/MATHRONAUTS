package com.ripliquid.mathronauts.core

data class OperationProgress(val attempts: Int = 0, val correct: Int = 0) {
    init { require(attempts >= 0 && correct in 0..attempts) }
    val accuracy: Int get() = if (attempts == 0) 0 else correct * 100 / attempts
}

data class LearningStats(val operations: Map<Operation, OperationProgress> = emptyMap(),
                         val bestStreak: Int = 0, val practiceRounds: Int = 0) {
    init { require(bestStreak >= 0 && practiceRounds >= 0) }
    val attempts: Int get() = operations.values.sumOf { it.attempts }
    val correct: Int get() = operations.values.sumOf { it.correct }
    val accuracy: Int get() = if (attempts == 0) 0 else correct * 100 / attempts

    fun record(operation: Operation, correct: Boolean, streak: Int, finishedPractice: Boolean): LearningStats {
        val previous = operations[operation] ?: OperationProgress()
        val next = OperationProgress(previous.attempts + 1, previous.correct + if (correct) 1 else 0)
        return LearningStats(operations + (operation to next), maxOf(bestStreak, streak),
            practiceRounds + if (finishedPractice) 1 else 0)
    }
}
