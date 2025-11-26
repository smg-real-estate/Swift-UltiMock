import Foundation

extension Syntax {
    public struct Extension: Equatable {
        public let extendedType: String
        public let inheritedTypes: [String]

        public init(extendedType: String, inheritedTypes: [String] = []) {
            self.extendedType = extendedType
            self.inheritedTypes = inheritedTypes
        }
    }
}
