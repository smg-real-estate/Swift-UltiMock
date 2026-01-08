import SwiftSyntax

struct MockedProtocol: MockedType, Equatable {
    let declaration: ProtocolDeclSyntax
    let inherited: [ProtocolDeclSyntax]

    var mockSyntax: CodeBlockItemListSyntax {
        let builder = ProtocolMockBuilder(self)

        return [
            builder.mockClass.asCodeBlockItem(),
        ] + builder.extensions
    }

    var allProtocols: [ProtocolDeclSyntax] {
        inherited + [declaration]
    }
}

extension DeclSyntaxProtocol {
    func asCodeBlockItem() -> CodeBlockItemSyntax {
        CodeBlockItemSyntax(item: .init(self))
    }
}
