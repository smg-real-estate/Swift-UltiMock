import Foundation

extension Syntax {
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
}
