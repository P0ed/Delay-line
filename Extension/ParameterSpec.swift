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
			valueRange: 0.25...4
		)
	}
}

public protocol NodeSpec {}

extension NodeSpec {
    static func validateID(_ name: String) -> String {
        let msg = "Parameter identifier should: not be empty, begin with a letter, and only contain alpha numeric characters or underscores. Hint: Use camelCase."
        assert(name.isAlphanumeric, msg)
        return name
    }
}

@resultBuilder struct ParameterGroupBuilder {
    static func buildBlock() -> [NodeSpec] { [] }
    static func buildBlock(_ nodes: NodeSpec...) -> [NodeSpec] { nodes }
}

public struct ParameterGroupSpec: NodeSpec {
    let identifier: String
    let name: String
    let children: [NodeSpec]

    init(identifier: String, name: String, @ParameterGroupBuilder _ children: () -> [NodeSpec]) {
        self.identifier = ParameterGroupSpec.validateID(identifier)
        self.name = name
        self.children = children()
    }
}

public struct ParameterTreeSpec: NodeSpec {
    let children: [NodeSpec]
    init(@ParameterGroupBuilder _ children: () -> [NodeSpec]) { self.children = children() }
}

public struct ParameterSpec: NodeSpec {
    let identifier: String
    let name: String
    let address: AUParameterAddress
    let minValue: AUValue
    let maxValue: AUValue
    let units: AudioUnitParameterUnit
    let unitName: String?
    let flags: AudioUnitParameterOptions
    let valueStrings: [String]?
    let dependentParameters: [NSNumber]?

    init(
        address: AUParameterAddress,
        identifier: String,
        name: String,
        units: AudioUnitParameterUnit,
        valueRange: ClosedRange<AUValue>,
        unitName: String? = nil,
        flags: AudioUnitParameterOptions = [.flag_IsWritable, .flag_IsReadable],
        valueStrings: [String]? = nil,
        dependentParameters: [NSNumber]? = nil
    ) {
        self.identifier = ParameterSpec.validateID(identifier)
        self.name = name
        self.address = address
        self.minValue = valueRange.lowerBound
        self.maxValue = valueRange.upperBound
        self.units = units
        self.unitName = unitName
        self.flags = flags
        self.valueStrings = valueStrings
        self.dependentParameters = dependentParameters
    }

	init(
		address: ParameterAddress,
		identifier: String,
		name: String,
		units: AudioUnitParameterUnit,
		valueRange: ClosedRange<AUValue>,
		unitName: String? = nil,
		flags: AudioUnitParameterOptions = [.flag_IsWritable, .flag_IsReadable],
		valueStrings: [String]? = nil,
		dependentParameters: [NSNumber]? = nil
	) {
		self.init(
			address: address.rawValue,
			identifier: identifier,
			name: name,
			units: units,
			valueRange: valueRange,
			unitName: unitName,
			flags: flags,
			valueStrings: valueStrings,
			dependentParameters: dependentParameters
		)
	}
}


extension AUParameterTree {

	static func createNode(from spec: NodeSpec) -> AUParameterNode {
        switch spec {
        case let parameterSpec as ParameterSpec:
            return AUParameterTree.createParameter(from: parameterSpec)
        case let groupSpec as ParameterGroupSpec:
            return AUParameterTree.createParameterGroup(from: groupSpec)
        default:
            return AUParameterNode()
        }
    }

	static func createParameterGroup(from spec: ParameterGroupSpec) -> AUParameterGroup {
        return self.createGroup(
            withIdentifier: spec.identifier,
            name: spec.name,
            children: spec.children.createAUParameterNodes()
        )
    }

    static func createParameter(from spec: ParameterSpec) -> AUParameter {
        createParameter(
            withIdentifier: spec.identifier,
            name: spec.name,
            address: spec.address,
            min: spec.minValue,
            max: spec.maxValue,
            unit: spec.units,
            unitName: spec.unitName,
            flags: spec.flags,
            valueStrings: spec.valueStrings,
            dependentParameters: spec.dependentParameters
        )
    }
}

extension Array where Element == NodeSpec {
    func createAUParameterNodes() -> [AUParameterNode] {
        self.map { spec in
            AUParameterTree.createNode(from: spec)
        }
    }

    func createAUParameterTree() -> AUParameterTree {
        AUParameterTree.createTree(withChildren: self.createAUParameterNodes())
    }
}

extension AUParameterTree {
    @objc static func make() -> AUParameterTree {
        AUParameterTree.createTree(withChildren: parameterSpecs.children.createAUParameterNodes())
    }
}

private extension String {
	var range: NSRange {
		NSRange(location: 0, length: count)
	}

	var isAlphanumeric: Bool {
		if self.isEmpty { return false }
		let regex = try! NSRegularExpression(pattern: "^[a-zA-Z0-9_-]*$", options: .caseInsensitive)
		guard regex.firstMatch(in: self, options: [], range: range) != nil else {
			return false
		}
		return true
	}
}
