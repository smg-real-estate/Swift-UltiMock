import Foundation
import SwiftSyntax

enum Syntax {
    struct TypeInfo: Equatable {
        public internal(set) var scope: [String]
        public internal(set) var declaration: DeclSyntax
    }
}
