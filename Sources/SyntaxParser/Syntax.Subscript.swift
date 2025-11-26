import Foundation

extension Syntax {
    public struct Subscript: Hashable {
        public let parameters: [Method.Parameter]
        public let returnType: String?
        public let resolvedReturnType: String?
        public let annotations: [String: [String]]
        public let readAccess: String
        public let writeAccess: String
        public let attributes: [String: [Attribute]]

        public init(
            parameters: [Method.Parameter],
            returnType: String?,
            resolvedReturnType: String? = nil,
            annotations: [String: [String]] = [:],
            readAccess: String = "internal",
            writeAccess: String = "internal",
            attributes: [String: [Attribute]] = [:]
        ) {
            self.parameters = parameters
            self.returnType = returnType
            self.resolvedReturnType = resolvedReturnType
            self.annotations = annotations
            self.readAccess = readAccess
            self.writeAccess = writeAccess
            self.attributes = attributes
        }

        public var returnTypeName: TypeName {
            guard let returnType else {
                return TypeName(name: "Unknown")
            }
            return TypeName.parse(returnType, actualTypeNameString: resolvedReturnType)
        }
    }
}
