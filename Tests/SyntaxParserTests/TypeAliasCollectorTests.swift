//
//  Test.swift
//  UltiMock
//
//  Created by Mykola Tarbaiev on 28.11.25.
//

import Testing
@testable import SyntaxParser
import SwiftParser

struct TypeAliasCollectorTests {
    let sut = TypeAliasCollector()

    @Test func `collects namespaced aliases`() async throws {
        let source = Parser.parse(source: """
            typealias A = Int
            typealias B = A
        
            enum X {
                typealias B = Double 
            }
        """)

        let aliases = sut.collect(from: source)

        #expect(aliases == [
            "" : [
                "A" : AliasDefinition(name: "A", genericParameters: [], text: "Int"),
                "B" : AliasDefinition(name: "B", genericParameters: [], text: "A")
            ],
            "X" : [
                "B" : AliasDefinition(name: "B", genericParameters: [], text: "Double")
            ]
        ])
    }

}
