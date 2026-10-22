"""Offline rules and persistence; no Pygame imports, accounts or network calls."""
from dataclasses import dataclass, field, asdict
from enum import Enum
import json
from pathlib import Path
import random


OPERATIONS = ("Addition", "Subtraction", "Multiplication", "Division", "Mixed operations")


class Difficulty(str, Enum):
    EASY = "Easy"
    NORMAL = "Normal"
    HARD = "Hard"

    @property
    def limits(self):
        return {self.EASY: (10, 20, 5), self.NORMAL: (25, 50, 10), self.HARD: (50, 100, 12)}[self]

    @property
    def speed(self):
        return {self.EASY: 14, self.NORMAL: 20, self.HARD: 30}[self]


@dataclass(frozen=True)
class Settings:
    difficulty: Difficulty = Difficulty.NORMAL
    practice: bool = False
    operation: int = 0

    def __post_init__(self):
        if not isinstance(self.difficulty, Difficulty) or not 0 <= self.operation <= 4:
            raise ValueError("Invalid game settings")


@dataclass(frozen=True)
class Question:
    id: int
    first: int
    second: int
    operation: int
    answer: int
    choices: tuple

    @property
    def text(self):
        return f"{self.first} {('+', '-', 'x', '/')[self.operation]} {self.second} = ?"


def generate_question(stage, number, difficulty, rng):
    operation = rng.randrange(4) if stage == 4 else stage
    add, subtract, table = difficulty.limits
    if operation == 0:
        first, second = rng.randint(1, add), rng.randint(1, add)
        answer = first + second
    elif operation == 1:
        first = rng.randint(1, subtract)
        second = rng.randint(1, first)
        answer = first - second
    elif operation == 2:
        first, second = rng.randint(1, table), rng.randint(1, table)
        answer = first * second
    else:
        answer = rng.randint(1, table)
        second = rng.randint(1, answer)
        first = answer * second
    upper = subtract - 1 if stage <= 1 else table * table - 1
    choices = rng.sample([n for n in range(1, upper + 1) if n != answer], 3) + [answer]
    rng.shuffle(choices)
    return Question(number, first, second, operation, answer, tuple(choices))


class Session:
    def __init__(self, settings=Settings(), rng=None):
        self.settings = settings
        self.rng = rng or random.Random()
        self.score = self.attempts = self.correct = self.streak = self.best_streak = 0
        self.stage = self.completed = self.missed = 0
        self.lives = 3
        self.mistakes = []
        self.question = generate_question(settings.operation if settings.practice else 0, 1, settings.difficulty, self.rng)
        self.available = set(self.question.choices)

    @property
    def over(self):
        return self.attempts >= 10 if self.settings.practice else self.lives == 0

    @property
    def accuracy(self):
        return self.correct * 100 // self.attempts if self.attempts else 0

    def next_question(self):
        stage = self.settings.operation if self.settings.practice else self.stage
        self.question = generate_question(stage, self.question.id + 1, self.settings.difficulty, self.rng)
        self.available = set(self.question.choices)

    def submit(self, answer, question_id):
        if self.over or question_id != self.question.id or answer not in self.available:
            return False
        self.attempts += 1
        if answer == self.question.answer:
            self.score += 10
            self.correct += 1
            self.streak += 1
            self.best_streak = max(self.best_streak, self.streak)
            if not self.settings.practice:
                self.completed += 1
                if self.stage < 4 and self.completed >= (10, 10, 5, 5)[self.stage]:
                    self.stage += 1
                    self.completed = 0
            if not self.over:
                self.next_question()
        else:
            self.streak = 0
            self.mistakes.append((self.question.text, answer, self.question.answer))
            self.mistakes = self.mistakes[-20:]
            if self.settings.practice:
                if not self.over:
                    self.next_question()
            else:
                self.lives -= 1
                self.available.remove(answer)
        return True

    def expire(self, question_id):
        if self.settings.practice or self.over or question_id != self.question.id:
            return False
        self.lives -= 1
        self.missed += 1
        self.streak = 0
        if not self.over:
            self.next_question()
        return True


@dataclass
class ProgressStore:
    path: Path
    operations: dict = field(default_factory=dict)
    best_streak: int = 0
    practice_rounds: int = 0
    best_scores: dict = field(default_factory=dict)
    settings: Settings = Settings()

    @classmethod
    def load(cls, path):
        path = Path(path)
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
            operations = data.get("operations", {})
            for key, value in operations.items():
                if key not in OPERATIONS[:4] or not 0 <= value["correct"] <= value["attempts"]:
                    raise ValueError("Invalid progress")
            streak, rounds = data.get("best_streak", 0), data.get("practice_rounds", 0)
            best = data.get("best_scores", {})
            if streak < 0 or rounds < 0 or any(not isinstance(v, int) or v < 0 for v in best.values()):
                raise ValueError("Invalid totals")
            settings = data.get("settings", {})
            return cls(path, operations, streak, rounds, best,
                       Settings(Difficulty(settings.get("difficulty", "Normal")),
                                settings.get("practice", False), settings.get("operation", 0)))
        except (OSError, ValueError, TypeError, KeyError, AttributeError):
            return cls(path)

    def record(self, question, answer, session):
        key = OPERATIONS[question.operation]
        progress = self.operations.setdefault(key, {"attempts": 0, "correct": 0})
        progress["attempts"] += 1
        progress["correct"] += int(answer == question.answer)
        self.best_streak = max(self.best_streak, session.best_streak)
        if session.over and session.settings.practice:
            self.practice_rounds += 1
        if not session.settings.practice:
            difficulty = session.settings.difficulty.value
            self.best_scores[difficulty] = max(self.best_scores.get(difficulty, 0), session.score)

    def save(self):
        data = {"version": 1, "operations": self.operations, "best_streak": self.best_streak,
                "practice_rounds": self.practice_rounds, "best_scores": self.best_scores,
                "settings": asdict(self.settings)}
        self.path.parent.mkdir(parents=True, exist_ok=True)
        temporary = self.path.with_suffix(".tmp")
        temporary.write_text(json.dumps(data, indent=2), encoding="utf-8")
        temporary.replace(self.path)

    def reset_statistics(self):
        self.operations = {}
        self.best_streak = self.practice_rounds = 0
        self.save()
