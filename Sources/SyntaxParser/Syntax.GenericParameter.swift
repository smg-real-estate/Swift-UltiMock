import Foundation

public extension Syntax {
    struct GenericParameter: Hashable {
        public let name: String
        public let constraints: [String]

        public init(name: String, constraints: [String] = []) {
            self.name = name
            self.constraints = constraints
        }
    }
}
