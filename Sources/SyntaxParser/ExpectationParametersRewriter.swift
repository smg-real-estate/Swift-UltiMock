import SwiftSyntax

final class ExpectationParametersRewriter: SyntaxRewriter, SyntaxBuilder {
    let mockName: String

    init(mockName: String) {
        self.mockName = mockName
        super.init(viewMode: .fixedUp)
    }

    override func visit(_ node: FunctionParameterSyntax) -> FunctionParameterSyntax {
        var copy = node
        copy.type = IdentifierTypeSyntax(
            name: .identifier("Parameter"),
            genericArgumentClause: genericArgumentClause(arguments: [node.type])
        ).cast(TypeSyntax.self)
        return copy
    }
}
