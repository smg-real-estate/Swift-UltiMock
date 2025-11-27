import Foundation

public extension Syntax {
    struct Modifier: Hashable {
        public let name: String

        public init(name: String) {
            self.name = name
        }
    }
}
