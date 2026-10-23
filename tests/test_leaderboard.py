"""Desktop API contract and offline failures; these tests never contact AWS."""
from io import BytesIO
import json
from urllib.error import HTTPError, URLError

import pytest

from desktop import leaderboard


def entry(score=120):
    return {"nickname": "Player1", "score": score, "createdAt": "2026-10-23T01:00:00+00:00"}


def reply(monkeypatch, payload):
    monkeypatch.setattr(leaderboard, "urlopen", lambda *a, **k: BytesIO(json.dumps(payload).encode()))


def test_fetch_uses_get_with_normalized_difficulty_and_timeout(monkeypatch):
    def open_request(request, timeout):
        assert request.get_method() == "GET"
        assert request.full_url == leaderboard.API_URL + "?difficulty=normal"
        assert request.data is None
        assert timeout == 5
        return BytesIO(json.dumps({"difficulty": "normal", "entries": [entry()]}).encode())
    monkeypatch.setattr(leaderboard, "urlopen", open_request)
    assert leaderboard.fetch_scores("Normal") == [entry()]


def test_submit_sends_json_without_aws_credentials_or_retries(monkeypatch):
    calls = []
    def open_request(request, timeout):
        calls.append(request)
        assert request.get_method() == "POST"
        assert request.full_url == leaderboard.API_URL
        assert not request.has_header("Authorization")
        assert json.loads(request.data) == {"nickname": "Player1", "difficulty": "hard", "score": 60}
        return BytesIO(b'{"message":"Score submitted.","submissionId":"test-id"}')
    monkeypatch.setattr(leaderboard, "urlopen", open_request)
    assert leaderboard.submit_score("Player1", "Hard", 60)["submissionId"] == "test-id"
    assert len(calls) == 1


@pytest.mark.parametrize("error", [URLError("offline"), TimeoutError("timeout"), OSError("connection reset")])
def test_network_failures_are_reported_without_retry(monkeypatch, error):
    calls = []
    def fail(*args, **kwargs):
        calls.append(1)
        raise error
    monkeypatch.setattr(leaderboard, "urlopen", fail)
    with pytest.raises(leaderboard.LeaderboardError, match="Offline play still works"):
        leaderboard.fetch_scores("easy")
    assert len(calls) == 1


@pytest.mark.parametrize("status", [400, 429, 503])
def test_http_errors_remain_distinct(monkeypatch, status):
    def fail(*args, **kwargs):
        raise HTTPError(leaderboard.API_URL, status, "request failed", {}, None)
    monkeypatch.setattr(leaderboard, "urlopen", fail)
    with pytest.raises(leaderboard.LeaderboardError, match=str(status)):
        leaderboard.submit_score("Player1", "normal", 20)


def test_non_json_response_is_an_availability_error(monkeypatch):
    monkeypatch.setattr(leaderboard, "urlopen", lambda *a, **k: BytesIO(b"<html>Unavailable</html>"))
    with pytest.raises(leaderboard.LeaderboardError):
        leaderboard.fetch_scores("normal")


@pytest.mark.parametrize("payload", [
    None,
    {"difficulty": "hard", "entries": []},
    {"difficulty": "normal"},
    {"difficulty": "normal", "entries": {}},
    {"difficulty": "normal", "entries": [entry()] * 11},
    {"difficulty": "normal", "entries": [{"nickname": "Player1"}]},
    {"difficulty": "normal", "entries": [entry(True)]},
    {"difficulty": "normal", "entries": [entry(-10)]},
    {"difficulty": "normal", "entries": [entry(15)]},
    {"difficulty": "normal", "entries": [entry(20), entry(120)]},
])
def test_bad_rankings_do_not_reach_the_ui(monkeypatch, payload):
    reply(monkeypatch, payload)
    with pytest.raises(leaderboard.LeaderboardError):
        leaderboard.fetch_scores("normal")


def test_empty_rankings_are_valid(monkeypatch):
    reply(monkeypatch, {"difficulty": "easy", "entries": []})
    assert leaderboard.fetch_scores("Easy") == []


def test_submission_requires_acknowledgement(monkeypatch):
    reply(monkeypatch, {"error": "not saved"})
    with pytest.raises(leaderboard.LeaderboardError):
        leaderboard.submit_score("Player1", "normal", 20)
