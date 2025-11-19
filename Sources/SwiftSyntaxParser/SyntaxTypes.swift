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
            extensions: [Extension] = [],
            annotations: [String: String] = [:],
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
            self.extensions = extensions
            self.annotations = annotations
            self.isExtension = isExtension
            self.comment = comment
            self.associatedTypes = associatedTypes
            self.genericRequirements = genericRequirements
        }
        
        // Computed properties for template compatibility
        public var allMethods: [Method] { methods }
        public var allVariables: [Property] { properties }
        public var allSubscripts: [Subscript] { subscripts }
        public var based: [String: String] {
            inheritedTypes.reduce(into: [:]) { result, type in
                result[type] = type
            }
        }
        public var implements: [String: TypeInfo] {
            // Simplified - returns empty. In full SourceryRuntime this would resolve inherited protocol types
            [:]
        }
        public var supertype: TypeInfo? {
            // Simplified - would need type resolution to implement properly
            nil
        }
    }
    
    public struct AssociatedType: Equatable {
        public let name: String
        public let typeNameString: String?
        
        public init(name: String, typeNameString: String? = nil) {
            self.name = name
            self.typeNameString = typeNameString
        }
        
        public var typeName: TypeName? {
            typeNameString.map { TypeName(name: $0) }
        }
    }
    
    public struct GenericRequirement: Equatable {
        public let leftTypeName: String
        public let rightTypeName: String
        public let relationshipSyntax: String
        
        public init(leftTypeName: String, rightTypeName: String, relationshipSyntax: String) {
            self.leftTypeName = leftTypeName
            self.rightTypeName = rightTypeName
            self.relationshipSyntax = relationshipSyntax
        }
        
        public var leftType: TypeName {
            TypeName(name: leftTypeName)
        }
        
        public var rightType: TypeNameContainer {
            TypeNameContainer(typeName: TypeName(name: rightTypeName))
        }
    }
    
    public struct TypeNameContainer: Equatable {
        public let typeName: TypeName
        
        public init(typeName: TypeName) {
            self.typeName = typeName
        }
    }
    
    public struct TypeName: Equatable {
        public let name: String
        public let isOptional: Bool
        public let isImplicitlyUnwrappedOptional: Bool
        public let unwrappedTypeName: String
        public let actualTypeNameString: String?
        public let isVoid: Bool
        public let isClosure: Bool
        public let closureDescription: String?
        public let attributes: [Attribute]
        
        public init(
            name: String,
            isOptional: Bool = false,
            isImplicitlyUnwrappedOptional: Bool = false,
            unwrappedTypeName: String? = nil,
            actualTypeNameString: String? = nil,
            isVoid: Bool = false,
            isClosure: Bool = false,
            closureDescription: String? = nil,
            attributes: [Attribute] = []
        ) {
            self.name = name
            self.isOptional = isOptional
            self.isImplicitlyUnwrappedOptional = isImplicitlyUnwrappedOptional
            self.unwrappedTypeName = unwrappedTypeName ?? name.replacingOccurrences(of: "?", with: "").replacingOccurrences(of: "!", with: "")
            self.actualTypeNameString = actualTypeNameString
            self.isVoid = isVoid || name == "Void" || name == "()"
            self.isClosure = isClosure
            self.closureDescription = closureDescription
            self.attributes = attributes
        }
        
        public var actualTypeName: TypeName? {
            actualTypeNameString.map { TypeName(name: $0) }
        }
        
        public var closure: ClosureType? {
            guard isClosure, let desc = closureDescription else { return nil }
            return ClosureType(description: desc)
        }
        
        public var fixedName: String { name }
        public var asSource: String { name }
    }
    
    public struct ClosureType: Equatable {
        public let description: String
        
        public init(description: String) {
            self.description = description
        }
        
        public var asFixedSource: String { description }
    }
    
    public struct Attribute: Equatable {
        public let name: String
        public let arguments: [String: String]
        public let description: String
        
        public init(name: String, arguments: [String: String] = [:], description: String? = nil) {
            self.name = name
            self.arguments = arguments
            self.description = description ?? "@\(name)"
        }
        
        public var key: String { name }
        public var value: [Attribute] { [self] }
        public var asSource: String { description }
    }
    
    public struct Modifier: Equatable {
        public let name: String
        
        public init(name: String) {
            self.name = name
        }
    }

    public enum AccessLevel: String, Equatable, Sendable {
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
            public let `inout`: Bool
            public let isClosure: Bool
            public let isOptional: Bool

            public init(
                label: String?,
                name: String,
                type: String?,
                isInout: Bool = false,
                isClosure: Bool = false,
                isOptional: Bool = false
            ) {
                self.label = label
                self.name = name
                self.type = type
                self.`inout` = isInout
                self.isClosure = isClosure
                self.isOptional = isOptional
            }
            
            public var argumentLabel: String? { label }
            public var typeName: TypeName {
                TypeName(name: type ?? "Unknown", isOptional: isOptional, isClosure: isClosure)
            }
        }

        public let name: String
        public let parameters: [Parameter]
        public let returnType: String?
        public let annotations: [String: String]
        public let accessLevel: String
        public let modifiers: [Modifier]
        public let attributes: [String: [Attribute]]
        public let isAsync: Bool
        public let `throws`: Bool
        public let definedInTypeIsExtension: Bool
        public let isStatic: Bool
        public let isClass: Bool
        public let isInitializer: Bool
        public let isRequired: Bool

        public init(
            name: String,
            parameters: [Parameter] = [],
            returnType: String? = nil,
            annotations: [String: String] = [:],
            accessLevel: String = "internal",
            modifiers: [Modifier] = [],
            attributes: [String: [Attribute]] = [:],
            isAsync: Bool = false,
            throws: Bool = false,
            definedInTypeIsExtension: Bool = false,
            isStatic: Bool = false,
            isClass: Bool = false,
            isInitializer: Bool = false,
            isRequired: Bool = false
        ) {
            self.name = name
            self.parameters = parameters
            self.returnType = returnType
            self.annotations = annotations
            self.accessLevel = accessLevel
            self.modifiers = modifiers
            self.attributes = attributes
            self.isAsync = isAsync
            self.throws = `throws`
            self.definedInTypeIsExtension = definedInTypeIsExtension
            self.isStatic = isStatic
            self.isClass = isClass
            self.isInitializer = isInitializer
            self.isRequired = isRequired
        }
        
        public var shortName: String { name }
        public var callName: String { name.components(separatedBy: "(").first ?? name }
        public var selectorName: String { callName }
        public var unbacktickedCallName: String {
            callName.replacingOccurrences(of: "`", with: "")
        }
        public var returnTypeName: TypeName {
            TypeName(name: returnType ?? "Void", isVoid: returnType == nil || returnType == "Void" || returnType == "()")
        }
        public var definedInType: TypeInfo? { nil }
    }

    public struct Property: Equatable {
        public let name: String
        public let type: String?
        public let isVariable: Bool
        public let annotations: [String: String]
        public let readAccess: String
        public let writeAccess: String
        public let attributes: [String: [Attribute]]
        public let isAsync: Bool
        public let `throws`: Bool
        public let definedInTypeIsExtension: Bool
        public let isStatic: Bool

        public init(
            name: String,
            type: String?,
            isVariable: Bool = true,
            annotations: [String: String] = [:],
            readAccess: String = "internal",
            writeAccess: String = "internal",
            attributes: [String: [Attribute]] = [:],
            isAsync: Bool = false,
            throws: Bool = false,
            definedInTypeIsExtension: Bool = false,
            isStatic: Bool = false
        ) {
            self.name = name
            self.type = type
            self.isVariable = isVariable
            self.annotations = annotations
            self.readAccess = readAccess
            self.writeAccess = writeAccess
            self.attributes = attributes
            self.isAsync = isAsync
            self.throws = `throws`
            self.definedInTypeIsExtension = definedInTypeIsExtension
            self.isStatic = isStatic
        }
        
        public var typeName: TypeName {
            TypeName(name: type ?? "Unknown")
        }
        public var definedInType: TypeInfo? { nil }
        public var unbacktickedName: String {
            name.replacingOccurrences(of: "`", with: "")
        }
    }

    public struct Subscript: Equatable {
        public let parameters: [Method.Parameter]
        public let returnType: String?
        public let annotations: [String: String]
        public let readAccess: String
        public let writeAccess: String
        public let attributes: [String: [Attribute]]

        public init(
            parameters: [Method.Parameter],
            returnType: String?,
            annotations: [String: String] = [:],
            readAccess: String = "internal",
            writeAccess: String = "internal",
            attributes: [String: [Attribute]] = [:]
        ) {
            self.parameters = parameters
            self.returnType = returnType
            self.annotations = annotations
            self.readAccess = readAccess
            self.writeAccess = writeAccess
            self.attributes = attributes
        }
        
        public var returnTypeName: TypeName {
            TypeName(name: returnType ?? "Unknown")
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
