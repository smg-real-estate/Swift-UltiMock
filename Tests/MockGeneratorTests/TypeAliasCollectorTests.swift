import SwiftParser
import Testing
@testable import MockGenerator

struct TypeAliasCollectorTests {
    let sut = TypeAliasCollector()

    @Test func `collects namespaced aliases`() {
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

        #expect(aliases[""]?["A"]?.name.text == "A")
        #expect(aliases[""]?["A"]?.initializer.value.trimmedDescription == "Int")
        #expect(aliases[""]?["A"]?.genericParameterClause?.parameters.map(\.name.text) == nil)

        #expect(aliases[""]?["B"]?.name.text == "B")
        #expect(aliases[""]?["B"]?.initializer.value.trimmedDescription == "A")

        #expect(aliases[""]?["C"]?.name.text == "C")
        #expect(aliases[""]?["C"]?.initializer.value.trimmedDescription == "[T]")
        #expect(aliases[""]?["C"]?.genericParameterClause?.parameters.map(\.name.text) == ["T"])

        #expect(aliases["Struct"]?["B"]?.name.text == "B")
        #expect(aliases["Struct"]?["B"]?.initializer.value.trimmedDescription == "Double")

        #expect(aliases["Struct"]?["G"]?.name.text == "G")
        #expect(aliases["Struct"]?["G"]?.initializer.value.trimmedDescription == "Character")

        #expect(aliases["Struct.Enum"]?["D"]?.name.text == "D")
        #expect(aliases["Struct.Enum"]?["D"]?.initializer.value.trimmedDescription == "String")

        #expect(aliases["Enum"]?["D"]?.name.text == "D")
        #expect(aliases["Enum"]?["D"]?.initializer.value.trimmedDescription == "String")

        #expect(aliases["Class"]?["E"]?.name.text == "E")
        #expect(aliases["Class"]?["E"]?.initializer.value.trimmedDescription == "Float")

        #expect(aliases["Protocol"]?["F"]?.name.text == "F")
        #expect(aliases["Protocol"]?["F"]?.initializer.value.trimmedDescription == "Bool")
    }
}
