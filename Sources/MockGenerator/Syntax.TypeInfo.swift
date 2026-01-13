import Foundation
import SwiftSyntax

enum Syntax {
    struct TypeInfo: Equatable {
        var scope: [String]
        var declaration: DeclSyntax
    }
}
