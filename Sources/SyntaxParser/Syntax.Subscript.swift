import Foundation

public extension Syntax {
    struct Subscript: Hashable {
        public let parameters: [Method.Parameter]
        public let returnType: String
        public let annotations: [String: [String]]
        public let readAccess: String
        public let writeAccess: String
        public let attributes: [String: [Attribute]]

        public init(
            parameters: [Method.Parameter],
            returnType: String,
            annotations: [String: [String]] = [:],
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
    }
}
