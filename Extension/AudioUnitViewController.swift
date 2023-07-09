import CoreAudioKit
import os
import UIKit
import MetalKit
import SwiftUI

private var log: [Int32] = .init(repeating: 0, count: 64)
private var idx = 0

final class AudioUnitViewController: AUViewController, AUAudioUnitFactory {

	struct State {
		var holds = false
		var dragged = false
		var stopped = false
		var speed = 1 as Float
		var dSpeed = 0 as Float
		var offset = 0 as Float

		var eHolds: Float { holds || stopped || dragged ? 1 : 0 }
		var eSpeed: Float { stopped ? 0 : min(max(speed + dSpeed, 0), 4) }
	}

	private var setValue: (ParameterAddress, AUValue) -> Void = { _, _ in }
	private var state = State() {
		didSet {
			if state.eHolds != oldValue.eHolds { setValue(.hold, state.eHolds) }
			if state.eSpeed != oldValue.eSpeed { setValue(.speed, state.eSpeed) }
		}
	}

	@objc public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
		let unit = try DelayUnit(componentDescription: componentDescription, options: [])
		setValue = { unit.parameterTree?.parameter(withAddress: $0.rawValue)?.value = $1 }
		DispatchQueue.main.async { self.setupUI(unit: unit) }
		return unit
	}

	private func setupUI(unit: DelayUnit) {
		let img = { [bounds = view.bounds] in
			let view = UIImageView(frame: bounds.intersection(bounds
				.offsetBy(dx: $0 * bounds.width / 2, dy: 0)
			))
			view.transform = .identity.scaledBy(x: $0, y: 1)
			return view
		}
		let left = img(-1)
		let right = img(1)
		view.addSubview(left)
		view.addSubview(right)

		lifetime += [Timer.scheduledTimer(withTimeInterval: 1 / 60, repeats: true, block: { _ in
			let ft = unit.ft()
			self.state.offset = Float(ft.rowOffset) / Float(ft.rows)
			let image = UIImage.grayscaleImage(withData: ft.data, width: ft.cols, height: ft.rows)
			left.image = image
			right.image = image
			log[idx] = ft.rowOffset
			idx = (idx + 1) % 64
		})]

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
		view.addGestureRecognizer(UITapGestureRecognizer(
			handler: { [weak self] _ in self?.state.speed = self?.state.speed == 1 ? 2 : 1 },
			setupDelegate: { rec, delegate in
				rec.numberOfTouchesRequired = 3
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
}
