import UIKit

extension UIColor {
	static var buttonNormal: UIColor { .init(white: 0.3, alpha: 1) }
	static var buttonHighlighted: UIColor { .init(white: 0.2, alpha: 1) }
	static var buttonSelected: UIColor { .init(white: 0.1, alpha: 1) }
}

final class Button: UIButton {
	var isHighlightedDidSet: (Button, Bool) -> Void = { _, _ in }
	var isSelectedDidSet: (Button, Bool) -> Void = { _, _ in }

	override var isHighlighted: Bool { didSet { isHighlightedDidSet(self, isHighlighted) } }
	override var isSelected: Bool { didSet { isSelectedDidSet(self, isSelected) } }

	convenience init(action: @escaping () -> Void) {
		self.init(primaryAction: UIAction(handler: { _ in
			commit.impactOccurred(intensity: 1)
			action()
		}))
		layer.cornerRadius = 8
		backgroundColor = .buttonNormal
		isSelectedDidSet = { $0.backgroundColor = $1 ? .buttonSelected : .buttonNormal }
		isHighlightedDidSet = { $0.backgroundColor = $1 ? .buttonHighlighted : .buttonNormal }
	}
}

private let commit = UIImpactFeedbackGenerator(style: .heavy)
