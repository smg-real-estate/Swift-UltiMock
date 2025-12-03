import SwiftParser
import SwiftSyntax
import Testing
@testable import SyntaxParser

final class MockedTypesResolverTests {
    var typeAliases: [String: [String: TypeAliasDeclSyntax]] = [:]
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
            func doSomething(with value: Int) -> String
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

    @Test func `resolves multi-level class inheritance`() {
        let types = TypesCollector().collect(from: """
        class A {
            func doSomething()
        }

        class B: A {
            func doSomethingElse()
        }

        // UltiMock:AutoMockable
        class C: B {
            func doMore()
        }
        """)

        let resolved = sut.resolve(types)

        #expect(casted(resolved) == [
            MockedClass(
                declaration: types[2].declaration.cast(ClassDeclSyntax.self),
                superclasses: [
                    types[1].declaration.cast(ClassDeclSyntax.self),
                    types[0].declaration.cast(ClassDeclSyntax.self)
                ],
                protocols: []
            )
        ])
    }

    @Test func `resolves class with multiple protocols`() {
        let types = TypesCollector().collect(from: """
        protocol A {
            func doSomething()
        }

        protocol B {
            func doSomethingElse()
        }

        // UltiMock:AutoMockable
        class C: A, B {
            func doSomething() {}
            func doSomethingElse() {}
        }
        """)

        let resolved = sut.resolve(types)

        #expect(casted(resolved) == [
            MockedClass(
                declaration: types[2].declaration.cast(ClassDeclSyntax.self),
                superclasses: [],
                protocols: [
                    types[0].declaration.cast(ProtocolDeclSyntax.self),
                    types[1].declaration.cast(ProtocolDeclSyntax.self)
                ]
            )
        ])
    }

    @Test func `resolves transitive protocols from class protocol conformance`() {
        let types = TypesCollector().collect(from: """
        protocol A {
            func doSomething()
        }

        protocol B: A {
            func doSomethingElse()
        }

        // UltiMock:AutoMockable
        class C: B {
            func doSomething() {}
            func doSomethingElse() {}
        }
        """)

        let resolved = sut.resolve(types)

        #expect(casted(resolved) == [
            MockedClass(
                declaration: types[2].declaration.cast(ClassDeclSyntax.self),
                superclasses: [],
                protocols: [
                    types[1].declaration.cast(ProtocolDeclSyntax.self),
                    types[0].declaration.cast(ProtocolDeclSyntax.self)
                ]
            )
        ])
    }

    @Test func `resolves protocols from superclasses`() {
        let types = TypesCollector().collect(from: """
        protocol A {
            func doSomething()
        }

        protocol B {
            func doSomethingElse()
        }

        class Parent: A, B {
            func doSomething() {}
            func doSomethingElse() {}
        }

        // UltiMock:AutoMockable
        class Child: Parent {
            func doMore() {}
        }
        """)

        let resolved = sut.resolve(types)

        #expect(casted(resolved) == [
            MockedClass(
                declaration: types[3].declaration.cast(ClassDeclSyntax.self),
                superclasses: [
                    types[2].declaration.cast(ClassDeclSyntax.self)
                ],
                protocols: [
                    types[0].declaration.cast(ProtocolDeclSyntax.self),
                    types[1].declaration.cast(ProtocolDeclSyntax.self)
                ]
            )
        ])
    }

    @Test func `resolves aliased types`() throws {
        let source = Parser.parse(source: """
            class Parent {
                func doSomething() {}
            }

            typealias ParentAlias = Parent
            typealias Count = Int

            // UltiMock:AutoMockable
            class Child: ParentAlias {
                typealias Amount = Double
                func doMore(count: Count) {}
                var count: Count
                var amount: Amount
            }
        """)

        typeAliases = TypeAliasCollector().collect(from: source)

        let types = TypesCollector().collect(from: source)

        let resolved = try #require(sut.resolve(types).first as? MockedClass)

        #expect(resolved.superclasses == [
            types[0].declaration.cast(ClassDeclSyntax.self)
        ])
        #expect(resolved.declaration.trimmedDescription == """
        class Child: Parent {
                func doMore(count: Int) {}
                var count: Int { get set }
                var amount: Double { get set }
            }
        """)
    }
}

func casted<B>(_ value: some Any, to type: B.Type = B.self) -> B? {
    value as? B
}
