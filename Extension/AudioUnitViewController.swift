import CoreAudioKit
import os
import UIKit
import MetalKit
import SwiftUI

final class AudioUnitViewController: AUViewController, AUAudioUnitFactory {
	var unit: DelayUnit?

	public override func beginRequest(with context: NSExtensionContext) {}

	@objc public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
		let unit = try DelayUnit(componentDescription: componentDescription, options: [])
		self.unit = unit
		DispatchQueue.main.async { self.setupUI(unit: unit) }

		return unit
	}

	struct State {
		var holds = false
		var stopped = false
		var speed = 1 as Float
	}

	var state = State() {
		didSet {
			let hld = state.holds || state.stopped ? 1 : 0 as Float
			let oldHld = oldValue.holds || oldValue.stopped ? 1 : 0 as Float
			if hld != oldHld { parameter(.hold)?.value = hld }

			let spd = state.stopped ? 0 : state.speed
			let oldSpd = oldValue.stopped ? 0 : oldValue.speed
			if spd != oldSpd { parameter(.speed)?.value = spd }
		}
	}

	func parameter(_ address: ParameterAddress) -> AUParameter? {
		unit?.parameterTree?.parameter(withAddress: address.rawValue)
	}

	private func setupUI(unit: DelayUnit) {

		view.addGestureRecognizer(UITapGestureRecognizer(
			handler: { [weak self] _ in
				self?.state.holds.toggle()
			},
			setupDelegate: { rec, delegate in
				rec.numberOfTapsRequired = 1
			}
		))

		view.addGestureRecognizer(UITapGestureRecognizer(
			handler: { [weak self] _ in
				self?.state.stopped.toggle()
			},
			setupDelegate: { rec, delegate in
				rec.numberOfTapsRequired = 2
			}
		))

		view.addGestureRecognizer(UIPanGestureRecognizer(
			handler: { [weak self] recognizer in
				guard let self, let view = recognizer.view else { return }

				let translation = recognizer.translation(in: view).y

				switch recognizer.state {
				case .began: state.holds = true
				case .changed: state.speed = abs(1 - Float(translation) / 256)
				case .cancelled: state.holds = false
				case .ended: state.holds = false
				default: break
				}
			},
			setupDelegate: { rec, delegate in

			}
		))
	}
}

func metal() -> MTKView {
	let view = MTKView()
	let renderer = AAPLRenderer(device: view.device!, format: .r32Float)
	view.lifetime = [renderer]

	view.colorPixelFormat = .r32Float
	view.delegate = renderer

	return view
}
