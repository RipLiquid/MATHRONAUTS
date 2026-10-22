"""Load the original source verbatim, then install optional runtime callbacks."""
import argparse
import os
from pathlib import Path
import sys
import warnings
from types import ModuleType


ROOT = Path(__file__).resolve().parents[1]


class SilentSound:
    def play(self, *args, **kwargs): pass
    def stop(self): pass


class OptionalSounds:
    """Continue playing if a historical audio asset cannot be decoded."""
    def __init__(self, loader):
        self.loader = loader
        self.unavailable = {}

    def __getattr__(self, name):
        import pygame
        from pgzero.loaders import UnsupportedFormat
        if name in self.unavailable:
            return self.unavailable[name]
        try:
            return getattr(self.loader, name)
        except (AttributeError, pygame.error, UnsupportedFormat):
            warnings.warn(f"Sound '{name}' could not be decoded; continuing without that sound.")
            self.unavailable[name] = SilentSound()
            return self.unavailable[name]


def load_game(data_dir=None):
    from pgzero.runner import prepare_mod
    from pgzero.loaders import SoundLoader
    from .enhancements import EnhancedGame

    os.chdir(ROOT)
    # The original background is MP3. Pygame 2.6 supports it, while Pygame
    # Zero 1.2's resource lookup only lists WAV/OGG by default.
    if "mp3" not in SoundLoader.EXTNS:
        SoundLoader.EXTNS = SoundLoader.EXTNS + ["mp3"]
    # The historical game opens this file during initialization and expects a
    # nonempty list. Bootstrap it only when absent; never overwrite user scores.
    scores = ROOT / "scores_list"
    if not scores.exists():
        scores.write_text("0\n", encoding="utf-8")
    source = ROOT / "U11-Final CPT.py"
    module = ModuleType("mathronauts_original")
    module.__file__ = str(source)
    prepare_mod(module)
    module.sounds = OptionalSounds(module.sounds)
    previous_flag = getattr(sys, "_pgzrun", None)
    had_flag = hasattr(sys, "_pgzrun")
    # This is the same flag used by Pygame Zero's own runner: the base file's
    # pgzrun.go() returns so the extension can be installed before the game loop.
    sys._pgzrun = True
    try:
        exec(compile(source.read_text(encoding="utf-8"), str(source), "exec"), module.__dict__)
    finally:
        if had_flag: sys._pgzrun = previous_flag
        else: del sys._pgzrun
    runtime = EnhancedGame(module, Path(data_dir or ROOT / "local_data") / "progress.json")
    runtime.install()
    return module, runtime


def main():
    parser = argparse.ArgumentParser(description="Optional enhancements for the original MATHRONAUTS Pygame game")
    parser.add_argument("--data-dir", type=Path, help="Local progress directory (defaults to local_data)")
    parser.add_argument("--smoke-test", type=Path, metavar="OUTPUT_DIR", help="Run headless checks and save screenshots")
    args = parser.parse_args()
    if args.smoke_test:
        os.environ["SDL_VIDEODRIVER"] = "dummy"
        os.environ["SDL_AUDIODRIVER"] = "dummy"
        from .smoke import run_smoke
        run_smoke(args.smoke_test.resolve(), args.data_dir)
    else:
        from pgzero.runner import run_mod
        module, _ = load_game(args.data_dir)
        run_mod(module)
