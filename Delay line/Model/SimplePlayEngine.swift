import Foundation
import CoreAudioKit
import AVFoundation
import UIKit

extension AVAudioUnit {

	static fileprivate func description(type: String, subType: String, manufacturer: String) -> AudioComponentDescription {
		AudioComponentDescription(
			componentType: type.fourCharCode!,
			componentSubType: subType.fourCharCode!,
			componentManufacturer: manufacturer.fourCharCode!,
			componentFlags: AudioComponentFlags.sandboxSafe.rawValue,
			componentFlagsMask: 0
		)
	}

	fileprivate func loadAudioUnitViewController(completion: @escaping (UIViewController?) -> Void) {
		DispatchQueue.main.async {
			let controller = AUGenericViewController()
			controller.auAudioUnit = self.auAudioUnit
			completion(controller)
		}
	}
}

public class SimplePlayEngine {
	private var avAudioUnit: AVAudioUnit?
	private let stateChangeQueue = DispatchQueue(label: "com.example.apple-samplecode.StateChangeQueue")
	private let engine = AVAudioEngine()
	private let player = AVAudioPlayerNode()
	private var file: AVAudioFile?
	private (set) var isPlaying = false

	private let midiOutBlock: AUMIDIOutputEventBlock = { sampleTime, cable, length, data in return noErr }

	var scheduleMIDIEventListBlock: AUMIDIEventListBlock? = nil

	public init() {
		engine.attach(player)

		guard let fileURL = Bundle.main.url(forResource: "Synth", withExtension: "aif") else {
			fatalError("\"Synth.aif\" file not found.")
		}
		setPlayerFile(fileURL)

		engine.prepare()
		setupMIDI()
	}

	private func setupMIDI() {
		if !MIDIManager.shared.setupPort(midiProtocol: MIDIProtocolID._2_0, receiveBlock: { [weak self] eventList, _ in
			if let scheduleMIDIEventListBlock = self?.scheduleMIDIEventListBlock {
				_ = scheduleMIDIEventListBlock(AUEventSampleTimeImmediate, 0, eventList)
			}
		}) {
			fatalError("Failed to setup Core MIDI")
		}
	}

	func initComponent(type: String, subType: String, manufacturer: String, completion: @escaping (Result<UIViewController, Error>) -> Void) {
		reset()

		let description = AVAudioUnit.description(type: type, subType: subType, manufacturer: manufacturer)
		let lookup = { AVAudioUnitComponentManager.shared().components(matching: description).first }

		guard lookup() != nil else {
			print("Failed to find component with type: \(type), subtype: \(subType), manufacturer: \(manufacturer))" )
			print(AVAudioUnitComponentManager.shared().components(passingTest: { _, _ in true }).map(\.name))
			return
		}

		AVAudioUnit.instantiate(with: description, options: .loadOutOfProcess) { avAudioUnit, error in
			guard let audioUnit = avAudioUnit, error == nil else {
				return completion(.failure(error ?? "nil"))
			}

			self.avAudioUnit = audioUnit
			self.connect(avAudioUnit: audioUnit)

			audioUnit.loadAudioUnitViewController { viewController in
				completion(viewController.map(Result.success) ?? .failure("nil"))
			}
		}
	}

	private func setPlayerFile(_ fileURL: URL) {
		do {
			let file = try AVAudioFile(forReading: fileURL)
			self.file = file
			engine.connect(player, to: engine.mainMixerNode, format: file.processingFormat)
		} catch {
			fatalError("Could not create AVAudioFile instance. error: \(error).")
		}
	}

	private func setSessionActive(_ active: Bool) {
#if os(iOS)
		do {
			let session = AVAudioSession.sharedInstance()
			try session.setCategory(.playback, mode: .default)
			try session.setActive(active)
		} catch {
			fatalError("Could not set Audio Session active \(active). error: \(error).")
		}
#endif
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
		if isPlaying {
			stopPlaying()
		} else {
			startPlaying()
		}
		return isPlaying
	}

	private func startPlayingInternal() {
		guard avAudioUnit != nil else { return }

		// assumptions: we are protected by stateChangeQueue. we are not playing.
		setSessionActive(true)

		scheduleEffectLoop()
		scheduleEffectLoop()

		let hardwareFormat = engine.outputNode.outputFormat(forBus: 0)
		engine.connect(engine.mainMixerNode, to: engine.outputNode, format: hardwareFormat)

		do {
			try engine.start()
		} catch {
			isPlaying = false
			fatalError("Could not start engine. error: \(error).")
		}

		player.play()
		isPlaying = true
	}

	private func stopPlayingInternal() {
		guard avAudioUnit != nil else { return }

		player.stop()
		engine.stop()
		isPlaying = false
		setSessionActive(false)
	}

	private func scheduleEffectLoop() {
		guard let file = file else {
			fatalError("`file` must not be nil in \(#function).")
		}

		player.scheduleFile(file, at: nil) {
			self.stateChangeQueue.async {
				if self.isPlaying {
					self.scheduleEffectLoop()
				}
			}
		}
	}

	private func resetAudioLoop() {
		guard avAudioUnit != nil else { return }

		guard let format = file?.processingFormat else { fatalError("No AVAudioFile defined (processing format unavailable).") }
		engine.connect(player, to: engine.mainMixerNode, format: format)
	}

	public func reset() {
		
	}

	public func connect(avAudioUnit: AVAudioUnit, completion: @escaping (() -> Void) = {}) {
		engine.disconnectNodeInput(engine.mainMixerNode)
		resetAudioLoop()
		engine.detach(avAudioUnit)

		let hardwareFormat = engine.outputNode.outputFormat(forBus: 0)

		engine.connect(engine.mainMixerNode, to: engine.outputNode, format: hardwareFormat)

		// Pause the player before re-wiring it. It is not simple to keep it playing across an insertion or deletion.
		if isPlaying { player.pause() }

		let auAudioUnit = avAudioUnit.auAudioUnit

		if !auAudioUnit.midiOutputNames.isEmpty {
			auAudioUnit.midiOutputEventBlock = midiOutBlock
		}

		engine.attach(avAudioUnit)

		engine.disconnectNodeInput(engine.mainMixerNode)

		if let format = file?.processingFormat {
			engine.connect(player, to: avAudioUnit, format: format)
			engine.connect(avAudioUnit, to: engine.mainMixerNode, format: format)
		}

		scheduleMIDIEventListBlock = auAudioUnit.scheduleMIDIEventListBlock
		if isPlaying {
			player.play()
		}
		completion()
	}
}
