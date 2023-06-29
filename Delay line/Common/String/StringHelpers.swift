import Foundation

extension String {
    var fourCharCode: FourCharCode? {
		guard count == 4 && utf8.count == 4 else { return nil }

		var code: FourCharCode = 0
		for character in self.utf8 {
			code = code << 8 + FourCharCode(character)
		}
		return code
    }
}

extension String: Error {}
