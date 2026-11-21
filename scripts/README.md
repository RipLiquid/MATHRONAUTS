# Windows setup and play

Players double-click **Play-MATHRONAUTS.cmd**. That is the only file a player
needs to start with. It also works inside an extracted repository ZIP.

Requires Windows 10/11 on a 64-bit Intel/AMD PC. First-time setup requires an
internet connection. No Git, VS Code, PowerShell 7, manually installed pip,
virtual-environment activation or administrator launch is required under normal
per-user installation conditions. Windows or organization policy may still ask
the user to approve running a downloaded file or may prevent installation.

## What it does

1. Uses the game beside the launcher, or downloads the published `main` ZIP
   from the official MATHRONAUTS GitHub repository and caches its desktop files.
2. Reuses an available Python 3.12. If none is found, downloads the official
   Python 3.12.10 64-bit Windows installer, checks its pinned SHA-256 and its
   Python Software Foundation Authenticode signature, then installs it for the
   current user with pip. It does not modify PATH or install a global launcher.
3. Creates a private environment, separate from developers' existing `.venv`.
4. Installs the pinned desktop requirements, including the correct Actor helper
   from the same pinned GitHub revision using a ZIP instead of a Git dependency.
5. Starts the enhanced game with local progress in a separate persistent folder.

Python 3.12.10 is used because it is the final 3.12 release with the official
traditional Windows binary installer. Later 3.12 security releases are source
only. See [Python's release page](https://www.python.org/downloads/release/python-31210/)
and [Windows installation options](https://docs.python.org/3.12/using/windows.html).
An already installed Python 3.12 patch version is reused. The script does not
claim to provide the latest Python security release.

Downloaded game files, private environments, logs and progress live under
`%LOCALAPPDATA%\MATHRONAUTS`. Repeat runs validate and reuse a completed setup
without contacting pip or downloading the game again; normal play then works
offline. Opening the online leaderboard still requires a connection.

The standalone cached game is the published `main` snapshot at its first run;
it does not auto-update or overwrite a developer checkout. To update it, close
the game and rename `%LOCALAPPDATA%\MATHRONAUTS\app` to `app-backup` before
running the launcher again. Progress is stored separately in `progress` and is
preserved. A launcher beside a full source checkout always uses that checkout.
Existing progress in a developer checkout's `local_data` is not moved; direct
`python MATHRONAUTS.py` continues using it, while the one-click launcher uses
its own persistent progress folder.

Failures keep the window open when double-clicked and report the log path in
`%LOCALAPPDATA%\MATHRONAUTS\logs`. A failed setup can be run again. No folders
are recursively deleted. An incomplete cached game is preserved with recovery
instructions. The original Python game and its sprites, fonts and audio are
not edited. Windows may require a restart if its installer reports one.

## Development and verification

The maintainable source is `scripts/setup-and-play.ps1`. The `.cmd` contains a
generated copy of it, so players do not need a second script or a permanent
PowerShell execution-policy change. The wrapper uses a process-only policy
override for its embedded script. Do not hand-edit the generated `.cmd`.

```powershell
python scripts/build_launcher.py
python scripts/build_launcher.py --check
python -m pytest tests/test_bootstrap.py -v
.\Play-MATHRONAUTS.cmd --smoke-test
```

`--setup-only` prepares the environment without opening a game window.
`--smoke-test` runs actual headless projectile/Practice checks, writes screenshots
to `smoke-test`, and keeps test progress separate from player progress.
For isolated testing, set `MATHRONAUTS_HOME` to a short writable folder first;
very long environment paths can exceed Windows package-installation limits.

The Windows CI job checks source generation, built-in PowerShell 5.1 parsing,
existing/missing-runtime branches, installer verification order, local versus
standalone game discovery, paths with spaces, repeat-run caching and failure
recovery. Installer execution is simulated in those branch tests so it cannot
replace the runner's registered Python. CI also installs real requirements in
a fresh private environment and exercises the `.cmd` through both local-source
and standalone-download smoke runs. This does not replace clean-PC installer
or manual keyboard, mouse and audio testing.
