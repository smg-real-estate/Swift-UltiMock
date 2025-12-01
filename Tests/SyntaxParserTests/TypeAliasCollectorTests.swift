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
            typealias C<T> = [T]
        
            struct Struct {
                typealias B = Double
        
                enum Enum {
                    typealias D = String
                }
            }
        
            enum Enum {
                typealias D = String
            }
        
            class Class {
                typealias E = Float
            }
        
            protocol Protocol {
                typealias F = Bool
            }
        
            extension Struct {
                typealias G = Character
            }
        """)

        let aliases = sut.collect(from: source)

        #expect(aliases == [
            "" : [
                "A" : AliasDefinition(name: "A", genericParameters: [], text: "Int"),
                "B" : AliasDefinition(name: "B", genericParameters: [], text: "A"),
                "C" : AliasDefinition(name: "C", genericParameters: ["T"], text: "[T]"),
            ],
            "Struct" : [
                "B" : AliasDefinition(name: "B", genericParameters: [], text: "Double"),
                "G" : AliasDefinition(name: "G", genericParameters: [], text: "Character")
            ],
            "Struct.Enum" : [
                "D" : AliasDefinition(name: "D", genericParameters: [], text: "String")
            ],
            "Enum" : [
                "D" : AliasDefinition(name: "D", genericParameters: [], text: "String")
            ],
            "Class" : [
                "E" : AliasDefinition(name: "E", genericParameters: [], text: "Float")
            ],
            "Protocol" : [
                "F" : AliasDefinition(name: "F", genericParameters: [], text: "Bool")
            ]
        ])
    }

}
