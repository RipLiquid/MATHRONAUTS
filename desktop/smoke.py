"""Exercise real base actors, projectiles, menus, results and offline storage."""
import hashlib
from pathlib import Path
from tempfile import TemporaryDirectory

from .launcher import ROOT, load_game
from .learning import Difficulty, ProgressStore, Settings


def run_smoke(output_dir, data_dir=None):
    import pygame
    from pgzero.game import PGZeroGame

    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    original = ROOT / "U11-Final CPT.py"
    before = hashlib.sha256(original.read_bytes()).digest()
    with TemporaryDirectory(dir=output_dir) as temporary:
        module, runtime = load_game(data_dir or temporary)
        game = PGZeroGame(module)
        game.reinit_screen()
        def capture(name):
            runtime.draw()
            pygame.image.save(pygame.display.get_surface(), str(output_dir / f"{name}.png"))
        capture("menu")
        runtime.settings = Settings(Difficulty.EASY, True, 0)
        runtime.start()
        capture("practice")
        for index in range(10):
            expected = runtime.session.question
            # Check the real inherited shooting callback and projectile collisions,
            # including an incorrect answer retained in the review.
            answer = expected.answer if index != 3 else next(a for a in expected.choices if a != expected.answer)
            target = next(m for m in runtime.meteors if m.answer == answer)
            runtime.click(target.pos, module.mouse.LEFT)
            for _ in range(180):
                runtime.update(1 / 60)
                if runtime.session.question.id != expected.id or runtime.session.over:
                    break
            assert runtime.session.attempts == index + 1, "Projectile did not resolve an answer"
        assert runtime.state == "results"
        assert runtime.session.lives == 3
        assert runtime.session.correct == 9
        assert runtime.session.accuracy == 90
        assert len(runtime.session.mistakes) == 1
        capture("results")
        runtime.state = "stats"
        capture("statistics")
        restored = ProgressStore.load(runtime.progress.path)
        assert not runtime.storage_error, runtime.storage_error
        assert restored.operations["Addition"] == {"attempts": 10, "correct": 9}
        assert restored.practice_rounds == 1
        runtime.action("reset")
        assert runtime.state == "confirm_reset"
        runtime.action("confirm")
        assert runtime.progress.operations == {}
        assert hashlib.sha256(original.read_bytes()).digest() == before, "Original source changed"
        print("Desktop smoke passed: unchanged base, real projectiles, 10-question results, local persistence and reset.")
        pygame.quit()
