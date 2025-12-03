import SwiftSyntax

struct MockedProtocol: MockedType, Equatable {
    let declaration: ProtocolDeclSyntax
    let inherited: [ProtocolDeclSyntax]
}
