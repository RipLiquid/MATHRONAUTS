"""Optional online screens layered over the enhanced desktop game."""
from queue import Empty, Queue
from threading import Thread

from .enhancements import EnhancedGame
from .leaderboard import LeaderboardError, fetch_scores, submit_score


class OnlineGame(EnhancedGame):
    def __init__(self, base, data_path):
        super().__init__(base, data_path)
        self.online_results = Queue()
        self.online_busy = False
        self.online_message = ""
        self.online_entries = []
        self.online_difficulty = "Normal"
        self.nickname = ""
        self.submission_attempted = False

    def start(self):
        self.submission_attempted = False
        self.online_message = ""
        super().start()

    def request_online(self, kind, function, *args):
        if self.online_busy:
            return
        self.online_busy = True
        self.online_message = "Connecting..."

        def work():
            try:
                result = function(*args)
                self.online_results.put((kind, result, None))
            except LeaderboardError as error:
                self.online_results.put((kind, None, str(error)))
            except Exception:
                self.online_results.put((
                    kind, None, "Leaderboard temporarily unavailable."
                ))

        Thread(target=work, daemon=True).start()

    def update(self, dt):
        try:
            kind, result, error = self.online_results.get_nowait()
        except Empty:
            pass
        else:
            self.online_busy = False
            if error:
                self.online_message = error
            elif kind == "fetch":
                self.online_entries = result
                self.online_message = (
                    "" if result else "No scores yet."
                )
            else:
                self.online_message = "Score submitted!"

        super().update(dt)

    def action(self, action):
        if action == "online":
            if self.online_busy:
                return
            self.online_difficulty = self.settings.difficulty.value
            self.online_entries = []
            self.state = "online"
            self.request_online(
                "fetch", fetch_scores, self.online_difficulty
            )
            return

        if action == "enter_nickname":
            if self.online_busy or self.submission_attempted:
                return
            if (
                self.state != "results"
                or self.session is None
                or self.session.settings.practice
                or not self.session.over
            ):
                return
            self.online_message = ""
            self.state = "nickname"
            return

        if action == "send_score":
            if self.online_busy or self.submission_attempted:
                return
            if (
                self.state != "nickname"
                or self.session is None
                or self.session.settings.practice
                or not self.session.over
            ):
                return
            if len(self.nickname) < 3:
                self.online_message = "Enter at least 3 characters."
                return
            # One attempt per round avoids duplicate submissions on retries.
            self.submission_attempted = True
            self.state = "results"
            self.request_online(
                "submit",
                submit_score,
                self.nickname,
                self.session.settings.difficulty.value,
                self.session.score
            )
            return

        if action == "back_results":
            self.state = "results"
            return

        super().action(action)

    def key(self, key):
        if self.state == "nickname":
            if key == self.base.keys.ESCAPE:
                self.state = "results"
            elif key == self.base.keys.BACKSPACE:
                self.nickname = self.nickname[:-1]
            elif key == self.base.keys.RETURN:
                self.action("send_score")
            elif len(self.nickname) < 16:
                code = int(key)
                if 97 <= code <= 122 or 48 <= code <= 57:
                    self.nickname += chr(code)
            return

        super().key(key)

    def draw(self):
        if self.state == "online":
            self.base.screen.fill((8, 13, 32))
            self.buttons = []
            self.text(
                f"{self.online_difficulty} online leaderboard", 70, 48
            )

            for index, entry in enumerate(self.online_entries[:10]):
                self.text(
                    f"{index + 1}. {entry['nickname']} - {entry['score']}",
                    180 + index * 43,
                    29
                )

            self.text(self.online_message, 645, 25)
            self.button("Refresh", (340, 700, 240, 55), "online")
            self.button("Main menu", (620, 700, 240, 55), "menu")
            return

        if self.state == "nickname":
            self.base.screen.fill((8, 13, 32))
            self.buttons = []
            self.text("Submit Arcade score", 160, 48)
            self.text(f"Score: {self.session.score}", 230, 34)
            self.text("Type a nickname: 3-16 letters or numbers", 300, 28)
            self.text(self.nickname + "_", 370, 44)
            self.text(self.online_message, 540, 25)
            self.button("Submit", (340, 620, 240, 55), "send_score")
            self.button("Cancel", (620, 620, 240, 55), "back_results")
            return

        super().draw()

        if self.state == "menu":
            self.button(
                "Online leaderboard", (870, 25, 300, 50), "online"
            )

        if self.state == "results" and not self.session.settings.practice:
            if not self.submission_attempted and not self.online_busy:
                self.button(
                    "Submit score", (900, 25, 270, 50), "enter_nickname"
                )
            self.text(self.online_message, 625, 24)
