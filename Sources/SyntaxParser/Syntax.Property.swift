import Foundation

public extension Syntax {
    struct Property: Hashable {
        public let name: String
        public let type: String?
        public let resolvedType: String?
        public let isVariable: Bool
        public let annotations: [String: [String]]
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
            resolvedType: String? = nil,
            isVariable: Bool = true,
            annotations: [String: [String]] = [:],
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
            self.resolvedType = resolvedType
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
            guard let type else {
                return TypeName(name: "Unknown")
            }
            return TypeName.parse(type, actualTypeNameString: resolvedType)
        }

        public var definedInType: TypeInfo? { nil }
        public var unbacktickedName: String {
            name.replacingOccurrences(of: "`", with: "")
        }
    }
}
