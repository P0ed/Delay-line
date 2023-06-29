import Foundation

extension String {
    var range: NSRange {
        NSRange(location: 0, length: count)
    }
    
    func isAlphanumeric() -> Bool {
        if self.isEmpty { return false }
        let regex = try! NSRegularExpression(pattern: "^[a-zA-Z0-9_-]*$", options: .caseInsensitive)
        guard regex.firstMatch(in: self, options: [], range: range) != nil else {
            return false
        }
        return true
    }
}

extension Result {
	func fold<A>(_ success: (Success) throws -> A, _ failure: (Error) throws -> A) rethrows -> A {
		switch self {
		case .success(let value): return try success(value)
		case .failure(let error): return try failure(error)
		}
	}
}
