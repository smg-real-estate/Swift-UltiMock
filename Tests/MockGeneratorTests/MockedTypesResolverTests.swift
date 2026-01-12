import SwiftParser
import SwiftSyntax
import Testing
@testable import MockGenerator

final class MockedTypesResolverTests {
    @Test func `resolves mocked types`() throws {
        let source = """
            // TestAnnotationKey:AutoMockable
            protocol A {
                func closureAliasResult(_ closure: @escaping ClosureAlias<Int>) -> ClosureAlias<Int>
            }

            typealias ClosureAlias<T> = (T) -> Void
        """

        let resolved = try MockedTypesResolver.resolve(
            from: [{ source }],
            annotationKeys: ["TestAnnotationKey"]
        )

        #expect(resolved.count == 1)
    }
}
