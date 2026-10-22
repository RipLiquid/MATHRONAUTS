package com.ripliquid.mathronauts.core

import org.junit.Assert.*
import org.junit.Test
import kotlin.random.Random

class PracticeTest {
    @Test fun allDifficultiesRespectRangesAndKeepFourDistinctChoices() {
        for (difficulty in Difficulty.entries) for (stage in 0..4) repeat(200) {
            val q = QuestionGenerator.generate(stage, it.toLong(), Random(it), difficulty)
            assertEquals(4, q.choices.toSet().size)
            assertEquals(1, q.choices.count { it == q.answer })
            when (q.operation) {
                Operation.ADD -> assertTrue(q.first in 1..difficulty.additionLimit && q.second in 1..difficulty.additionLimit)
                Operation.SUBTRACT -> assertTrue(q.first in 1..difficulty.subtractionLimit && q.second in 1..q.first)
                Operation.MULTIPLY -> assertTrue(q.first in 1..difficulty.tableLimit && q.second in 1..difficulty.tableLimit)
                Operation.DIVIDE -> {
                    assertTrue(q.answer in 1..difficulty.tableLimit && q.second in 1..q.answer)
                    assertEquals(0, q.first % q.second)
                }
            }
        }
        assertTrue(Difficulty.EASY.waveSpeed < Difficulty.NORMAL.waveSpeed)
        assertTrue(Difficulty.NORMAL.waveSpeed < Difficulty.HARD.waveSpeed)
    }

    @Test fun practiceEndsAfterTenAnswersWithoutLosingLives() {
        val game = GameSession(settings = SessionSettings(Difficulty.EASY, GameMode.PRACTICE, 3))
        repeat(10) { index ->
            assertFalse(game.isOver)
            val q = game.question
            assertEquals(Operation.DIVIDE, q.operation)
            assertFalse(game.expire(q.id))
            val answer = if (index % 2 == 0) q.answer else q.choices.first { it != q.answer }
            assertTrue(game.resolve(answer, q.id))
            assertFalse(game.resolve(answer, q.id))
        }
        assertTrue(game.isOver)
        assertEquals(3, game.lives)
        assertEquals(50, game.score)
        assertEquals(50, game.accuracy)
        assertEquals(5, game.mistakes.size)
        assertFalse(game.resolve(game.question.answer, game.question.id))
    }

    @Test fun mistakeReviewKeepsOriginalQuestionAndSolution() {
        val game = GameSession(settings = SessionSettings(mode = GameMode.PRACTICE))
        val q = game.question
        val wrong = q.choices.first { it != q.answer }
        game.resolve(wrong, q.id)
        assertEquals(ReviewItem(q.text, wrong, q.answer), game.mistakes.single())
        assertNotEquals(q.id, game.question.id)
    }

    @Test fun practiceRestorationPreservesSettingsCountersAndStreak() {
        val settings = SessionSettings(Difficulty.HARD, GameMode.PRACTICE, 2)
        val game = GameSession(settings = settings)
        repeat(4) { game.resolve(game.question.answer, game.question.id) }
        val restored = GameSession(saved = game.snapshot())
        assertEquals(game.snapshot(), restored.snapshot())
        repeat(6) { restored.resolve(restored.question.answer, restored.question.id) }
        assertTrue(restored.isOver)
        assertEquals(10, restored.bestStreak)
        assertEquals(100, restored.accuracy)
    }

    @Test fun statisticsSeparateOperationsAndCountOnlyCompletedRounds() {
        var stats = LearningStats()
        stats = stats.record(Operation.ADD, true, 1, false)
        stats = stats.record(Operation.ADD, false, 0, false)
        stats = stats.record(Operation.DIVIDE, true, 3, true)
        assertEquals(3, stats.attempts)
        assertEquals(2, stats.correct)
        assertEquals(66, stats.accuracy)
        assertEquals(50, stats.operations[Operation.ADD]!!.accuracy)
        assertEquals(100, stats.operations[Operation.DIVIDE]!!.accuracy)
        assertEquals(3, stats.bestStreak)
        assertEquals(1, stats.practiceRounds)
        assertEquals(0, LearningStats().accuracy)
    }
}
