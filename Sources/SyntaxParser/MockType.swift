import SwiftSyntax

struct MockType {
    let declaration: DeclSyntax

    init?(_ typeInfo: Syntax.TypeInfo, annotationKeys: [String] = ["sourcery", "UltiMock"]) {
        let hasAnnotation = typeInfo.declaration.leadingTrivia.contains { piece in
            if case .lineComment(let comment) = piece {
                return annotationKeys.contains { key in
                    comment.contains("\(key):AutoMockable")
                }
            }
            if case .blockComment(let comment) = piece {
                return annotationKeys.contains { key in
                    comment.contains("\(key):AutoMockable")
                }
            }
            return false
        }

        guard hasAnnotation else { return nil }
        self.declaration = typeInfo.declaration
    }
}
