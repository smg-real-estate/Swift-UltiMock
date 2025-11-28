import Foundation

public extension Syntax {
    struct TypeInfo: Equatable {
        public enum Kind: Equatable {
            case `class`
            case `struct`
            case `enum`
            case `protocol`
            case `extension`
        }

        public internal(set) var kind: Kind
        public internal(set) var name: String
        public internal(set) var localName: String
        public internal(set) var accessLevel: AccessLevel
        public internal(set) var inheritedTypes: [String]
        public internal(set) var genericParameters: [GenericParameter] = []
        public internal(set) var methods: [Method] = []
        public internal(set) var properties: [Property] = []
        public internal(set) var subscripts: [Subscript] = []
        public internal(set) var annotations: [String: [String]] = [:]
        public internal(set) var isExtension: Bool
        public internal(set) var comment: String?
        public internal(set) var associatedTypes: [AssociatedType] = []
        public internal(set) var genericRequirements: [GenericRequirement] = []

        public var allMethods: [Method] { methods }
        public var allVariables: [Property] { properties }
        public var allSubscripts: [Subscript] { subscripts }
        public var based: [String: String] {
            inheritedTypes.reduce(into: [:]) { result, type in
                result[type] = type
            }
        }

        public var implements: [String: TypeInfo] {
            [:]
        }

        public var supertype: TypeInfo? {
            nil
        }
    }
}
