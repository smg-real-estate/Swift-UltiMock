import SwiftParser
import SwiftSyntax
import Testing
@testable import MockGenerator

final class MockedTypesResolverTests {
    @Test func `resolves aliased closures`() throws {
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

        let mockedProtocol = try #require(resolved.first as? MockedProtocol)

        #expect(mockedProtocol.declaration.description == """
        // TestAnnotationKey:AutoMockable
        protocol A {
            func closureAliasResult(_ closure: @escaping (Int) -> Void) -> (Int) -> Void
        }
        """)
    }

    @Test func `resolves generic type aliases with parameters`() throws {
        let source = """
        // TestAnnotationKey:AutoMockable
        protocol A {
            func withClosureWithTypeAliasedGeneric<T>(closure: @escaping (Foo<T>) -> Void)
        }

        typealias Foo<X> = Bar<X>
        """

        let resolved = try MockedTypesResolver.resolve(
            from: [{ source }],
            annotationKeys: ["TestAnnotationKey"]
        )

        #expect(resolved.count == 1)

        let mockedProtocol = try #require(resolved.first as? MockedProtocol)

        #expect(mockedProtocol.declaration.description == """
        // TestAnnotationKey:AutoMockable
        protocol A {
            func withClosureWithTypeAliasedGeneric<T>(closure: @escaping (Bar<T>) -> Void)
        }
        """)
    }

    @Test func `resolves generic type aliases without parameters`() throws {
        let source = """
        // TestAnnotationKey:AutoMockable
        protocol A {
            func withClosureWithTypeAliasedGeneric<T>(closure: @escaping (Foo<T>) -> Void)
        }

        typealias Foo = Bar
        """

        let resolved = try MockedTypesResolver.resolve(
            from: [{ source }],
            annotationKeys: ["TestAnnotationKey"]
        )

        #expect(resolved.count == 1)

        let mockedProtocol = try #require(resolved.first as? MockedProtocol)

        #expect(mockedProtocol.declaration.description == """
        // TestAnnotationKey:AutoMockable
        protocol A {
            func withClosureWithTypeAliasedGeneric<T>(closure: @escaping (Bar<T>) -> Void)
        }
        """)
    }
}
