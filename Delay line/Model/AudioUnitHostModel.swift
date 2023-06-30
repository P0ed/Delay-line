import SwiftUI
import CoreMIDI
import AudioToolbox

final class AudioUnitHostModel: ObservableObject {

    private let engine = Engine()

    @Published private(set) var viewModel = AudioUnitViewModel()

    @Published var isPlaying: Bool = false

    let type: String
    let subType: String
    let manufacturer: String
    let wantsAudio: Bool
    let wantsMIDI: Bool
    let auValString: String

    init(type: String = "aufx", subType: String = "dlln", manufacturer: String = "Kost") {
        self.type = type
        self.subType = subType
        self.manufacturer = manufacturer
        wantsAudio = true
        wantsMIDI = true
        auValString = "\(type) \(subType) \(manufacturer)"

		engine.initComponent(type: type, subType: subType, manufacturer: manufacturer) { [self] result in
			switch result {
			case .success(let viewController):
				viewModel = AudioUnitViewModel(
					showAudioControls: wantsAudio,
					showMIDIContols: wantsMIDI,
					title: auValString,
					message: "Successfully loaded (\(self.auValString))",
					viewController: viewController
				)

				if isPlaying { engine.startPlaying() }

			case .failure(let error):
				viewModel = AudioUnitViewModel(
					showAudioControls: false,
					showMIDIContols: false,
					title: auValString,
					message: "Failed to load Audio Unit with error: \(error.localizedDescription)",
					viewController: nil
				)
			}
		}
    }

    func startPlaying() {
		if !isPlaying {
			engine.startPlaying()
			isPlaying = true
		}
	}
    func stopPlaying() {
		if isPlaying {
			engine.stopPlaying()
			isPlaying = false
		}
	}
}
