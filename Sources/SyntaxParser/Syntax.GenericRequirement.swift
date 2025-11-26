import Foundation

extension Syntax {
    public struct GenericRequirement: Hashable {
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
}
