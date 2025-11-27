import Foundation

public extension Syntax {
    struct Extension: Equatable {
        public let extendedType: String
        public let inheritedTypes: [String]

        public init(extendedType: String, inheritedTypes: [String] = []) {
            self.extendedType = extendedType
            self.inheritedTypes = inheritedTypes
        }
    }
}
