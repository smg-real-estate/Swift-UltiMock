import Foundation
import SwiftSyntax

enum Syntax {
    struct TypeInfo: Equatable {
        internal(set) var scope: [String]
        internal(set) var declaration: DeclSyntax
    }
}
