import SwiftSyntax

struct MockType {
    let declaration: DeclSyntax

    init(_ typeInfo: Syntax.TypeInfo) {
        self.declaration = typeInfo.declaration
    }

    struct Method {
        let declaration: FunctionDeclSyntax

        var stubIdentifier: String {
            ""
        }
    }
}
