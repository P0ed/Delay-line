import SwiftUI
import Foundation
import CoreAudioKit
import AVFoundation

final class Model: ObservableObject {
	private var unit: AVAudioUnit?
	private var engine: AVAudioEngine?

	@Published private(set) var state: Result<UIViewController, String> = .failure("")

    init() {
		let lookup = { AVAudioUnitComponentManager.shared().components(matching: .delayLine).first }
		let assign = { result in DispatchQueue.main.async { self.state = result } }

		guard lookup() != nil else {
			assign(.failure("Failed to find component"))
			return
		}

		AVAudioUnit.instantiate(with: .delayLine, options: .loadOutOfProcess) { unit, error in
			guard let unit, error == nil else { return assign(.failure(error?.localizedDescription ?? "Unknown error")) }

			self.unit = unit
			self.connect(unit: unit)

			unit.auAudioUnit.requestViewController { controller in
				assign(controller.map { .success($0) } ?? .failure("nil"))
			}
		}
	}

	private func connect(unit: AVAudioUnit) {
		do {
			let session = AVAudioSession.sharedInstance()
			try session.setCategory(.multiRoute, mode: .default)
			try session.setPreferredSampleRate(48000)
			try session.setActive(true)

			try session.availableInputs?.forEach { i in
				if i.portType == .usbAudio { try session.setPreferredInput(i) }
			}

			let engine = AVAudioEngine()
			engine.attach(unit)
			engine.connect(engine.inputNode, to: unit, format: engine.inputNode.inputFormat(forBus: 0))
			engine.connect(unit, to: engine.mainMixerNode, format: engine.outputNode.outputFormat(forBus: 0))

			try engine.start()
			self.engine = engine
		} catch {
			print(error)
		}
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

extension String: Swift.Error {}
