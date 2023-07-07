import Foundation
import CoreAudioKit
import AVFoundation
import UIKit

public class Engine {
	private var unit: AVAudioUnit?
	private let engine = AVAudioEngine()

	public init() {
		let input = engine.inputNode
		let mixer = engine.mainMixerNode
		let output = engine.outputNode

		engine.connect(input, to: mixer, format: input.inputFormat(forBus: 0))
		engine.connect(mixer, to: output, format: mixer.inputFormat(forBus: 0))

		engine.prepare()
	}

	func setup(completion: @escaping (Result<UIViewController, Error>) -> Void) {
		let lookup = { AVAudioUnitComponentManager.shared().components(matching: .delayLine).first }
		let completion = { result in DispatchQueue.main.async { completion(result) } }
		guard lookup() != nil else { return completion(.failure("Failed to find component")) }

		AVAudioUnit.instantiate(with: .delayLine, options: .loadOutOfProcess) { unit, error in
			guard let unit, error == nil else { return completion(.failure(error ?? "xxx")) }

			self.unit = unit
			self.connect(unit: unit)
			try! self.engine.start()

			unit.auAudioUnit.requestViewController { controller in
				completion(controller.map { .success($0) } ?? .failure("nil"))
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
	static let delayLine = AudioComponentDescription(
		componentType: "aufx".fourCharCode,
		componentSubType: "dlln".fourCharCode,
		componentManufacturer: "Kost".fourCharCode,
		componentFlags: AudioComponentFlags.sandboxSafe.rawValue,
		componentFlagsMask: 0
	)
}

extension String {
	var fourCharCode: FourCharCode {
		guard count == 4 && utf8.count == 4 else { fatalError() }
		var code: FourCharCode = 0
		for character in self.utf8 { code = code << 8 + FourCharCode(character) }
		return code
	}
}

extension String: Error {}
