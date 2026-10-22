# MATHRONAUTS mobile continuation

Updated October 22, 2026. Keep Python at root, iOS under mobile/ios and Android
under mobile/android on main. Use temporary feature branches and merge verified
work through pull requests. No separate repositories or store publication.

## User decisions

- Resume/GitHub portfolio extension in RipLiquid/MATHRONAUTS.
- Separate native iOS (SwiftUI/SpriteKit) and Android (Kotlin/Canvas) apps.
- Flutter was explicitly declined. VS Code is the editor; SDKs remain required.
- Deliver source, automated checks, build artifacts and documented demos.

## Original source baseline

Python source: U11-Final CPT.py at f5f355e. Original tests and artwork preserved.
Addition: operands 1...25. Subtraction: first 1...50, second 1...first.
Multiplication: operands 1...10. Division: answer 1...10, divisor 1...answer,
with their product as the dividend. Stages require 10/10/5/5 correct answers,
then indefinite mixed arithmetic. Three lives, +10 per correct hit. A wrong
meteor removes one life and itself, retaining the current question.
Four unique choices. The original expects a scores_list file absent from Git.

Mobile adaptations: portrait, vertical movement lane, direct target tapping,
one penalty per wave crossing the defense line, frozen wave during a shot.
Android adds accessible native answer buttons and a saved best score.

## Implementation and evidence

### iOS

mobile/ios contains the addition-only first slice, independent Swift package,
six XCTest cases, SwiftUI navigation and a SpriteKit battlefield. XcodeGen
creates the app project. Commits c2d9097 and f78dd0d were published; macOS tests
and simulator compilation passed:
https://github.com/RipLiquid/MATHRONAUTS/actions/runs/39798349576

No manual iOS simulator or physical-device playtest is established. Other math
operations, stage progression and saved scores remain future work on iOS.

### Android

mobile/android contains all five stages, Kotlin rules independent of Android,
native controls and Canvas rendering, best score persistence, saved-instance
state, projectile resolution, pause/resume and replay. Seven JUnit tests cover
question generation, scoring, lives, stale events, progression and restoration.
An API-35 emulator test covers launch, pause, activity recreation, resume and
return to menu, with screenshots. Inspect Native Android Actions for actual
results; no success is claimed before verification.

Verification checkpoint: Android's seven unit tests, lint, APK build and one
API-35 instrumentation test passed in run 39801957156. That run's overall status
was failure because screenshot collection occurred after app uninstall. The
workflow now keeps the test app installed until screenshots are copied. Verify
the follow-up run before merging. Physical-device gameplay checks remain open.

## Build commands

Android uses JDK 17, Gradle wrapper 8.11.1, AGP 8.9.2, Kotlin 2.1.20, Android
SDK 35/build-tools 35.0.0 and minimum SDK 26. From mobile/android on Windows:

    .\gradlew.bat testDebugUnitTest lintDebug assembleDebug
    .\gradlew.bat connectedDebugAndroidTest

The second command needs a booted emulator/device. No Android Studio editor is
required. APK installation and SDK setup are documented in android/README.md.

On a Mac, use swift test, xcodegen generate and the simulator build command in
ios/README.md. Windows cannot run SwiftUI or the iPhone Simulator. The iOS
artifact is a simulator .app, not an iPhone IPA. Android produces a debug APK.

## Remaining work

1. Resolve Android/integration CI failures and merge the verified apps into main.
2. Inspect emulator screenshots; playtest on an Android phone. Check correct and
   wrong shots, replay, stages, backgrounding mid-shot, insets and talkback.
3. Bring iOS to five-stage parity and persist scores; test on a Mac/iPhone.
4. Add audio, explosions and an expanded leaderboard if desired.
5. Document original asset provenance and add verified screenshots/demo video.
6. Write resume claims matching verified features and actual device checks.

Keep compilation, automated emulator tests and physical-device playtesting
separate in all reports. No store release work is required.
