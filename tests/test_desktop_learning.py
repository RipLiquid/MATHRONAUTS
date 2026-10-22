import random

import pytest

from desktop.learning import Difficulty, ProgressStore, Session, Settings, generate_question


@pytest.mark.parametrize("difficulty", list(Difficulty))
@pytest.mark.parametrize("stage", range(5))
def test_desktop_question_ranges_and_choices(difficulty, stage):
    rng = random.Random(42)
    add, subtract, table = difficulty.limits
    for number in range(100):
        q = generate_question(stage, number, difficulty, rng)
        assert len(set(q.choices)) == 4
        assert q.choices.count(q.answer) == 1
        if q.operation == 0:
            assert 1 <= q.first <= add and 1 <= q.second <= add
            assert q.answer == q.first + q.second
        elif q.operation == 1:
            assert 1 <= q.second <= q.first <= subtract
            assert q.answer == q.first - q.second
        elif q.operation == 2:
            assert 1 <= q.first <= table and 1 <= q.second <= table
            assert q.answer == q.first * q.second
        else:
            assert q.second > 0 and q.first % q.second == 0
            assert q.answer == q.first // q.second
            assert 1 <= q.answer <= table


def test_practice_ten_answers_no_expiry_or_life_loss():
    game = Session(Settings(Difficulty.HARD, True, 3), random.Random(2))
    for index in range(10):
        assert not game.over
        q = game.question
        assert q.operation == 3
        assert not game.expire(q.id)
        answer = q.answer if index % 2 == 0 else next(a for a in q.choices if a != q.answer)
        assert game.submit(answer, q.id)
        assert not game.submit(answer, q.id)
    assert game.over and game.lives == 3
    assert game.correct == 5 and game.accuracy == 50 and game.score == 50
    assert len(game.mistakes) == 5


def test_arcade_progression_and_game_over():
    game = Session(rng=random.Random(1))
    for stage, limit in enumerate((10, 10, 5, 5)):
        for _ in range(limit - 1):
            game.submit(game.question.answer, game.question.id)
        assert game.stage == stage
        game.submit(game.question.answer, game.question.id)
        assert game.stage == stage + 1
    assert game.score == 300
    assert not game.submit(-1, game.question.id)
    q = game.question
    for wrong in [a for a in q.choices if a != q.answer]:
        assert game.submit(wrong, q.id)
    assert game.over
    assert not game.submit(q.answer, q.id)
    assert not game.expire(q.id)


def test_offline_progress_round_trip_and_reset(tmp_path):
    path = tmp_path / "progress.json"
    store = ProgressStore.load(path)
    store.best_scores = {"Normal": 100}
    store.settings = Settings(Difficulty.EASY, True, 0)
    game = Session(store.settings, random.Random(3))
    for _ in range(10):
        q = game.question
        game.submit(q.answer, q.id)
        store.record(q, q.answer, game)
    store.save()
    restored = ProgressStore.load(path)
    assert restored.operations["Addition"] == {"attempts": 10, "correct": 10}
    assert restored.best_streak == 10 and restored.practice_rounds == 1
    assert restored.settings == store.settings
    restored.reset_statistics()
    reset = ProgressStore.load(path)
    assert reset.operations == {} and reset.practice_rounds == 0
    assert reset.best_scores == {"Normal": 100}


def test_corrupt_progress_falls_back_without_crashing(tmp_path):
    path = tmp_path / "progress.json"
    path.write_text("broken", encoding="utf-8")
    assert ProgressStore.load(path).operations == {}
    path.write_text('{"operations":{"Addition":{"attempts":2,"correct":3}}}', encoding="utf-8")
    assert ProgressStore.load(path).operations == {}
