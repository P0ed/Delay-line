import CoreAudioKit
import os
import UIKit
import MetalKit
import SwiftUI

final class AudioUnitViewController: AUViewController, AUAudioUnitFactory {

	struct State {
		var holds = false
		var stopped = false
		var speed = 1 as Float
		var dSpeed = 0 as Float

		var eHolds: Bool { holds || stopped }
		var eSpeed: Float { stopped ? 0 : speed + dSpeed }
	}

	var state = State() {
		didSet {
			let hld = state.eHolds
			if hld != oldValue.eHolds { parameter(.hold)?.value = hld ? 1 : 0 }

			let spd = state.eSpeed
			if spd != oldValue.eSpeed { parameter(.speed)?.value = max(0, spd) }
		}
	}

	var unit: DelayUnit?
	var renderer: AAPLRenderer?

	public override func beginRequest(with context: NSExtensionContext) {}

	@objc public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
		let unit = try DelayUnit(componentDescription: componentDescription, options: [])
		self.unit = unit
		DispatchQueue.main.async { self.setupUI(unit: unit) }

		return unit
	}

	private func setupUI(unit: DelayUnit) {
//		let textureView = MTKView(frame: view.bounds)
//		let renderer = AAPLRenderer(device: textureView.device!, format: .r32Float)
//		textureView.colorPixelFormat = .r32Float
//		textureView.delegate = renderer
//		textureView.isUserInteractionEnabled = false
//		view.addSubview(textureView)
//		self.renderer = renderer

		CADisplayLink(target: self, selector: #selector(update))
			.add(to: .main, forMode: .common)

		addGestures()
	}

	@objc private func update() {
		if let data = unit?.ft {
			renderer?.loadTexture(data, width: 512, height: 1024)
		}
	}

	private func addGestures() {
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

				let translation = -recognizer.translation(in: view).y

				switch recognizer.state {
				case .began: state.holds = true
				case .changed: state.dSpeed = Float(translation) / 256
				case .cancelled, .ended:
					state.holds = false
					state.dSpeed = 0
				default: break
				}
			}
		))
	}

	private func parameter(_ address: ParameterAddress) -> AUParameter? {
		unit?.parameterTree?.parameter(withAddress: address.rawValue)
	}
}
