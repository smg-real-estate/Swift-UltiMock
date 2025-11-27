import Foundation

public extension Syntax {
    struct ClosureType: Equatable {
        public let description: String

        public init(description: String) {
            self.description = description
        }

        public var asFixedSource: String { description }
    }
}
