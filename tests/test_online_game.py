"""Check optional online transitions without a display or external network."""
from threading import Event
from types import SimpleNamespace

import pytest

from desktop.enhancements import EnhancedGame
from desktop.learning import Difficulty, Session, Settings
from desktop.online import OnlineGame


@pytest.fixture
def game(monkeypatch):
    def initialize(self, base, data_path):
        self.base = base
        self.settings = Settings(Difficulty.HARD)
        self.state = "menu"
        self.session = None
    monkeypatch.setattr(EnhancedGame, "__init__", initialize)
    return OnlineGame(SimpleNamespace(), None)


def finish_worker(game):
    # Wait for the worker's result, then let the normal update process it.
    result = game.online_results.get(timeout=2)
    game.online_results.put(result)
    game.update(0)


def test_request_returns_while_worker_is_waiting(game):
    started, release = Event(), Event()
    def blocked_request():
        started.set()
        assert release.wait(2)
        return []
    try:
        game.request_online("fetch", blocked_request)
        assert started.wait(2)
        assert game.online_busy
        assert game.online_message == "Connecting..."
        game.update(0)
        assert game.online_busy
    finally:
        release.set()
    finish_worker(game)
    assert not game.online_busy
    assert game.online_message == "No scores yet."


def test_worker_failure_returns_to_available_menu(game):
    def offline():
        from desktop.leaderboard import LeaderboardError
        raise LeaderboardError("Offline play still works.")
    game.request_online("fetch", offline)
    finish_worker(game)
    assert not game.online_busy
    assert game.state == "menu"
    assert game.online_message == "Offline play still works."


@pytest.mark.parametrize("practice,finished,state", [
    (True, True, "results"),
    (False, False, "results"),
    (False, True, "menu"),
])
def test_only_finished_arcade_results_allow_nickname(game, practice, finished, state):
    game.session = SimpleNamespace(settings=Settings(practice=practice), over=finished)
    game.state = state
    game.action("enter_nickname")
    assert game.state == state
    assert not game.online_busy


def test_score_submission_uses_round_difficulty_and_allows_one_attempt(game, monkeypatch):
    game.session = Session(Settings(Difficulty.EASY))
    game.session.score = 60
    game.session.lives = 0
    game.state = "results"
    game.nickname = "Player1"
    requests = []
    monkeypatch.setattr(game, "request_online", lambda *args: requests.append(args))
    game.action("enter_nickname")
    assert game.state == "nickname"
    game.action("send_score")
    game.action("send_score")
    assert len(requests) == 1
    assert requests[0][2:] == ("Player1", "Easy", 60)
    assert game.submission_attempted
    assert game.state == "results"


def test_cancel_and_short_nickname_never_submit(game, monkeypatch):
    game.session = SimpleNamespace(settings=Settings(), over=True)
    game.state = "nickname"
    game.nickname = "ab"
    monkeypatch.setattr(game, "request_online", lambda *args: pytest.fail("Unexpected submission"))
    game.action("send_score")
    assert game.state == "nickname"
    assert "at least 3" in game.online_message
    game.action("back_results")
    assert game.state == "results"
    assert not game.submission_attempted


def test_ordinary_menu_draw_does_not_request_network(game, monkeypatch):
    monkeypatch.setattr(EnhancedGame, "draw", lambda self: None)
    monkeypatch.setattr(game, "button", lambda *args: None)
    monkeypatch.setattr(game, "request_online", lambda *args: pytest.fail("Unexpected network request"))
    game.draw()
    assert not game.online_busy
