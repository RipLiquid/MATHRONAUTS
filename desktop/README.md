# Optional enhanced Pygame launcher

`U11-Final CPT.py` remains the original base game, unchanged. New functionality
is kept in separate files and enabled only when running `MATHRONAUTS.py`.

```powershell
python -m pip install -r requirements-desktop.txt
python MATHRONAUTS.py
```

The main menu offers Easy/Normal/Hard, Arcade/Practice and operation selection.
WASD moves the ship, the mouse aims, left click fires, P pauses and Esc returns
to the menu. Arcade has three lives and five stages; Practice has ten untimed
questions with no life loss. Results include accuracy, best streak and mistake
review. Statistics show accuracy bars by operation and completed Practice rounds.
Scores are separated by difficulty; statistics include accepted answers from
both modes. Missed waves are counted separately. Review keeps the last 20
Arcade mistakes and all ten Practice mistakes.

## How the extension relates to the base

The launcher executes the original source without editing it, using Pygame
Zero's runner setup. It retains the original actors, assets and shooting
callback, then installs enhanced draw/update/input callbacks in memory before
the game loop starts. New settings, arithmetic rules, results and persistence
live in `desktop/learning.py` and `desktop/enhancements.py`. Future changes to
base callback signatures may require corresponding adapter updates.

Run `python "U11-Final CPT.py"` for the historical game without the extension.
Its historical file/audio assumptions still apply. The enhanced launcher
creates `scores_list` containing `0` only when missing, because the original
initialization expects it. Existing score files are never replaced. New
progress goes to ignored `local_data/progress.json`; it does not alter legacy
scores. Use `--data-dir PATH` to choose a different local progress folder.

The compatible Actor helper is pinned to QuirkyCort/pgzhelper in the requirements
file. The unrelated similarly named PyPI package lacks the original movement
extensions. Dependencies are installed, not copied into the repository.
The supplied `background_music.mp3` has an MP4 container signature and cannot be
decoded by the tested Pygame build. The enhanced launcher skips undecodable
sounds; valid WAV sound effects still play. Source and assets are left intact.

## Local data and tests

Settings, accuracy by operation, best streak, completed Practice rounds and
difficulty-specific Arcade best scores are stored on this computer. Resetting
statistics requires confirmation and leaves best scores intact. Active rounds
start fresh after relaunch. These learning features stay offline; the optional
leaderboard is the only feature that contacts AWS.

```powershell
python -m pip install pytest
python -m pytest tests/ -v
python MATHRONAUTS.py --smoke-test desktop-test-artifacts
```

The smoke check uses dummy display/audio drivers, loads the actual original
module, exercises real projectile collisions through ten Practice questions,
verifies persistence/reset, compares the original file hash before and after,
and saves menu/game/results/statistics screenshots. It does not substitute for
manual desktop input and audio playtesting. Difficulty ranges match the
[mobile guide](../mobile/README.md); desktop wave speed scales to its 1200-wide
playfield and projectiles use physical collision checks.

## Optional AWS leaderboard

Choose **Online leaderboard** on the main menu to read the top ten scores for
its selected difficulty. Complete an Arcade round, choose **Submit score** and
enter a nickname of 3–16 letters or digits. The typing field supports lower-case
letters, digits, Backspace, Enter to submit and Esc to cancel. No submission is
made automatically. Practice rounds cannot be submitted.

`desktop/online.py` adds the screens over `EnhancedGame`, while
`desktop/leaderboard.py` handles HTTPS requests using Python's standard library.
Workers send results through a queue so the game loop stays responsive. Requests
have a five-second network timeout; failures show an availability message.
There is one submission attempt per Arcade round and no automatic retry, since
a timed-out write may already have reached the server. Rankings keep separate
round entries, including repeated nicknames. Nicknames last only for the current
app session; they are not accounts. Gameplay and local saves do not depend on AWS.

The client sends nickname, difficulty and score only on submission. The handler
adds a server timestamp. This demo accepts client-reported scores; the UI's
one-attempt safeguard is not server-side anti-cheat or rate limiting. Android
and iOS still use their existing offline features. The preserved original source
and assets are unchanged. See [AWS setup and API](../aws/leaderboard/README.md).

### Live connection check

```powershell
python -m desktop.check_leaderboard
```

This makes GET requests for Easy, Normal and Hard and checks response fields,
ordering and the ten-score limit. It uses the same endpoint and client as the
game, needs no AWS keys, and never writes scores. CI runs it separately from the
offline suite, which tests successful requests, rejected requests, invalid data,
connection failures and UI transitions using simulated responses. A live check
failure can indicate an AWS or network outage rather than a gameplay regression.
