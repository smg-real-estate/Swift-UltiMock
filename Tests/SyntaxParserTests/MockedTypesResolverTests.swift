import SwiftSyntax
import Testing
@testable import SyntaxParser

final class MockedTypesResolverTests {
    var typeAliases: [String: [String: AliasDefinition]] = [:]
    lazy var sut = MockedTypesResolver(
        typeAliases: typeAliases
    )

    @Test func `skips types without annotation`() {
        let types = TypesCollector().collect(from: """
        // This is a regular comment
        class MyClass {
            func doSomething() {}
        }

        // This is a regular comment
        protocol MyProtocol {
            func doSomething()
        }
        """)

        #expect(sut.resolve(types).isEmpty)
    }

    @Test(arguments: ["UltiMock", "sourcery"])
    func `resolves types with all supported annotation keys`(annotationKey: String) {
        let types = TypesCollector().collect(from: """
        // \(annotationKey):AutoMockable
        protocol A {
            func doSomething()
        }
        """)

        let resolved = sut.resolve(types)

        #expect(resolved.isEmpty == false)
    }

    @Test func `resolves annotated protocols`() {
        let types = TypesCollector().collect(from: """
        // UltiMock:AutoMockable
        protocol A {
            func doSomething()
        }
        """)

        let resolved = sut.resolve(types)

        #expect(casted(resolved) == [
            MockedProtocol(
                declaration: types[0].declaration.cast(ProtocolDeclSyntax.self),
                inherited: []
            )
        ])
    }

    @Test func `resolves protocols from annotated extensions`() {
        let types = TypesCollector().collect(from: """
        protocol A {
            func doSomething()
        }

        // UltiMock:AutoMockable
        extension A {}
        """)

        let resolved = sut.resolve(types)

        #expect(casted(resolved) == [
            MockedProtocol(
                declaration: types[0].declaration.cast(ProtocolDeclSyntax.self),
                inherited: []
            )
        ])
    }

    @Test func `resolves inherited protocols also in different files`() {
        let types = TypesCollector().collect(from: """
        protocol A {
            func doSomething()
        }

        protocol B: A {
            func doSomethingElse()
        }
        """) + TypesCollector().collect(from: """
        // UltiMock:AutoMockable
        protocol C: B {
            func doSomethingElse()
        }
        """)

        let resolved = sut.resolve(types)

        #expect(casted(resolved) == [
            MockedProtocol(
                declaration: types[2].declaration.cast(ProtocolDeclSyntax.self),
                inherited: [
                    types[1].declaration.cast(ProtocolDeclSyntax.self),
                    types[0].declaration.cast(ProtocolDeclSyntax.self)
                ]
            )
        ])
    }

    @Test func `resolves annotated classes`() {
        let types = TypesCollector().collect(from: """
        // UltiMock:AutoMockable
        class A {
            func doSomething()
        }
        """)

        let resolved = sut.resolve(types)

        #expect(casted(resolved) == [
            MockedClass(
                declaration: types[0].declaration.cast(ClassDeclSyntax.self),
                superclasses: [],
                protocols: []
            )
        ])
    }

    @Test func `resolves classes from annotated extensions`() {
        let types = TypesCollector().collect(from: """
        class A {
            func doSomething()
        }

        // UltiMock:AutoMockable
        extension A {}
        """)

        let resolved = sut.resolve(types)

        #expect(casted(resolved) == [
            MockedClass(
                declaration: types[0].declaration.cast(ClassDeclSyntax.self),
                superclasses: [],
                protocols: []
            )
        ])
    }
}

func casted<B>(_ value: some Any, to type: B.Type = B.self) -> B? {
    value as? B
}
