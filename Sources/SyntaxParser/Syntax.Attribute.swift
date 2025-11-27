import Foundation

public extension Syntax {
    struct Attribute: Hashable {
        public let name: String
        public let arguments: [String: String]
        public let description: String

        public init(name: String, arguments: [String: String] = [:], description: String? = nil) {
            self.name = name
            self.arguments = arguments
            self.description = description ?? "@\(name)"
        }

        public var key: String { name }
        public var value: [Attribute] { [self] }
        public var asSource: String { description }
    }
}
