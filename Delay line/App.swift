import CoreMIDI
import SwiftUI

@main
final class App: SwiftUI.App {
    @ObservedObject private var model = Model()

    required init() {}

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
        }
    }
}
