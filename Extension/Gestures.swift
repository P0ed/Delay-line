import UIKit

public protocol GestureRecognizerProtocol {}
extension UIGestureRecognizer: GestureRecognizerProtocol {}

public extension GestureRecognizerProtocol where Self: UIGestureRecognizer {

	init(handler: @escaping (Self) -> Void) {
		self.init(handler: handler, setupDelegate: { _, _ in })
	}

	init(handler: @escaping (Self) -> Void, setupDelegate setup: (Self, GestureRecognizerDelegate<Self>) -> Void) {
		self.init(target: nil, action: nil)
		addHandler(handler)
		let delegate = GestureRecognizerDelegate<Self>()
		self.delegate = delegate
		setup(self, delegate)
		lifetime += [delegate]
	}

	func addHandler(_ handler: @escaping (Self) -> Void) {
		let trampoline = ActionTrampoline<Self>(handler)
		lifetime += [trampoline]
		addTarget(trampoline, action: trampoline.selector)
	}
}

public final class GestureRecognizerDelegate<ConcreteRecognizer: UIGestureRecognizer>: NSObject, UIGestureRecognizerDelegate {
	public var shouldBeRequiredToFailBy: ((ConcreteRecognizer, UIGestureRecognizer) -> Bool)?
	public var shouldRequireFailureOf: ((ConcreteRecognizer, UIGestureRecognizer) -> Bool)?
	public var shouldRecognizeSimultaneouslyWith: ((ConcreteRecognizer, UIGestureRecognizer) -> Bool)?
	public var shouldBegin: ((ConcreteRecognizer) -> Bool)?
	public var shouldReceiveTouch: ((ConcreteRecognizer, UITouch) -> Bool)?

	public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
		guard let recognizer = gestureRecognizer as? ConcreteRecognizer, let shouldBeRequiredToFailBy = shouldBeRequiredToFailBy else { return false }
		return shouldBeRequiredToFailBy(recognizer, otherGestureRecognizer)
	}
	public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
		guard let recognizer = gestureRecognizer as? ConcreteRecognizer, let shouldRequireFailureOf = shouldRequireFailureOf else { return false }
		return shouldRequireFailureOf(recognizer, otherGestureRecognizer)
	}
	public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
		guard let recognizer = gestureRecognizer as? ConcreteRecognizer, let shouldRecognizeSimultaneouslyWith = shouldRecognizeSimultaneouslyWith else { return false }
		return shouldRecognizeSimultaneouslyWith(recognizer, otherGestureRecognizer)
	}
	public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
		guard let recognizer = gestureRecognizer as? ConcreteRecognizer, let shouldBegin = shouldBegin else { return true }
		return shouldBegin(recognizer)
	}
	public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
		guard let recognizer = gestureRecognizer as? ConcreteRecognizer, let shouldReceiveTouch = shouldReceiveTouch else { return true }
		return shouldReceiveTouch(recognizer, touch)
	}
}

import UIKit.UIGestureRecognizerSubclass

public final class TouchGestureRecognizer: UIGestureRecognizer {
	private let moveThreshold = 10 as CGFloat
	private var touchLocation = nil as CGPoint?

	public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
		if state == .possible { state = .began }
		touchLocation = touches.first?.location(in: view)
	}
	public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
		guard let initial = touchLocation, let to = touches.first?.location(in: view),
		   max(abs(to.x - initial.x), abs(to.y - initial.y)) > moveThreshold
		else { return }
		state = .failed
	}
	public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
		state = .recognized
	}
	public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
		state = .cancelled
	}
}

final class ActionTrampoline<A>: NSObject {
	private let action: (A) -> Void
	var selector: Selector { #selector(objCAction) }

	init(_ action: @escaping (A) -> Void) { self.action = action }
	@objc private func objCAction(_ sender: Any) { action(sender as! A) }
}

extension NSObject {

	private static var lifetimeKey = 0

	var lifetime: [Any] {
		get {
			(objc_getAssociatedObject(self, &Self.lifetimeKey) as? [Any]) ?? []
		}
		set {
			objc_setAssociatedObject(self, &Self.lifetimeKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
		}
	}
}
