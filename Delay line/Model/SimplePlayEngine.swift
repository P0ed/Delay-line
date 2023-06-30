import Foundation
import CoreAudioKit
import AVFoundation
import UIKit

public class Engine {
	private var avAudioUnit: AVAudioUnit?
	private let stateChangeQueue = DispatchQueue(label: "com.example.apple-samplecode.StateChangeQueue")
	private let engine = AVAudioEngine()
	private (set) var isPlaying = false

	private let midiOutBlock: AUMIDIOutputEventBlock = { sampleTime, cable, length, data in return noErr }
	var scheduleMIDIEventListBlock: AUMIDIEventListBlock? = nil

	public init() {

		let session = AVAudioSession.sharedInstance()
		session.availableInputs?.forEach { i in
			if i.portType == .usbAudio { try! session.setPreferredInput(i) }
		}

		let input = engine.inputNode
		let mixer = engine.mainMixerNode
		let output = engine.outputNode

		engine.inputNode.installTap(
			onBus: 0,
			bufferSize: 128,
			format: input.inputFormat(forBus: 0),
			block: { buffer, time in }
		)

		engine.connect(input, to: mixer, format: input.inputFormat(forBus: 0))
		engine.connect(mixer, to: output, format: mixer.inputFormat(forBus: 0))

		engine.prepare()
		setupMIDI()
	}

	private func setupMIDI() {
		let result = MIDIManager.shared.setupPort(
			midiProtocol: MIDIProtocolID._2_0,
			receiveBlock: { [weak self] events, _ in
				_ = self?.scheduleMIDIEventListBlock?(AUEventSampleTimeImmediate, 0, events)
			})
		if !result { fatalError("Failed to setup Core MIDI") }
	}

	func initComponent(type: String, subType: String, manufacturer: String, completion: @escaping (Result<UIViewController, Error>) -> Void) {

		let description = AudioComponentDescription(type: type, subType: subType, manufacturer: manufacturer)
		let lookup = { AVAudioUnitComponentManager.shared().components(matching: description).first }

		guard lookup() != nil else { fatalError("Failed to find component: \(description)") }

		AVAudioUnit.instantiate(with: description, options: .loadOutOfProcess) { unit, error in
			guard let unit, error == nil else { return completion(.failure(error ?? "nil")) }

			self.avAudioUnit = unit
			self.connect(unit: unit)

			unit.loadAudioUnitViewController { viewController in
				completion(viewController.map(Result.success) ?? .failure("nil"))
			}
		}
	}

	private func setSessionActive(_ active: Bool) {
		let session = AVAudioSession.sharedInstance()
		try! session.setCategory(.playback, mode: .default)
		try! session.setActive(active)
	}

	public func startPlaying() {
		stateChangeQueue.sync {
			if !self.isPlaying { self.startPlayingInternal() }
		}
	}

	public func stopPlaying() {
		stateChangeQueue.sync {
			if self.isPlaying { self.stopPlayingInternal() }
		}
	}

	public func togglePlay() -> Bool {
		isPlaying ? stopPlaying() : startPlaying()
		return isPlaying
	}

	private func startPlayingInternal() {
		guard avAudioUnit != nil else { return }
		setSessionActive(true)
		try! engine.start()
		isPlaying = true
	}

	private func stopPlayingInternal() {
		guard avAudioUnit != nil else { return }
		engine.stop()
		isPlaying = false
		setSessionActive(false)
	}

	private func connect(unit: AVAudioUnit, completion: @escaping () -> Void = {}) {
		engine.disconnectNodeInput(engine.mainMixerNode)
		engine.detach(unit)

		let fmt = engine.outputNode.outputFormat(forBus: 0)
		engine.connect(engine.mainMixerNode, to: engine.outputNode, format: fmt)

		if !unit.auAudioUnit.midiOutputNames.isEmpty {
			unit.auAudioUnit.midiOutputEventBlock = midiOutBlock
		}

		engine.attach(unit)

		engine.disconnectNodeInput(engine.mainMixerNode)
		engine.connect(engine.inputNode, to: unit, format: fmt)
		engine.connect(unit, to: engine.mainMixerNode, format: fmt)

		scheduleMIDIEventListBlock = unit.auAudioUnit.scheduleMIDIEventListBlock
		completion()
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

extension AVAudioUnit {

	fileprivate func loadAudioUnitViewController(completion: @escaping (UIViewController?) -> Void) {
		DispatchQueue.main.async {
			let controller = AUGenericViewController()
			controller.auAudioUnit = self.auAudioUnit
			completion(controller)
		}
	}
}
