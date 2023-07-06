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

struct AnyUIView<View: UIView>: UIViewRepresentable {
	var make: (Context) -> View
	var update: (View, Context) -> Void = { _, _ in }

	func makeUIView(context: Context) -> View { make(context) }
	func updateUIView(_ uiView: View, context: Context) { update(uiView, context) }
}

import MetalKit

private var rendererKey = 0

func metal() -> AnyUIView<MTKView> {
	.init(make: { _ in
		let view = MTKView()
		let renderer = AAPLRenderer(device: view.device!, format: .r32Float)
		objc_setAssociatedObject(view, &rendererKey, renderer, .OBJC_ASSOCIATION_RETAIN)

		view.colorPixelFormat = .r32Float
		view.delegate = renderer

		return view
	})
}
