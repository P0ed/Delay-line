import CoreAudioKit
import os

final class AudioUnitViewController: AUViewController, AUAudioUnitFactory {
	var unit: DelayUnit?

	public override func beginRequest(with context: NSExtensionContext) {}

	@objc public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
		let unit = try DelayUnit(componentDescription: componentDescription, options: [])
		self.unit = unit
		DispatchQueue.main.async { self.setupUI(unit: unit) }

		return unit
	}

	private func setupUI(unit: DelayUnit) {
		let controller = AUGenericViewController()
		controller.auAudioUnit = unit
		addChild(controller)
		view.addSubview(controller.view)
		controller.didMove(toParent: self)
	}
}

import MetalKit

private var rendererKey = 0

func metal() -> MTKView {
	let view = MTKView()
	let renderer = AAPLRenderer(device: view.device!, format: .r32Float)
	objc_setAssociatedObject(view, &rendererKey, renderer, .OBJC_ASSOCIATION_RETAIN)

	view.colorPixelFormat = .r32Float
	view.delegate = renderer

	return view
}
