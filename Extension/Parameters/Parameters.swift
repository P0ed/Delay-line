import Foundation
import AudioToolbox

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
			valueRange: 1...4
		)
    }
}
