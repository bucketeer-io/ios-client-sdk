import SwiftUI
import Bucketeer

@main
struct ExampleSwiftUIApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .enableBKTBackgroundTask()
    }
}
