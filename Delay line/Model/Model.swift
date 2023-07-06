import SwiftUI
import CoreMIDI
import AudioToolbox
import AVFoundation

final class Model: ObservableObject {
	@Published private(set) var state: Result<UIViewController, String>?

	private let engine: Engine

    init() {
		AVAudioSession.activate()

		engine = Engine()
		engine.setup { [self] result in
			state = result.mapError { $0 as? String ?? $0.localizedDescription }
		}

		UIApplication.shared.isIdleTimerDisabled = true
    }
}

private extension AVAudioSession {

	static func activate() {
		let session = AVAudioSession.sharedInstance()
		try! session.setCategory(.playAndRecord, mode: .default)
		session.availableInputs?.forEach { i in
			if i.portType == .usbAudio { try! session.setPreferredInput(i) }
		}
		try! session.setActive(true)
	}
}
