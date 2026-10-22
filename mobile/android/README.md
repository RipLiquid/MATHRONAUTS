# MATHRONAUTS for Android

Native Kotlin app using Android `Canvas` for the battlefield and native widgets
for menus, status, pause/resume, and accessible answer buttons. The original
artwork is bundled directly from the repository's `images` folder. The Python
and iOS implementations remain separate.

## Play

Launch a mission. Drag in the left lane to move the spaceship. Tap an answer
meteor, or use an answer button, to fire. The answer resolves after the visible
shot reaches the target. The wave freezes during its 0.3-second shot; extra
shots are ignored while it resolves.

- Three lives, +10 points per correct answer.
- Wrong answers remove one life and that answer meteor; the question stays.
- A wave crossing the defense line costs one life and starts a new question.
- Progression: 10 addition, 10 subtraction, 5 multiplication, 5 division correct
  answers, then continuous mixed arithmetic. Division is exact and nonzero.
- Pause/resume, replay, return to menu, and a saved best score.
- Backgrounding pauses gameplay. Android saved-instance-state restoration keeps
  question, progress, lives, available choices and positions; an in-flight shot
  is cancelled on recreation without scoring. Explicitly resume to continue.

## Build and run in VS Code

Requirements: JDK **17**, Android command-line SDK with platform **35** and build
tools **35.0.0**, plus platform-tools (`adb`) to install. Android Studio's editor
is not required. Configure `JAVA_HOME` to the JDK and `ANDROID_HOME` to the SDK;
add their command-line tools to PATH. Run SDK tools and review/accept SDK
licenses during your local setup. Alternatively set `sdk.dir` in an untracked
`local.properties` file.

From the repository root in PowerShell:

```powershell
cd mobile/android
.\gradlew.bat testDebugUnitTest lintDebug assembleDebug
adb install -r app/build/outputs/apk/debug/app-debug.apk
adb shell am start -n com.ripliquid.mathronauts/.MainActivity
```

On macOS/Linux use `./gradlew` instead. Gradle **8.11.1**, Android Gradle Plugin
**8.9.2** and Kotlin **2.1.20** are pinned. The official wrapper JAR and distribution
have checksum verification. Minimum Android **8.0 / API 26**, target **API 35**.
The debug APK uses a development signing key automatically; no store account or
release keystore is required. Never commit local signing keys or SDK paths.

The GitHub **Native Android** workflow installs the toolchain, runs seven unit
tests, lint, APK compilation and an API-35 emulator navigation/recreation test.
The artifact includes the APK, reports and emulator screenshots on a successful
run. See [Native Android Actions](https://github.com/RipLiquid/MATHRONAUTS/actions/workflows/android-ci.yml) for actual results; a workflow's existence
alone does not mean its checks have passed.

## Architecture

- `core/GameSession.kt`: Android-independent arithmetic, progression, session
  state and once-only answer/wave events, with seeded random generation tests.
- `GameView.kt`: cached bitmaps, elapsed-time movement, inverse-scaled touch
  coordinates, bounded ship movement and a single projectile animation.
- `MainActivity.kt`: native controls, lifecycle/state restoration and local
  high-score persistence. Touch and native buttons call the same shot handler.

No networking permissions, backend, store integration, analytics or purchases.
Audio, explosion animations and a multi-entry leaderboard remain future work.
Physical-device playtesting and longer gameplay sessions are still required.
Asset provenance/licensing remains inherited from the original project and
has not been independently established.

References: [Android custom drawing](https://developer.android.com/develop/ui/views/layout/custom-views/custom-drawing),
[AGP compatibility](https://developer.android.com/build/releases/agp-8-9-0-release-notes),
[Gradle wrapper](https://docs.gradle.org/8.11.1/userguide/gradle_wrapper.html).
