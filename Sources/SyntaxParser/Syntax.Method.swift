import Foundation

extension Syntax {
    public struct Method: Hashable {
        public struct Parameter: Hashable {
            public let label: String?
            public let name: String
            public let type: String?
            public let resolvedType: String?
            public let `inout`: Bool
            public let isClosure: Bool
            public let isOptional: Bool

            public init(
                label: String?,
                name: String,
                type: String?,
                resolvedType: String? = nil,
                isInout: Bool = false,
                isClosure: Bool = false,
                isOptional: Bool = false
            ) {
                self.label = label
                self.name = name
                self.type = type
                self.resolvedType = resolvedType
                self.`inout` = isInout
                self.isClosure = isClosure
                self.isOptional = isOptional
            }

            public var argumentLabel: String? { label }
            public var typeName: TypeName {
                guard let type else {
                    return TypeName(name: "Unknown")
                }
                return TypeName.parse(type, actualTypeNameString: resolvedType)
            }
        }

        public let name: String
        public let parameters: [Parameter]
        public let returnType: String?
        public let resolvedReturnType: String?
        public let annotations: [String: [String]]
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
        public let genericParameters: [GenericParameter]
        public let genericRequirements: [GenericRequirement]

        public init(
            name: String,
            parameters: [Parameter] = [],
            returnType: String? = nil,
            resolvedReturnType: String? = nil,
            annotations: [String: [String]] = [:],
            accessLevel: String = "internal",
            modifiers: [Modifier] = [],
            attributes: [String: [Attribute]] = [:],
            isAsync: Bool = false,
            throws: Bool = false,
            definedInTypeIsExtension: Bool = false,
            isStatic: Bool = false,
            isClass: Bool = false,
            isInitializer: Bool = false,
            isRequired: Bool = false,
            genericParameters: [GenericParameter] = [],
            genericRequirements: [GenericRequirement] = []
        ) {
            self.name = name
            self.parameters = parameters
            self.returnType = returnType
            self.resolvedReturnType = resolvedReturnType
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
            self.genericParameters = genericParameters
            self.genericRequirements = genericRequirements
        }

        public var shortName: String { name }
        public var callName: String { name.components(separatedBy: "(").first ?? name }
        public var selectorName: String { callName }
        public var unbacktickedCallName: String {
            callName.replacingOccurrences(of: "`", with: "")
        }

        public var returnTypeName: TypeName {
            guard let returnType else {
                return TypeName(name: "Void", isVoid: true)
            }
            return TypeName.parse(returnType, actualTypeNameString: resolvedReturnType)
        }

        public var definedInType: TypeInfo? { nil }

        struct SignatureData: Hashable {
            let name: String
            let parameters: [Parameter]
            let returnType: String?
            let isAsync: Bool
            let `throws`: Bool
            let isStatic: Bool
            let isClass: Bool
        }

        var signatureData: SignatureData {
            SignatureData(
                name: name,
                parameters: parameters,
                returnType: returnType,
                isAsync: isAsync,
                throws: `throws`,
                isStatic: isStatic,
                isClass: isClass
            )
        }
    }
}
