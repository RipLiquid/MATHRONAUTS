# MATHRONAUTS for iPhone

Native Swift / SwiftUI / SpriteKit addition prototype, extending the original
Python project. Developed as a GitHub portfolio project, with VS Code as the
editor. No store publication is planned.

## Current scope

- Menu, four moving answer meteors, original background/ship/meteor artwork.
- Drag in the left lane to move; tap a meteor to fire a visible projectile.
- Answer resolves at impact. Further taps are ignored until the shot finishes.
- Correct answer: +10 points and a new question. Wrong answer: -1 life and
  removal of the selected meteor; the current question remains.
- Three lives; game over, replay, pause, and main menu.
- A wave reaching the defense line costs one life and starts a new question.
- App backgrounding pauses the scene; explicitly resume after returning.
- Independent Swift package for rules, with deterministic generator tests.

This is the first vertical slice. Other operations, progression, saved high
scores, audio, explosion animations, app icons, and accessibility of individual
SpriteKit targets remain future work. Manual simulator/device validation is
still required, including layout, touch interaction and sprite orientation.

## Work in VS Code on Windows

Open the **repository root** in VS Code. Install its recommended Swift extension
for source editing; the extension does not install Apple's iOS SDK on Windows.
SwiftUI/SpriteKit compilation and the iPhone Simulator require macOS/Xcode.
You can edit and push from Windows and inspect the **Native iOS** workflow on
GitHub. No paid Apple membership or signing credentials are needed for this
unsigned simulator build.

The workflow runs core tests, generates the Xcode project from `project.yml`,
and compiles a simulator app. Its artifact runs on an iOS Simulator on a Mac;
it is not an iPhone-installable IPA, Windows executable, or browser demo.
See [Native iOS Actions](https://github.com/RipLiquid/MATHRONAUTS/actions/workflows/ios-ci.yml) for build and test results.

## Build on a Mac, still using VS Code

Prerequisites: Xcode and its command-line tools, iOS platform support, Swift
5.9 or later, and XcodeGen (`brew install xcodegen`).

```sh
cd mobile/ios
swift test
xcodegen generate
xcodebuild build -project Mathronauts.xcodeproj -scheme Mathronauts \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO
```

The deployment target is iOS 16.0, iPhone portrait. These are initial prototype
defaults. `com.ripliquid.Mathronauts` is a development bundle identifier, not a
registered distribution identity. Signing is disabled for simulator CI.

To install the resulting app on a booted simulator from VS Code's Mac terminal:

```sh
xcrun simctl install booted DerivedData/Build/Products/Debug-iphonesimulator/Mathronauts.app
xcrun simctl launch booted com.ripliquid.Mathronauts
```

The generated `.xcodeproj` is ignored; `project.yml` is the source of truth.
Original image files are referenced directly as bundle resources, not copied.
Original authorship is preserved in the root README. Asset licensing/provenance
was not established by this implementation; document it before broader reuse.

## Structure

- `App/`: SwiftUI menu/HUD, stable scene controller, SpriteKit rendering/input.
- `Sources/MathronautsCore/`: arithmetic and session rules without UI dependencies.
- `Tests/MathronautsCoreTests/`: generator bounds/uniqueness, score/life changes,
  stale event rejection, game over and reset.
- `project.yml`: app target, shared scheme, resources and local package dependency.
- `../../.github/workflows/ios-ci.yml`: macOS test/build workflow.

Sources: [Apple SpriteView](https://developer.apple.com/documentation/spritekit/spriteview),
[XcodeGen](https://github.com/yonaskolb/XcodeGen).
