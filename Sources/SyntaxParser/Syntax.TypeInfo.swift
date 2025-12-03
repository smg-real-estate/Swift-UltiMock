import Foundation
import SwiftSyntax

public extension Syntax {
    struct TypeInfo: Equatable {
        public internal(set) var scope: [String]
        public internal(set) var declaration: DeclSyntax
    }
}
