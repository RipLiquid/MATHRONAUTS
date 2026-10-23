"""Optional connection to the MATHRONAUTS leaderboard."""
import json
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen

API_URL = (
    "https://e2mhxo25fsc3brbzm2hszueea40ywcpc"
    ".lambda-url.ca-central-1.on.aws/"
)


class LeaderboardError(Exception):
    pass


def _request(url, data=None):
    body = None if data is None else json.dumps(data).encode("utf-8")
    request = Request(
        url,
        data=body,
        headers={
            "Content-Type": "application/json",
            "Accept": "application/json"
        }
    )

    try:
        with urlopen(request, timeout=5) as result:
            return json.load(result)
    except HTTPError as error:
        raise LeaderboardError(
            f"Leaderboard request failed ({error.code})."
        ) from error
    except (URLError, OSError, ValueError) as error:
        raise LeaderboardError(
            "Leaderboard unavailable. Offline play still works."
        ) from error


def fetch_scores(difficulty):
    difficulty = difficulty.lower()
    query = urlencode({"difficulty": difficulty})
    result = _request(API_URL + "?" + query)
    if not isinstance(result, dict) or result.get("difficulty") != difficulty:
        raise LeaderboardError("Invalid leaderboard response.")
    entries = result.get("entries")
    if not isinstance(entries, list) or len(entries) > 10:
        raise LeaderboardError("Invalid leaderboard response.")
    for entry in entries:
        if (
            not isinstance(entry, dict)
            or not isinstance(entry.get("nickname"), str)
            or not 3 <= len(entry["nickname"]) <= 16
            or type(entry.get("score")) is not int
            or not 0 <= entry["score"] <= 999999990
            or entry["score"] % 10 != 0
            or not isinstance(entry.get("createdAt"), str)
        ):
            raise LeaderboardError("Invalid leaderboard response.")
    if any(a["score"] < b["score"] for a, b in zip(entries, entries[1:])):
        raise LeaderboardError("Leaderboard scores are out of order.")
    return entries


def submit_score(nickname, difficulty, score):
    result = _request(API_URL, {
        "nickname": nickname,
        "difficulty": difficulty.lower(),
        "score": score
    })
    if not isinstance(result, dict) or not isinstance(result.get("submissionId"), str):
        raise LeaderboardError("Invalid score submission response.")
    return result
