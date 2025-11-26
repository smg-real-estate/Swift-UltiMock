import Foundation

extension Syntax {
    public struct TypeInfo: Equatable {
        public enum Kind: Equatable {
            case `class`
            case `struct`
            case `enum`
            case `protocol`
            case `extension`
        }

        public let kind: Kind
        public let name: String
        public let localName: String
        public let accessLevel: AccessLevel
        public let inheritedTypes: [String]
        public let genericParameters: [GenericParameter]
        public let methods: [Method]
        public let properties: [Property]
        public let subscripts: [Subscript]
        public let typealiases: [Typealias]
        public let annotations: [String: [String]]
        public let isExtension: Bool
        public let comment: String?
        public let associatedTypes: [AssociatedType]
        public let genericRequirements: [GenericRequirement]

        public init(
            kind: Kind,
            name: String,
            localName: String? = nil,
            accessLevel: AccessLevel = .internal,
            inheritedTypes: [String] = [],
            genericParameters: [GenericParameter] = [],
            methods: [Method] = [],
            properties: [Property] = [],
            subscripts: [Subscript] = [],
            typealiases: [Typealias] = [],
            annotations: [String: [String]] = [:],
            isExtension: Bool = false,
            comment: String? = nil,
            associatedTypes: [AssociatedType] = [],
            genericRequirements: [GenericRequirement] = []
        ) {
            self.kind = kind
            self.name = name
            self.localName = localName ?? name
            self.accessLevel = accessLevel
            self.inheritedTypes = inheritedTypes
            self.genericParameters = genericParameters
            self.methods = methods
            self.properties = properties
            self.subscripts = subscripts
            self.typealiases = typealiases
            self.annotations = annotations
            self.isExtension = isExtension
            self.comment = comment
            self.associatedTypes = associatedTypes
            self.genericRequirements = genericRequirements
        }

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
