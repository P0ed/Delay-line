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
			UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: 1.0)
			action()
		}))
		layer.cornerRadius = 8
		backgroundColor = .buttonNormal
		isSelectedDidSet = { $0.backgroundColor = $1 ? .buttonSelected : .buttonNormal }
		isHighlightedDidSet = { $0.backgroundColor = $1 ? .buttonHighlighted : .buttonNormal }
	}
}

extension UIView {

	func setHiddenAnimated(_ isHidden: Bool) {
		UIView.animate(
			withDuration: 0.1,
			delay: 0,
			options: .beginFromCurrentState,
			animations: { self.alpha = isHidden ? 0 : 1 }
		)
	}
}
