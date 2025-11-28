import SwiftParser
import SwiftSyntax
import Testing
@testable import SyntaxParser

@Suite struct TypesCollectorMembersTests {
    let collector = TypesCollector()

    @Test
    func `collect returns method with simple signature`() throws {
        let source = Parser.parse(source:
            """
            protocol Service {
                func doSomething()
            }
            """
        )

        let types = collector.collect(from: source)
        let type = try #require(types.first)
        #expect(type.methods == [
            Syntax.Method(name: "doSomething")
        ])
    }

    @Test
    func `collect returns method with return type`() throws {
        let source = Parser.parse(source:
            """
            protocol Service {
                func getValue() -> Int
            }
            """
        )

        let types = collector.collect(from: source)
        let type = try #require(types.first)
        #expect(type.methods == [
            Syntax.Method(name: "getValue", returnType: "Int")
        ])
    }

    @Test
    func `collect returns method with single parameter`() throws {
        let source = Parser.parse(source:
            """
            protocol Service {
                func setValue(_ value: Int)
            }
            """
        )

        let types = collector.collect(from: source)
        let type = try #require(types.first)
        #expect(
            type.methods == [
                Syntax.Method(
                    name: "setValue",
                    parameters: [
                        Syntax.Method.Parameter(
                            label: "_",
                            name: "value",
                            type: "Int",
                            isInout: false,
                            isClosure: false,
                            isOptional: false
                        )
                    ]
                )
            ]
        )
    }

    @Test
    func `collect returns method with labeled parameter`() throws {
        let source = Parser.parse(source:
            """
            protocol Service {
                func configure(with value: String)
            }
            """
        )

        let types = collector.collect(from: source)
        let type = try #require(types.first)
        #expect(
            type.methods == [
                Syntax.Method(
                    name: "configure",
                    parameters: [
                        Syntax.Method.Parameter(
                            label: "with",
                            name: "value",
                            type: "String",
                            isInout: false,
                            isClosure: false,
                            isOptional: false
                        )
                    ]
                )
            ]
        )
    }

    @Test
    func `collect returns method with multiple parameters`() throws {
        let source = Parser.parse(source:
            """
            protocol Service {
                func update(id: Int, name: String, isActive: Bool) -> Bool
            }
            """
        )

        let types = collector.collect(from: source)
        let type = try #require(types.first)
        #expect(type.methods == [
            Syntax.Method(
                name: "update",
                parameters: [
                    Syntax.Method.Parameter(label: "id", name: "id", type: "Int",
                                            isInout: false,
                                            isClosure: false,
                                            isOptional: false),
                    Syntax.Method.Parameter(label: "name", name: "name", type: "String",
                                            isInout: false,
                                            isClosure: false,
                                            isOptional: false),
                    Syntax.Method.Parameter(label: "isActive", name: "isActive", type: "Bool",
                                            isInout: false,
                                            isClosure: false,
                                            isOptional: false)
                ],
                returnType: "Bool"
            )
        ])
    }

    @Test
    func `collect returns stored property`() throws {
        let source = Parser.parse(source:
            """
            struct User {
                var name: String
            }
            """
        )

        let types = collector.collect(from: source)
        let type = try #require(types.first)
        #expect(type.properties == [
            Syntax.Property(name: "name", type: "String", isVariable: true)
        ])
    }

    @Test
    func `collect returns constant property`() throws {
        let source = Parser.parse(source:
            """
            struct User {
                let id: Int
            }
            """
        )

        let types = collector.collect(from: source)
        let type = try #require(types.first)
        #expect(type.properties == [
            Syntax.Property(name: "id", type: "Int", isVariable: false, writeAccess: "")
        ])
    }

    @Test
    func `collect returns multiple properties`() throws {
        let source = Parser.parse(source:
            """
            struct User {
                let id: Int
                var name: String
                var email: String
            }
            """
        )

        let types = collector.collect(from: source)
        let type = try #require(types.first)
        #expect(type.properties == [
            Syntax.Property(name: "id", type: "Int", isVariable: false, writeAccess: ""),
            Syntax.Property(name: "name", type: "String", isVariable: true),
            Syntax.Property(name: "email", type: "String", isVariable: true)
        ])
    }

    @Test
    func `collect returns subscript with single parameter`() throws {
        let source = Parser.parse(source:
            """
            struct Container {
                subscript(index: Int) -> String {
                    return ""
                }
            }
            """
        )

        let types = collector.collect(from: source)
        let type = try #require(types.first)
        #expect(type.subscripts == [
            Syntax.Subscript(
                parameters: [
                    Syntax.Method.Parameter(label: "index", name: "index", type: "Int",
                                            isInout: false,
                                            isClosure: false,
                                            isOptional: false)
                ],
                returnType: "String"
            )
        ])
    }

    @Test
    func `collect returns subscript with multiple parameters`() throws {
        let source = Parser.parse(source:
            """
            struct Matrix {
                subscript(row: Int, column: Int) -> Double {
                    return 0.0
                }
            }
            """
        )

        let types = collector.collect(from: source)
        let type = try #require(types.first)
        #expect(type.subscripts == [
            Syntax.Subscript(
                parameters: [
                    Syntax.Method.Parameter(label: "row", name: "row", type: "Int",
                                            isInout: false,
                                            isClosure: false,
                                            isOptional: false),
                    Syntax.Method.Parameter(label: "column", name: "column", type: "Int",
                                            isInout: false,
                                            isClosure: false,
                                            isOptional: false)
                ],
                returnType: "Double"
            )
        ])
    }

    @Test
    func `collect returns protocol with multiple members`() throws {
        let source = Parser.parse(source:
            """
            protocol Repository {
                var count: Int { get }
                func fetch(id: String) -> Item?
                subscript(index: Int) -> Item { get }
                typealias Identifier = String
            }
            """
        )

        let types = collector.collect(from: source)
        let type = try #require(types.first)
        #expect(type.properties == [
            Syntax.Property(name: "count", type: "Int", isVariable: true, writeAccess: "")
        ])
        #expect(type.methods == [
            Syntax.Method(
                name: "fetch",
                parameters: [
                    Syntax.Method.Parameter(label: "id", name: "id", type: "String",
                                            isInout: false,
                                            isClosure: false,
                                            isOptional: false)
                ],
                returnType: "Item?"
            )
        ])
        #expect(type.subscripts == [
            Syntax.Subscript(
                parameters: [
                    Syntax.Method.Parameter(label: "index", name: "index", type: "Int",
                                            isInout: false,
                                            isClosure: false,
                                            isOptional: false)
                ],
                returnType: "Item",
                writeAccess: ""
            )
        ])
    }
}
