import SwiftSyntax

struct MockType {
    let mockedType: Syntax.TypeInfo

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
        self.mockedType = typeInfo
    }

    var declaration: ClassDeclSyntax {
        fatalError()
    }
}
