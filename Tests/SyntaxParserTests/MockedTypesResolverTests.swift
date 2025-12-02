//
//  Test.swift
//  UltiMock
//
//  Created by Mykola Tarbaiev on 02.12.25.
//

import Testing
@testable import SyntaxParser
import SwiftSyntax

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
                declaration: types[0].declaration.cast(ProtocolDeclSyntax.self)
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
                declaration: types[0].declaration.cast(ProtocolDeclSyntax.self)
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
                declaration: types[0].declaration.cast(ClassDeclSyntax.self)
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
                declaration: types[0].declaration.cast(ClassDeclSyntax.self)
            )
        ])
    }
}

func casted<A, B>(_ value: A, to type: B.Type = B.self) -> B? {
    value as? B
}

