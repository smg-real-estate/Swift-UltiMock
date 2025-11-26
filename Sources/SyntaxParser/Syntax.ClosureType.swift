import Foundation

extension Syntax {
    public struct ClosureType: Equatable {
        public let description: String

        public init(description: String) {
            self.description = description
        }

        public var asFixedSource: String { description }
    }
}
