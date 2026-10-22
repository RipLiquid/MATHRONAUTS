package com.ripliquid.mathronauts.core

import org.junit.Assert.*
import org.junit.Test
import kotlin.random.Random

class GameSessionTest {
    @Test fun allStagesProduceValidUniqueAnswers() {
        val random = Random(42)
        for (stage in 0..4) repeat(1000) {
            val q = QuestionGenerator.generate(stage, it.toLong(), random)
            assertEquals(4, q.choices.toSet().size)
            assertEquals(1, q.choices.count { choice -> choice == q.answer })
            when (q.operation) {
                Operation.ADD -> {
                    assertTrue(q.first in 1..25 && q.second in 1..25)
                    assertEquals(q.first + q.second, q.answer)
                }
                Operation.SUBTRACT -> {
                    assertTrue(q.first in 1..50 && q.second in 1..q.first)
                    assertEquals(q.first - q.second, q.answer)
                }
                Operation.MULTIPLY -> {
                    assertTrue(q.first in 1..10 && q.second in 1..10)
                    assertEquals(q.first * q.second, q.answer)
                }
                Operation.DIVIDE -> {
                    assertTrue(q.second > 0)
                    assertEquals(0, q.first % q.second)
                    assertEquals(q.first / q.second, q.answer)
                    assertTrue(q.answer in 1..10)
                }
            }
        }
    }

    @Test fun correctAnswerScoresOnceAndAdvances() {
        val game = GameSession(Random(10))
        val q = game.question
        assertTrue(game.resolve(q.answer, q.id))
        assertEquals(10, game.score)
        assertEquals(3, game.lives)
        assertFalse(game.resolve(q.answer, q.id))
        assertEquals(10, game.score)
    }

    @Test fun wrongAnswerRemovesOnlyOneLifeAndCannotBeRepeated() {
        val game = GameSession(Random(10))
        val q = game.question
        val wrong = q.choices.first { it != q.answer }
        assertTrue(game.resolve(wrong, q.id))
        assertFalse(game.resolve(wrong, q.id))
        assertEquals(2, game.lives)
        assertEquals(q, game.question)
        assertEquals(0, game.score)
    }

    @Test fun expiryRejectsRepeatedWaveAndInvalidChoices() {
        val game = GameSession()
        val id = game.question.id
        assertFalse(game.resolve(-1, id))
        assertTrue(game.expire(id))
        assertFalse(game.expire(id))
        assertEquals(2, game.lives)
    }

    @Test fun progressionMatchesOriginalAndMixedContinues() {
        val game = GameSession(Random(2))
        for (stage in 0..3) {
            val limit = listOf(10, 10, 5, 5)[stage]
            repeat(limit - 1) { game.resolve(game.question.answer, game.question.id) }
            assertEquals(stage, game.stage)
            game.resolve(game.question.answer, game.question.id)
            assertEquals(stage + 1, game.stage)
            assertEquals(0, game.completed)
        }
        repeat(100) { game.resolve(game.question.answer, game.question.id) }
        assertEquals(4, game.stage)
        assertEquals(1300, game.score)
    }

    @Test fun gameOverRejectsInputAndNewGameResets() {
        val game = GameSession()
        val q = game.question
        q.choices.filter { it != q.answer }.forEach { game.resolve(it, q.id) }
        assertTrue(game.isOver)
        assertFalse(game.resolve(q.answer, q.id))
        assertFalse(game.expire(q.id))
        val reset = GameSession()
        assertEquals(0, reset.score)
        assertEquals(3, reset.lives)
        assertEquals(0, reset.stage)
    }

    @Test fun restoringSnapshotPreservesProgressAndRemovedChoices() {
        val game = GameSession(Random(8))
        repeat(12) { game.resolve(game.question.answer, game.question.id) }
        game.resolve(game.question.choices.first { it != game.question.answer }, game.question.id)
        val restored = GameSession(Random(9), game.snapshot())
        assertEquals(game.snapshot(), restored.snapshot())
        restored.resolve(restored.question.answer, restored.question.id)
        assertEquals(130, restored.score)
        assertTrue(restored.question.id > game.question.id)
    }
}
