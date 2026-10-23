"""Read-only live AWS check; run explicitly, never during normal gameplay."""
from .leaderboard import LeaderboardError, fetch_scores


def main():
    for difficulty in ("easy", "normal", "hard"):
        try:
            entries = fetch_scores(difficulty)
        except LeaderboardError as error:
            raise SystemExit(f"{difficulty}: live AWS check failed: {error}") from error
        print(f"{difficulty}: AWS connection and ranking response OK ({len(entries)} entries)")


if __name__ == "__main__":
    main()
