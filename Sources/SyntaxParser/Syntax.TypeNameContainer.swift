import Foundation

public extension Syntax {
    struct TypeNameContainer: Equatable {
        public let typeName: TypeName

        public init(typeName: TypeName) {
            self.typeName = typeName
        }
    }
}
