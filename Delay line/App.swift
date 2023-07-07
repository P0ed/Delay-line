import CoreMIDI
import SwiftUI

@main
final class App: SwiftUI.App {
    @ObservedObject var model = Model()

    required init() {}

    var body: some Scene {
        WindowGroup {
			ContentView(model: model)
				.onAppear { UIApplication.shared.isIdleTimerDisabled = true }
				.onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        }
    }
}

struct ContentView: View {
	@ObservedObject var model: Model

	var body: some View {
		switch model.state {
		case .success(let viewController):
			ViewControllerRepresentable(
				viewController: viewController
			)
		case .failure(let error):
			VStack() {
				Text(error).padding()
			}
			.frame(minWidth: 400, minHeight: 200)
		}
	}
}

struct ViewControllerRepresentable: UIViewControllerRepresentable {
	var viewController: UIViewController
	func makeUIViewController(context: Context) -> UIViewController { viewController }
	func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
