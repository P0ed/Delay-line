import CoreAudioKit
import os
import UIKit
import MetalKit
import SwiftUI

final class AudioUnitViewController: AUViewController, AUAudioUnitFactory {
	var unit: DelayUnit?
	var lifetime: Any?

	public override func beginRequest(with context: NSExtensionContext) {}

	@objc public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
		let unit = try DelayUnit(componentDescription: componentDescription, options: [])
		self.unit = unit
		DispatchQueue.main.async { self.setupUI(unit: unit) }

		return unit
	}

	private func setupUI(unit: DelayUnit) {
		let hold = unit.parameterTree?.parameter(withAddress: ParameterAddress.hold.rawValue)
		let speed = unit.parameterTree?.parameter(withAddress: ParameterAddress.speed.rawValue)

		// ??
		lifetime = unit.observe(\.allParameterValues, options: [.new]) { object, change in
			unit.parameterTree?.allParameters.forEach { $0.value = $0.value }
		}

		let controller = UIHostingController(rootView: VStack {
			Spacer()
			Spacer()
			Button("hold", action: { hold?.value = hold?.value == 0 ? 1 : 0 }).font(.headline)
			Spacer()
			Button("+", action: { speed?.value = max(10, speed?.value ?? 0 + 0.4) }).font(.headline)
			Spacer()
			Button("-", action: { speed?.value = max(0, speed?.value ?? 0 - 0.4) }).font(.headline)
			Spacer()
			Spacer()
		})
		addChild(controller)
		controller.view.frame = view.bounds
		view.addSubview(controller.view)
		controller.didMove(toParent: self)
	}
}

private var rendererKey = 0

func metal() -> MTKView {
	let view = MTKView()
	let renderer = AAPLRenderer(device: view.device!, format: .r32Float)
	objc_setAssociatedObject(view, &rendererKey, renderer, .OBJC_ASSOCIATION_RETAIN)

	view.colorPixelFormat = .r32Float
	view.delegate = renderer

	return view
}
