import CoreAudioKit
import os
import UIKit
import MetalKit
import SwiftUI

final class AudioUnitViewController: AUViewController, AUAudioUnitFactory {

	struct State {
		var holds = false
		var dragged = false
		var stopped = false
		var speed = 1 as Float
		var dSpeed = 0 as Float

		var eHolds: Bool { holds || stopped || dragged }
		var eSpeed: Float { stopped ? 0 : speed + dSpeed }
	}

	var state = State() {
		didSet {
			let hld = state.eHolds
			if hld != oldValue.eHolds { parameter(.hold)?.value = hld ? 1 : 0 }

			let spd = state.eSpeed
			if spd != oldValue.eSpeed { parameter(.speed)?.value = min(max(spd, 0), 4) }
		}
	}

	var unit: DelayUnit?
	var renderer: Renderer?
	var imgView: UIImageView?
	var timer: Timer?

	public override func beginRequest(with context: NSExtensionContext) {}

	@objc public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
		let unit = try DelayUnit(componentDescription: componentDescription, options: [])
		self.unit = unit
		DispatchQueue.main.async { self.setupUI() }
		return unit
	}

	private let imageData = UnsafeMutablePointer<UInt32>.allocate(capacity: 512 * 1024)

	private func setupUI() {
		let imgView = UIImageView(frame: view.bounds)
		imgView.contentMode = .scaleAspectFill
		view.addSubview(imgView)
		self.imgView = imgView

		timer = Timer.scheduledTimer(withTimeInterval: 1 / 60, repeats: true, block: { [unit, imageData] _ in
			unit?.ft { data in memcpy(imageData, data, 512 * 1024 * 4) }
			imgView.image = Renderer.img(imageData)
		})

		addGestures()
	}

	private func addGestures() {

		view.addGestureRecognizer(UITapGestureRecognizer(
			handler: { [weak self] _ in
				self?.state.holds.toggle()
			}
		))

		view.addGestureRecognizer(UITapGestureRecognizer(
			handler: { [weak self] _ in
				self?.state.stopped.toggle()
				self?.state.speed = 1
			},
			setupDelegate: { rec, delegate in
				rec.numberOfTouchesRequired = 2
			}
		))

		view.addGestureRecognizer(UIPanGestureRecognizer(
			handler: { [weak self] recognizer in
				guard let self, let view = recognizer.view else { return }

				let translation = -recognizer.translation(in: view).y

				switch recognizer.state {
				case .began: state.dragged = true
				case .changed: state.dSpeed = Float(translation) / 256
				case .cancelled, .ended:
					state.dragged = false
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
