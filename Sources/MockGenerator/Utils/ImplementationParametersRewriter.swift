import SwiftSyntax

final class ImplementationParametersRewriter: SyntaxRewriter, SyntaxBuilder {
    let mockName: String

    init(mockName: String) {
        self.mockName = mockName
        super.init(viewMode: .fixedUp)
    }

    override func visit(_ node: FunctionParameterSyntax) -> FunctionParameterSyntax {
        let rewritten = super.visit(node)

        if let secondNameText = rewritten.secondName?.text,
           keywordsToEscape.contains(secondNameText),
           !secondNameText.hasPrefix("`") {
            return rewritten.with(\.secondName, .identifier("`\(secondNameText)`"))
        }

        return rewritten
    }

    override func visit(_ token: TokenSyntax) -> TokenSyntax {
        if token.tokenKind == .keyword(.Self) {
            .identifier(mockName)
        } else {
            super.visit(token)
        }
    }
}

extension FunctionDeclSyntax {
    func withImplementationParameters(mockName: String) -> FunctionDeclSyntax {
        let rewriter = ImplementationParametersRewriter(mockName: mockName)
        let parameters = signature.parameterClause.parameters

        return with(\.signature.parameterClause.parameters, FunctionParameterListSyntax(
            parameters.map {
                rewriter.rewrite($0).as(FunctionParameterSyntax.self)!
            }
        ))
    }
}
