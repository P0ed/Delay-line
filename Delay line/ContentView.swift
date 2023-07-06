import AudioToolbox
import SwiftUI

struct ContentView: View {
    @ObservedObject var model: Model

    var body: some View {
		switch model.state {
		case .success(let viewController)?:
			ViewControllerRepresentable(viewController: viewController)
		case .failure(let error):
			message(error)
		case .none:
			message("No Audio Unit loaded..")
		}
    }

	private func message(_ text: String) -> some View {
		VStack() {
			Text(text).padding()
		}
		.frame(minWidth: 400, minHeight: 200)
	}
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(model: Model())
    }
}

struct ViewControllerRepresentable: UIViewControllerRepresentable {
	var viewController: UIViewController

	func makeUIViewController(context: Context) -> UIViewController { viewController }
	func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
