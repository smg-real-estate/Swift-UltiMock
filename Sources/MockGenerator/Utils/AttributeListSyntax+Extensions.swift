import SwiftSyntax

extension AttributeListSyntax.Element {
    var attribute: AttributeSyntax? {
        switch self {
        case let .attribute(attribute):
            attribute
        default:
            nil
        }
    }

    var attributeNameKind: TokenKind? {
        attribute?.attributeName.as(IdentifierTypeSyntax.self)?.name.tokenKind
    }
}
