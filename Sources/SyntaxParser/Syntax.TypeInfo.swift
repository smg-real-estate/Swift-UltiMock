import Foundation
import SwiftSyntax

public extension Syntax {
    struct TypeInfo: Equatable {
        public internal(set) var declaration: DeclSyntax
        public internal(set) var methods: [Method] = []
        public internal(set) var properties: [Property] = []
        public internal(set) var subscripts: [Subscript] = []
        public internal(set) var associatedTypes: [AssociatedType] = []
    }
}

extension DeclSyntaxProtocol where Self: SyntaxHashable {
    var declaration: Syntax.TypeInfo {
        .init(declaration: DeclSyntax(self))
    }
}
