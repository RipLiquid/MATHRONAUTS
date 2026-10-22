import SwiftUI

@main
struct MathronautsApp: App {
    init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing-reset"),
           let bundle = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundle)
        }
        #endif
    }
    var body: some Scene {
        WindowGroup { ContentView().preferredColorScheme(.dark) }
    }
}
