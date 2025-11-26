import Foundation

extension Syntax {
    public struct TypeNameContainer: Equatable {
        public let typeName: TypeName

        public init(typeName: TypeName) {
            self.typeName = typeName
        }
    }
}
