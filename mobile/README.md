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

Tests and simulator builds do not establish physical-device gameplay quality.
Record device checks and demo captures separately. Current platform scope differs:
Android supports all five stages; iOS currently supports addition only.
