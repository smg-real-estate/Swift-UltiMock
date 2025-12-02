import SwiftParser
import SwiftSyntax
import Testing
@testable import SyntaxParser

struct MockTypeTests {
    @Test func `init fails without mock annotation comment`() throws {
        let source = Parser.parse(source: """
        // This is a regular comment
        protocol MyProtocol {
            func doSomething() {}
        }
        """).statements.first?.item

        let declaration = try #require(ProtocolDeclSyntax(source))

        let typeInfo = Syntax.TypeInfo(
            scope: [],
            declaration: DeclSyntax(declaration)
        )

        let mockType = MockType(typeInfo)

        #expect(mockType == nil)
    }

    @Test(arguments: ["foo", "bar"])
    func `init succeeds when type has matching annotation`(annotationKey: String) throws {
        let source = Parser.parse(source: """
        // \(annotationKey):AutoMockable
        protocol MyProtocol {
            func doSomething() {}
        }
        """).statements.first?.item

        let declaration = try #require(ProtocolDeclSyntax(source))

        let typeInfo = Syntax.TypeInfo(
            scope: [],
            declaration: DeclSyntax(declaration)
        )

        let mockType = MockType(typeInfo, annotationKeys: ["foo", "bar"])

        #expect(mockType != nil)
    }

    @Test
    func `declaration`() {}
}
