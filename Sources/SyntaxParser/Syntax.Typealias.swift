import Foundation

public extension Syntax {
    struct Typealias: Equatable {
        public let name: String
        public let target: String
        public let annotations: [String: [String]]

        public init(name: String, target: String, annotations: [String: [String]] = [:]) {
            self.name = name
            self.target = target
            self.annotations = annotations
        }
    }
}
