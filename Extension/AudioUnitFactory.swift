import CoreAudioKit
import os

public final class AudioUnitFactory: NSObject, AUAudioUnitFactory {

    public func beginRequest(with context: NSExtensionContext) {}

    @objc public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
        let unit = try Unit(componentDescription: componentDescription, options: [])
        unit.setupParameterTree(ParameterSpecs.createAUParameterTree())

        return unit
    }
}
