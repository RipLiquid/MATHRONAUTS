"""Pygame Zero extension installed only by the optional enhanced launcher."""
from dataclasses import replace

from .learning import Difficulty, OPERATIONS, ProgressStore, Session


class EnhancedGame:
    def __init__(self, base, data_path):
        self.base = base
        self.progress = ProgressStore.load(data_path)
        self.settings = self.progress.settings
        self.session = None
        self.state = "menu"
        self.buttons = []
        self.meteors = []
        self.wave_id = None
        self.message = ""
        self.review_page = 0
        self.storage_error = ""
        self.original_shoot = base.on_mouse_down
        base.sounds.background_music.stop()
        base.clock.unschedule(base.start_game)

    def install(self):
        # Explicit callback signatures preserve Pygame Zero's event dispatch.
        def draw(): self.draw()
        def update(dt): self.update(dt)
        def on_mouse_move(pos): self.base.ship.angle = self.base.ship.angle_to(pos)
        def on_mouse_down(pos, button): self.click(pos, button)
        def on_key_down(key): self.key(key)
        self.base.draw = draw
        self.base.update = update
        self.base.on_mouse_move = on_mouse_move
        self.base.on_mouse_down = on_mouse_down
        self.base.on_key_down = on_key_down

    def save(self):
        try:
            self.progress.settings = self.settings
            self.progress.save()
            self.storage_error = ""
        except OSError:
            self.storage_error = "Progress could not be saved. Check that this folder is writable."

    def start(self):
        self.session = Session(self.settings)
        self.state = "playing"
        self.message = "Take your time!" if self.settings.practice else "Protect the mothership!"
        self.base.ship.pos = (170, 370)
        self.base.ship.angle = 0
        self.base.bullet_delay = 0
        self.base.bullets.clear()
        self.wave_id = None
        self.sync_wave()
        self.save()
        self.base.sounds.background_music.play(-1)

    def sync_wave(self):
        session = self.session
        if session.question.id != self.wave_id:
            self.wave_id = session.question.id
            self.base.bullets.clear()
            self.meteors = []
            for index, answer in enumerate(session.question.choices):
                meteor = self.base.Actor(f"meteor{index + 1}", (1080, 150 + index * 145))
                meteor.answer = answer
                self.meteors.append(meteor)
        self.meteors = [m for m in self.meteors if m.answer in session.available]
        self.base.current_meteors = self.meteors
        if session.over:
            self.state = "results"
            self.review_page = 0
            self.base.bullets.clear()
            self.base.sounds.background_music.stop()

    def submit(self, answer, question_id):
        previous = self.session.question
        if not self.session.submit(answer, question_id):
            return False
        self.progress.record(previous, answer, self.session)
        self.save()
        correct = answer == previous.answer
        self.message = "Correct! +10" if correct else f"Your answer: {answer}. Correct answer: {previous.answer}."
        self.base.sounds.meteor_explosion.play()
        if not correct and not self.settings.practice:
            self.base.sounds.heart_lost.play()
        self.sync_wave()
        return True

    def update(self, dt):
        if self.state != "playing":
            return
        dt = min(max(dt, 0), 0.05)
        base = self.base
        if base.keyboard.w: base.ship.y -= 300 * dt
        if base.keyboard.s: base.ship.y += 300 * dt
        if base.keyboard.a: base.ship.x -= 300 * dt
        if base.keyboard.d: base.ship.x += 300 * dt
        base.ship.x = min(max(base.ship.x, 170), 200)
        base.ship.y = min(max(base.ship.y, 85), 650)
        base.bullet_delay = max(0, base.bullet_delay - 60 * dt)
        if not self.settings.practice:
            for meteor in self.meteors:
                meteor.x -= self.settings.difficulty.speed * (1200 / 390) * dt
            if any(m.x < 100 for m in self.meteors):
                self.session.expire(self.wave_id)
                self.message = "Wave reached the defense line. One life lost."
                self.sync_wave()
                if self.session.over:
                    return
        for bullet in list(base.bullets):
            if bullet not in base.bullets:
                continue
            bullet.move_forward(900 * dt)
            hit = bullet.collidelist(self.meteors)
            if hit != -1:
                answer = self.meteors[hit].answer
                base.bullets.remove(bullet)
                self.submit(answer, bullet.question_id)
            elif not (-50 <= bullet.x <= 1250 and -50 <= bullet.y <= 850):
                base.bullets.remove(bullet)

    def key(self, key):
        if key == self.base.keys.P and self.state in ("playing", "paused"):
            self.state = "paused" if self.state == "playing" else "playing"
        if key == self.base.keys.ESCAPE:
            self.state = "menu"
            self.base.sounds.background_music.stop()

    def click(self, pos, button):
        if button != self.base.mouse.LEFT:
            return
        for rect, action in reversed(self.buttons):
            if rect.collidepoint(pos):
                self.action(action)
                return
        if self.state == "playing":
            before = len(self.base.bullets)
            self.base.ship.angle = self.base.ship.angle_to(pos)
            self.original_shoot(button)
            if len(self.base.bullets) > before:
                self.base.bullets[-1].question_id = self.session.question.id

    def action(self, action):
        if action == "start": self.start()
        elif action == "menu":
            self.state = "menu"
            self.base.sounds.background_music.stop()
        elif action == "stats": self.state = "stats"
        elif action == "reset": self.state = "confirm_reset"
        elif action == "confirm":
            self.progress.operations = {}
            self.progress.best_streak = self.progress.practice_rounds = 0
            self.save()
            self.state = "stats"
        elif action == "pause": self.state = "paused"
        elif action == "resume": self.state = "playing"
        elif action == "next": self.review_page += 1
        elif action == "previous": self.review_page = max(0, self.review_page - 1)
        elif action == "quit": raise SystemExit
        elif action.startswith("difficulty:"):
            self.settings = replace(self.settings, difficulty=Difficulty(action.split(":")[1])); self.save()
        elif action.startswith("mode:"):
            self.settings = replace(self.settings, practice=action.endswith("Practice")); self.save()
        elif action.startswith("operation:"):
            self.settings = replace(self.settings, operation=int(action.split(":")[1])); self.save()

    def button(self, label, rect, action, selected=False):
        rect = self.base.Rect(rect)
        screen = self.base.screen
        screen.draw.filled_rect(rect, (32, 105, 140) if selected else (34, 43, 66))
        screen.draw.rect(rect, (100, 210, 235))
        screen.draw.text(label, center=rect.center, fontsize=27, color="white")
        self.buttons.append((rect, action))

    def text(self, text, y, size=30, color="white"):
        self.base.screen.draw.text(text, center=(600, y), fontsize=size, color=color)

    def draw(self):
        screen = self.base.screen
        screen.fill((8, 13, 32))
        self.buttons = []
        if self.state in ("playing", "paused"):
            self.draw_game()
            if self.state == "paused":
                screen.draw.filled_rect(self.base.Rect(310, 240, 580, 300), (8, 13, 32))
                self.text("Paused", 290, 52)
                self.button("Resume", (390, 350, 420, 55), "resume")
                self.button("Main menu", (390, 430, 420, 55), "menu")
            return
        if self.state == "menu":
            self.text("MATHRONAUTS", 85, 64)
            self.text("Arcade missions and offline math practice", 130, 25)
            for index, difficulty in enumerate(Difficulty):
                self.button(difficulty.value, (270 + index * 230, 185, 200, 52),
                            "difficulty:" + difficulty.value, self.settings.difficulty == difficulty)
            for index, mode in enumerate(("Arcade", "Practice")):
                self.button(mode, (380 + index * 230, 265, 210, 52), "mode:" + mode,
                            self.settings.practice == (mode == "Practice"))
            if self.settings.practice:
                for index, operation in enumerate(OPERATIONS):
                    self.button(operation, (30 + index * 235, 345, 210, 50),
                                f"operation:{index}", self.settings.operation == index)
                self.text("10 questions - untimed - no life loss", 430, 28)
            else:
                best = self.progress.best_scores.get(self.settings.difficulty.value, 0)
                self.text(f"3 lives - five stages - {self.settings.difficulty.value} best: {best}", 390)
            self.button("Start practice" if self.settings.practice else "Launch mission", (430, 475, 340, 56), "start")
            self.button("Learning statistics", (430, 555, 340, 56), "stats")
            self.button("Quit", (430, 635, 340, 56), "quit")
            self.text("WASD: move | Mouse: aim | Click: fire | P: pause | Esc: menu", 745, 24)
        elif self.state == "stats":
            self.text("Learning statistics", 80, 54)
            attempts = sum(p["attempts"] for p in self.progress.operations.values())
            correct = sum(p["correct"] for p in self.progress.operations.values())
            accuracy = correct * 100 // attempts if attempts else 0
            self.text(f"{correct}/{attempts} correct - {accuracy}% accuracy", 145)
            self.text(f"Best streak {self.progress.best_streak} - Practice rounds {self.progress.practice_rounds}", 190)
            for index, operation in enumerate(OPERATIONS[:4]):
                progress = self.progress.operations.get(operation, {"attempts": 0, "correct": 0})
                percent = progress["correct"] * 100 // progress["attempts"] if progress["attempts"] else 0
                y = 260 + index * 80
                self.text(f"{operation}: {progress['correct']}/{progress['attempts']} ({percent}%)", y, 26)
                screen.draw.filled_rect(self.base.Rect(300, y + 24, 600, 12), (34, 43, 66))
                if percent: screen.draw.filled_rect(self.base.Rect(300, y + 24, percent * 6, 12), (80, 200, 225))
            self.button("Main menu", (340, 650, 240, 55), "menu")
            self.button("Reset statistics", (620, 650, 240, 55), "reset")
            self.text("Saved only on this computer. No cloud service or account.", 745, 24)
        elif self.state == "confirm_reset":
            self.text("Reset learning statistics?", 280, 48)
            self.text("Arcade best scores stay saved.", 350)
            self.button("Cancel", (340, 440, 240, 60), "stats")
            self.button("Reset", (620, 440, 240, 60), "confirm")
        else:
            session = self.session
            self.text("Practice complete" if self.settings.practice else "Mission over", 75, 55)
            self.text(f"{session.correct}/{session.attempts} correct - {session.accuracy}% accuracy", 140)
            self.text(f"Score {session.score} - Best streak {session.best_streak} - Missed waves {session.missed}", 185, 28)
            self.text("Answer review", 245, 34)
            if not session.mistakes: self.text("No incorrect answers to review.", 320)
            for index, (question, submitted, correct) in enumerate(session.mistakes[self.review_page * 6:(self.review_page + 1) * 6]):
                self.text(f"{question}   Your answer: {submitted}   Correct: {correct}", 295 + index * 46, 27)
            if self.review_page > 0: self.button("Previous", (280, 575, 220, 50), "previous")
            if len(session.mistakes) > (self.review_page + 1) * 6: self.button("Next", (700, 575, 220, 50), "next")
            self.button("Play again", (200, 665, 240, 60), "start")
            self.button("Statistics", (480, 665, 240, 60), "stats")
            self.button("Main menu", (760, 665, 240, 60), "menu")
        if self.storage_error: self.text(self.storage_error, 780, 22, "orange")

    def draw_game(self):
        base, session = self.base, self.session
        base.screen.blit(base.background, (0, 0))
        base.mothership.draw()
        base.ship.draw()
        for meteor in self.meteors:
            meteor.draw()
            base.screen.draw.text(str(meteor.answer), center=meteor.pos, fontsize=35, color="white", owidth=1, ocolor="black")
        for bullet in base.bullets: bullet.draw()
        info = f"Question {min(session.attempts + 1, 10)}/10 - Untimed" if self.settings.practice else f"Lives {session.lives}"
        stage = self.settings.operation if self.settings.practice else session.stage
        base.screen.draw.text(f"{OPERATIONS[stage]} - {self.settings.difficulty.value} - Score {session.score} - {info}",
                              (30, 25), fontsize=30, color="white")
        self.text(session.question.text, 710, 48)
        self.text(self.message, 765, 26)
        self.button("Pause", (990, 20, 95, 45), "pause")
        self.button("Menu", (1095, 20, 85, 45), "menu")
