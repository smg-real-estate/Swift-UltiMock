import Foundation

public enum Syntax {
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
        public let extensions: [Extension]
        public let annotations: [String: String]
        public let isExtension: Bool
        public let comment: String?

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
            extensions: [Extension] = [],
            annotations: [String: String] = [:],
            isExtension: Bool = false,
            comment: String? = nil
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
            self.extensions = extensions
            self.annotations = annotations
            self.isExtension = isExtension
            self.comment = comment
        }
    }

    public enum AccessLevel: String, Equatable {
        case `public`
        case `open`
        case `internal`
        case `fileprivate`
        case `private`
        case `package`
    }

    public struct GenericParameter: Equatable {
        public let name: String
        public let constraints: [String]

        public init(name: String, constraints: [String] = []) {
            self.name = name
            self.constraints = constraints
        }
    }

    public struct Method: Equatable {
        public struct Parameter: Equatable {
            public let label: String?
            public let name: String
            public let type: String?

            public init(label: String?, name: String, type: String?) {
                self.label = label
                self.name = name
                self.type = type
            }
        }

        public let name: String
        public let parameters: [Parameter]
        public let returnType: String?
        public let annotations: [String: String]

        public init(
            name: String,
            parameters: [Parameter] = [],
            returnType: String? = nil,
            annotations: [String: String] = [:]
        ) {
            self.name = name
            self.parameters = parameters
            self.returnType = returnType
            self.annotations = annotations
        }
    }

    public struct Property: Equatable {
        public let name: String
        public let type: String?
        public let isVariable: Bool
        public let annotations: [String: String]

        public init(
            name: String,
            type: String?,
            isVariable: Bool = true,
            annotations: [String: String] = [:]
        ) {
            self.name = name
            self.type = type
            self.isVariable = isVariable
            self.annotations = annotations
        }
    }

    public struct Subscript: Equatable {
        public let parameters: [Method.Parameter]
        public let returnType: String?
        public let annotations: [String: String]

        public init(
            parameters: [Method.Parameter],
            returnType: String?,
            annotations: [String: String] = [:]
        ) {
            self.parameters = parameters
            self.returnType = returnType
            self.annotations = annotations
        }
    }

    public struct Typealias: Equatable {
        public let name: String
        public let target: String
        public let annotations: [String: String]

        public init(name: String, target: String, annotations: [String: String] = [:]) {
            self.name = name
            self.target = target
            self.annotations = annotations
        }
    }

    public struct Extension: Equatable {
        public let extendedType: String
        public let inheritedTypes: [String]

        public init(extendedType: String, inheritedTypes: [String] = []) {
            self.extendedType = extendedType
            self.inheritedTypes = inheritedTypes
        }
    }
}
