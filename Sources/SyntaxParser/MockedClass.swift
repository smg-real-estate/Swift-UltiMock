import SwiftSyntax

struct MockedClass: MockedType, Equatable {
    let declaration: ClassDeclSyntax
    let superclasses: [ClassDeclSyntax]
    let protocols: [ProtocolDeclSyntax]

    var mockSyntax: CodeBlockItemListSyntax {
        []
    }
}
