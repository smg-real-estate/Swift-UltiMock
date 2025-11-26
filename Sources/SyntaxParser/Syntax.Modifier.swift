import Foundation

extension Syntax {
    public struct Modifier: Hashable {
        public let name: String

        public init(name: String) {
            self.name = name
        }
    }
}
