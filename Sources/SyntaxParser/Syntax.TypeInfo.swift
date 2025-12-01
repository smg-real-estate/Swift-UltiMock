import Foundation
import SwiftSyntax

public extension Syntax {
    struct TypeInfo: Equatable {
        public internal(set) var scope: [String]
        public internal(set) var declaration: DeclSyntax
        public internal(set) var initializers: [InitializerDeclSyntax] = []
        public internal(set) var methods: [FunctionDeclSyntax] = []
        public internal(set) var properties: [VariableDeclSyntax] = []
        public internal(set) var subscripts: [SubscriptDeclSyntax] = []
        public internal(set) var associatedTypes: [AssociatedtypeDeclSyntax] = []
    }
}
