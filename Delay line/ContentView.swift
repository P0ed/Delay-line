import AudioToolbox
import SwiftUI

struct ContentView: View {
    @ObservedObject var hostModel: AudioUnitHostModel

    var body: some View {
		if let viewController = hostModel.viewModel.viewController {
			ViewControllerRepresentable(viewController: viewController)
		} else {
			VStack() {
				Text(hostModel.viewModel.message)
					.padding()
			}
			.frame(minWidth: 400, minHeight: 200)
		}
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(hostModel: AudioUnitHostModel())
    }
}

struct ViewControllerRepresentable: UIViewControllerRepresentable {
	var viewController: UIViewController

	func makeUIViewController(context: Context) -> UIViewController { viewController }
	func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
