import CoreAudioKit
import os

private let log = Logger(subsystem: "com.bundle.id.", category: "AudioUnitFactory")

public class AudioUnitFactory: NSObject, AUAudioUnitFactory {
    private var unit: AUAudioUnit?

    private var observation: NSKeyValueObservation?

    public func beginRequest(with context: NSExtensionContext) {}

    @objc
    public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
        let unit = try Unit(componentDescription: componentDescription, options: [])
		self.unit = unit

        unit.setupParameterTree(ParameterSpecs.createAUParameterTree())

        observation = unit.observe(\.allParameterValues, options: [.new]) { object, change in
            guard let tree = unit.parameterTree else { return }

            // This insures the Audio Unit gets initial values from the host.
            for param in tree.allParameters { param.value = param.value }
        }

        return unit
    }
}
