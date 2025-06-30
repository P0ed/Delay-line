import CoreMIDI
import SwiftUI

let model = Model()

@main struct App: SwiftUI.App {
    var body: some Scene {
        WindowGroup {
			ContentView(model: model)
				.statusBarHidden()
				.persistentSystemOverlays(.hidden)
				.onAppear { UIApplication.shared.isIdleTimerDisabled = true }
				.onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        }
    }
}

struct ContentView: View {
	@ObservedObject var model: Model

	var body: some View {
		ZStack {
			switch model.state {
			case .success(let viewController):
				ViewControllerRepresentable(viewController: viewController)
					.ignoresSafeArea()
			case .failure(let error):
				VStack() { Text(error).padding() }
			}
		}
	}
}

struct ViewControllerRepresentable: UIViewControllerRepresentable {
	var viewController: UIViewController
	func makeUIViewController(context: Context) -> UIViewController { viewController }
	func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
