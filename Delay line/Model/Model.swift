import SwiftUI
import CoreMIDI
import AudioToolbox
import AVFoundation

final class Model: ObservableObject {

	private let engine: Engine

	@Published private(set) var state: Result<UIViewController, String>?

    init(type: String = "aufx", subType: String = "dlln", manufacturer: String = "Kost") {
		AVAudioSession.activate()

		engine = Engine()

		engine.initComponent(type: type, subType: subType, manufacturer: manufacturer) { [self] result in
			state = result.mapError { $0 as? String ?? $0.localizedDescription }
		}

		UIApplication.shared.isIdleTimerDisabled = true
    }
}

extension AVAudioSession {

	static func activate() {
		let session = AVAudioSession.sharedInstance()
		try! session.setCategory(.playAndRecord, mode: .default)
		session.availableInputs?.forEach { i in
			if i.portType == .usbAudio { try! session.setPreferredInput(i) }
		}
		try! session.setActive(true)
	}
}
