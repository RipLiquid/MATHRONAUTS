# Native mobile versions

Both apps extend the Python original in this repository. Platform folders stay
on `main`; feature branches are temporary work areas and merge through pull
requests after checks pass. There is no separate app repository and no store
release requirement.

| Platform | Code | Build | Run |
| --- | --- | --- | --- |
| [iOS](ios/README.md) | SwiftUI + SpriteKit | macOS / Xcode SDK, locally or GitHub Actions | iPhone Simulator on a Mac |
| [Android](android/README.md) | Kotlin + native Canvas | Windows/macOS/Linux with JDK 17 + Android SDK, or Actions | Android phone or emulator |

VS Code is sufficient as the editor. The platform SDKs and command-line tools
are additional build requirements. Native iOS cannot run on Windows.

## Get the apps from GitHub

1. Open the repository's **Actions** tab.
2. Choose a successful **Native Android** or **Native iOS** run.
3. Download its artifact (GitHub sign-in may be required).
4. Android: extract `app-debug.apk`, then install it using `adb install -r` or
   transfer it to your phone and allow installation from that source.
5. iOS: the artifact is a simulator `.app`, not an IPA for an iPhone. Use a Mac
   and the simulator commands in the iOS README.

## Difficulty and offline practice

Both apps support five-stage Arcade and ten-question Practice. Select a
difficulty before starting. Arcade best scores are separated by difficulty.

| Difficulty | Addition operands | Subtraction first operand | Multiplication/division table | Arcade wave speed |
| --- | --- | --- | --- | --- |
| Easy | 1–10 | 1–20 | 1–5 | 7 scene units/second |
| Normal | 1–25 | 1–50 | 1–10 | 10 scene units/second |
| Hard | 1–50 | 1–100 | 1–12 | 15 scene units/second |

Subtraction stays nonnegative. Division uses a nonzero divisor and exact whole
answers; the table limit applies to the answer and divisor, so the dividend can
be larger. Normal preserves the original Python operand ranges.

Practice lets you choose one operation or mixed questions. Meteors stay still,
there is no timer or life loss, and every answer advances the round. Results
show accuracy, best streak and the correct solutions to mistakes. Arcade keeps
the original 10/10/5/5 stage limits and continuous mixed questions.

Learning statistics show answered attempts, accuracy by operation, best streak
and completed practice rounds across both modes. Missed Arcade waves are shown
separately in session results and do not count as answered attempts. Accuracy
percentages are rounded down. Charts compare operations; they are not a daily
history. Reset statistics requires confirmation and leaves Arcade best scores.
Arcade answer review keeps the last 20 mistakes; Practice keeps all ten.

Everything is saved locally with no backend, account or cloud hosting bill.
Progress does not synchronize between devices; deleting the app can remove its
local data. Statistics are saved after each accepted answer, including partial
rounds. Android restores an active round after activity recreation; iOS saves
settings, aggregate statistics and best scores but starts fresh after relaunch.

Tests and simulator builds do not establish physical-device gameplay quality.
Record device checks and demo captures separately.
