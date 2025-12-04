//
//  Test.swift
//  UltiMock
//
//  Created by Mykola Tarbaiev on 04.12.25.
//

import Testing
import SwiftParser
@testable import SyntaxParser
import SwiftSyntax

struct MockedProtocolTests {
    @Test func `mock contains correct declaration for simple protocol`() async throws {
        let source = Parser.parse(source: """
        protocol TestProtocol {
            func doSomething() -> Int
        }
        """)

        let declaration = try #require(source.statements.first?.item.as(ProtocolDeclSyntax.self))

        let sut = MockedProtocol(declaration: declaration, inherited: [])

        let mock = sut.mock

        #expect(mock.withoutMembers().description == """
        class TestProtocolMock: Mock, @unchecked Sendable {
        }
        """)
    }

    @Test func `mock contains correct declaration for a protocol with associated types`() async throws {
        let source = Parser.parse(source: """
        protocol TestProtocol {
            associatedtype Item
            associatedtype Identifier: Hashable
        
            func doSomething() -> Int
        }
        """)

        let declaration = try #require(source.statements.first?.item.as(ProtocolDeclSyntax.self))

        let sut = MockedProtocol(declaration: declaration, inherited: [])

        let mock = sut.mock

        #expect(mock.withoutMembers().description == """
        class TestProtocolMock<Item, Identifier: Hashable>: Mock, @unchecked Sendable {
        }
        """)
    }

    @Test func `mock contains declaration with generic parameters from inherited protocol with associated types`() async throws {
        let source = Parser.parse(source: """
        protocol Foo {
            associatedtype Item: Hashable, Codable
            associatedtype Identifier: Hashable
        
            func doSomething() -> Int
        }
        
        protocol Bar: Foo {}
        """)

        let types = source.statements.map { $0.item.cast(ProtocolDeclSyntax.self) }

        let sut = MockedProtocol(declaration: types[1], inherited: [types[0]])

        let mock = sut.mock

        #expect(mock.withoutMembers().description == """
        class BarMock<Item: Hashable & Codable, Identifier: Hashable>: Mock, @unchecked Sendable {
        }
        """)
    }
}

extension ClassDeclSyntax {
    func withoutMembers() -> ClassDeclSyntax {
        with(\.memberBlock.members, [])
    }
}
