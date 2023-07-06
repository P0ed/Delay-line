import Foundation
import CoreAudioKit
import AVFoundation
import UIKit

public class Engine {
	private var avAudioUnit: AVAudioUnit?
	private let stateChangeQueue = DispatchQueue(label: "delay-line.stateChangeQueue")
	private let engine = AVAudioEngine()

	public init() {

		let input = engine.inputNode
		let mixer = engine.mainMixerNode
		let output = engine.outputNode

		engine.connect(input, to: mixer, format: input.inputFormat(forBus: 0))
		engine.connect(mixer, to: output, format: mixer.inputFormat(forBus: 0))

		engine.prepare()
	}

	func initComponent(type: String, subType: String, manufacturer: String, completion: @escaping (Result<UIViewController, Error>) -> Void) {

		let description = AudioComponentDescription(type: type, subType: subType, manufacturer: manufacturer)
		let lookup = { AVAudioUnitComponentManager.shared().components(matching: description).first }

		guard lookup() != nil else { fatalError("Failed to find component: \(description)") }

		AVAudioUnit.instantiate(with: description, options: .loadOutOfProcess) { unit, error in
			guard let unit, error == nil else { return completion(.failure(error ?? "nil")) }

			self.avAudioUnit = unit
			self.connect(unit: unit)
			self.stateChangeQueue.sync { try! self.engine.start() }

			DispatchQueue.main.async {
				let controller = AUGenericViewController()
				controller.auAudioUnit = unit.auAudioUnit
				completion(.success(controller))
			}
		}
	}

	private func connect(unit: AVAudioUnit) {
		engine.disconnectNodeInput(engine.mainMixerNode)
		engine.detach(unit)

		let fmt = engine.outputNode.outputFormat(forBus: 0)
		engine.connect(engine.mainMixerNode, to: engine.outputNode, format: fmt)

		engine.attach(unit)

		engine.disconnectNodeInput(engine.mainMixerNode)
		engine.connect(engine.inputNode, to: unit, format: fmt)
		engine.connect(unit, to: engine.mainMixerNode, format: fmt)
	}
}

extension AudioComponentDescription {
	init(type: String, subType: String, manufacturer: String) {
		self = AudioComponentDescription(
			componentType: type.fourCharCode!,
			componentSubType: subType.fourCharCode!,
			componentManufacturer: manufacturer.fourCharCode!,
			componentFlags: AudioComponentFlags.sandboxSafe.rawValue,
			componentFlagsMask: 0
		)
	}
}
