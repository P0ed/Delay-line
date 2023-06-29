import Foundation
import AudioToolbox

let ParameterSpecs = ParameterTreeSpec {
    ParameterGroupSpec(identifier: "global", name: "Global") {
		ParameterSpec(
			address: .hold,
			identifier: "hold",
			name: "Hold",
			units: .boolean,
			valueRange: 0.0...1.0,
			defaultValue: 0
		)
        ParameterSpec(
            address: .gain,
            identifier: "gain",
            name: "Output Gain",
            units: .linearGain,
            valueRange: 0.0...1.0,
            defaultValue: 1
        )
    }
}

extension ParameterSpec {
    init(
        address: ParameterAddress,
        identifier: String,
        name: String,
        units: AudioUnitParameterUnit,
        valueRange: ClosedRange<AUValue>,
        defaultValue: AUValue,
        unitName: String? = nil,
        flags: AudioUnitParameterOptions = [AudioUnitParameterOptions.flag_IsWritable, AudioUnitParameterOptions.flag_IsReadable],
        valueStrings: [String]? = nil,
        dependentParameters: [NSNumber]? = nil
    ) {
        self.init(address: address.rawValue,
                  identifier: identifier,
                  name: name,
                  units: units,
                  valueRange: valueRange,
                  defaultValue: defaultValue,
                  unitName: unitName,
                  flags: flags,
                  valueStrings: valueStrings,
                  dependentParameters: dependentParameters)
    }
}
