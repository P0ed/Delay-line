import UIKit
import AudioToolbox
import CoreAudioKit
import os

final class AudioUnitViewController: AUViewController, AUAudioUnitFactory {

	struct State {
		var holds = false
		var dragged = false
		var stopped = false
		var speed = 1 as Float
		var offset = 0 as Float
	}

	private var setValue: (ParameterAddress, AUValue) -> Void = { _, _ in }
	private var state = State() {
		didSet {
			if state.holds != oldValue.holds { setValue(.hold, state.holds ? 1 : 0) }
			if state.speed != oldValue.speed { setValue(.speed, state.speed) }
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

		let setImage = { left.image = $0; right.image = $0 }
		let proxy = ActionTrampoline<CADisplayLink> { [weak self, setImage] _ in
			let ft = unit.ft()
			self?.state.offset = Float(ft.rowOffset) / Float(ft.rows)
			let image = UIImage.grayscaleImage(withData: ft.data, width: ft.cols, height: ft.rows)
			setImage(image)
		}
		let displayLink = CADisplayLink(target: proxy, selector: proxy.selector)
		displayLink.add(to: .main, forMode: .common)

		lifetime += [
			proxy,
			Auto(displayLink.invalidate)
		]

		addGestures()
	}

	private func addGestures() {
		var v = state.speed
		var dV = 0 as Float
		var speed: Float {
			get { min(max(v + dV, 0), 4) }
			set { v = min(max(newValue, 0), 4); dV = 0 }
		}

		view.addGestureRecognizer(UITapGestureRecognizer(
			handler: { [weak self] _ in
				self?.state.holds.toggle()
			}
		))
		view.addGestureRecognizer(UITapGestureRecognizer(
			handler: { [weak self] _ in
				speed = speed == 1 ? 0 : 1
				self?.state.speed = speed
			},
			setupDelegate: { rec, delegate in
				rec.numberOfTouchesRequired = 2
			}
		))
		view.addGestureRecognizer(UIPanGestureRecognizer(
			handler: { [weak self] recognizer in
				guard let self, let view = recognizer.view else { return }
				let translation = -Float(recognizer.translation(in: view).y)

				switch recognizer.state {
				case .began:
					state.dragged = true
				case .changed:
					dV = translation / 256
					state.speed = speed
				case .cancelled, .ended:
					state.dragged = false
					speed = v + dV
				default: break
				}
			}
		))
	}
}

let parameterSpecs = ParameterTreeSpec {
	ParameterGroupSpec(identifier: "base", name: "Base") {
		ParameterSpec(
			address: .hold,
			identifier: "hold",
			name: "Hold",
			units: .boolean,
			valueRange: 0.0...1.0
		)
		ParameterSpec(
			address: .speed,
			identifier: "speed",
			name: "Speed",
			units: .rate,
			valueRange: 0.25...4
		)
	}
}
