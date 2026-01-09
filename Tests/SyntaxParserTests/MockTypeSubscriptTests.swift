import SwiftParser
import SwiftSyntax
import Testing
@testable import SyntaxParser

struct MockTypeSubscriptTests {
    @Test(arguments: [
        ("subscript(key: Int) -> String { get }", "subscript_get_key_key_Int_String"),
        ("subscript(key: Int) -> String { get set }", "subscript_get_key_key_Int_String"),
        ("subscript(key: String) -> Int? { get }", "subscript_get_key_key_String_Int_opt"),
        ("subscript(key: String!) -> Int! { get set }", "subscript_get_key_key_String_impopt_Int_impopt"),
        ("subscript(_ index: Int) -> String { get }", "subscript_get___index_Int_String"),
        ("subscript(key: Int, secondary: String) -> Bool { get }", "subscript_get_key_key_Int_secondary_secondary_String_Bool"),
    ])
    func `getterStubIdentifier maps subscript correctly`(source: String, expectedIdentifier: String) throws {
        let syntax = Parser.parse(source: source).statements.first?.item
        let declaration = try #require(SubscriptDeclSyntax(syntax))

        let sut = MockType.Subscript(declaration: declaration, mockName: "TestMock")

        #expect(sut.getterStubIdentifier == expectedIdentifier)
    }

    @Test(arguments: [
        ("subscript(key: Int) -> String { get set }", "subscript_set_key_key_Int_String"),
        ("subscript(_ index: Int) -> String { get set }", "subscript_set___index_Int_String"),
    ])
    func `setterStubIdentifier maps subscript correctly`(source: String, expectedIdentifier: String) throws {
        let syntax = Parser.parse(source: source).statements.first?.item
        let declaration = try #require(SubscriptDeclSyntax(syntax))

        let sut = MockType.Subscript(declaration: declaration, mockName: "TestMock")

        #expect(sut.setterStubIdentifier == expectedIdentifier)
    }

    @Test func `callDescription for single parameter`() throws {
        let syntax = Parser.parse(source: "subscript(key: Int) -> String { get }").statements.first?.item
        let declaration = try #require(SubscriptDeclSyntax(syntax))

        let sut = MockType.Subscript(declaration: declaration, mockName: "TestMock")

        #expect(sut.callDescription == #"[key: \($0[0] ?? "nil")]"#)
    }

    @Test func `callDescription for anonymous parameter`() throws {
        let syntax = Parser.parse(source: "subscript(_ index: Int) -> String { get }").statements.first?.item
        let declaration = try #require(SubscriptDeclSyntax(syntax))

        let sut = MockType.Subscript(declaration: declaration, mockName: "TestMock")

        #expect(sut.callDescription == #"[\($0[0] ?? "nil")]"#)
    }

    @Test func `callDescription for multiple parameters`() throws {
        let syntax = Parser.parse(source: "subscript(key: Int, secondary: String) -> Bool { get }").statements.first?.item
        let declaration = try #require(SubscriptDeclSyntax(syntax))

        let sut = MockType.Subscript(declaration: declaration, mockName: "TestMock")

        #expect(sut.callDescription == #"[key: \($0[0] ?? "nil"), secondary: \"\($0[1] ?? "nil")\"]"#)
    }

    @Test func `implementation for readonly subscript`() throws {
        let syntax = Parser.parse(source: "subscript(key: Int) -> String { get }").statements.first?.item
        let declaration = try #require(SubscriptDeclSyntax(syntax))

        let sut = MockType.Subscript(declaration: declaration, mockName: "TestMock")

        #expect(sut.implementation().formatted().description == """
        subscript(key: Int) -> String  {
            get {
                let perform = _perform(
                    Methods.\(sut.getterStubIdentifier),
                    [key]
                ) as! (Int) -> String
                return perform(key)
            }
        }
        """)
    }

    @Test func `implementation for readwrite subscript`() throws {
        let syntax = Parser.parse(source: "subscript(key: Int) -> String { get set }").statements.first?.item
        let declaration = try #require(SubscriptDeclSyntax(syntax))

        let sut = MockType.Subscript(declaration: declaration, mockName: "TestMock")

        #expect(sut.implementation().formatted().description == """
        subscript(key: Int) -> String  {
            get {
                let perform = _perform(
                    Methods.\(sut.getterStubIdentifier),
                    [key]
                ) as! (Int) -> String
                return perform(key)
            }
            set {
                let perform = _perform(
                    Methods.\(sut.setterStubIdentifier),
                    [key, newValue]
                ) as! (Int, String) -> Void
                return perform(key, newValue)
            }
        }
        """)
    }

    @Test func `implementation for anonymous parameter subscript`() throws {
        let syntax = Parser.parse(source: "subscript(_ index: Int) -> String { get }").statements.first?.item
        let declaration = try #require(SubscriptDeclSyntax(syntax))

        let sut = MockType.Subscript(declaration: declaration, mockName: "TestMock")

        #expect(sut.implementation().formatted().description == """
        subscript(_ index: Int) -> String  {
            get {
                let perform = _perform(
                    Methods.\(sut.getterStubIdentifier),
                    [index]
                ) as! (Int) -> String
                return perform(index)
            }
        }
        """)
    }

    @Test func `implementation replaces implicit optional with optional`() throws {
        let syntax = Parser.parse(source: "subscript(key: Int) -> String! { get set }").statements.first?.item
        let declaration = try #require(SubscriptDeclSyntax(syntax))

        let sut = MockType.Subscript(declaration: declaration, mockName: "TestMock")

        #expect(sut.implementation().formatted().description == """
        subscript(key: Int) -> String!  {
            get {
                let perform = _perform(
                    Methods.\(sut.getterStubIdentifier),
                    [key]
                ) as! (Int) -> String?
                return perform(key)
            }
            set {
                let perform = _perform(
                    Methods.\(sut.setterStubIdentifier),
                    [key, newValue]
                ) as! (Int, String?) -> Void
                return perform(key, newValue)
            }
        }
        """)
    }

    @Test func `getterVariableDeclaration generates correct method stub`() throws {
        let syntax = Parser.parse(source: "subscript(key: Int) -> String { get }").statements.first?.item
        let declaration = try #require(SubscriptDeclSyntax(syntax))

        let sut = MockType.Subscript(declaration: declaration, mockName: "TestMock")

        #expect(sut.getterVariableDeclaration.formatted().description == """

        static var \(sut.getterStubIdentifier): MockMethod {
            .init {
                "[key: \\($0 [0] ?? "nil")]"
            }
        }
        """)
    }

    @Test func `setterVariableDeclaration generates correct method stub`() throws {
        let syntax = Parser.parse(source: "subscript(key: Int) -> String { get set }").statements.first?.item
        let declaration = try #require(SubscriptDeclSyntax(syntax))

        let sut = MockType.Subscript(declaration: declaration, mockName: "TestMock")

        #expect(sut.setterVariableDeclaration?.formatted().description == """

        static var \(sut.setterStubIdentifier): MockMethod {
            .init {
                "[key: \\($0 [0] ?? "nil")] = \\"\\($0.last! ?? "nil")\\""
            }
        }
        """)
    }

    @Test func `setterVariableDeclaration returns nil for readonly subscript`() throws {
        let syntax = Parser.parse(source: "subscript(key: Int) -> String { get }").statements.first?.item
        let declaration = try #require(SubscriptDeclSyntax(syntax))

        let sut = MockType.Subscript(declaration: declaration, mockName: "TestMock")

        #expect(sut.setterVariableDeclaration == nil)
    }

    @Test func `getterExpect generates correct expect function`() throws {
        let syntax = Parser.parse(source: "subscript(key: Int) -> String { get }").statements.first?.item
        let declaration = try #require(SubscriptDeclSyntax(syntax))

        let sut = MockType.Subscript(declaration: declaration, mockName: "TestMock")

        #expect(sut.getterExpect.formatted().description == """
        public func expect(
            _ expectation: SubscriptExpectation<(Int) -> String >,
            fileID: String = #fileID,
            filePath: StaticString = #filePath,
            line: UInt = #line,
            column: Int = #column,
            perform: @escaping (Int) -> String
        ) {
            _record(
                expectation.getterExpectation,
                fileID,
                filePath,
                line,
                column,
                perform
            )
        }
        """)
    }

    @Test func `setterExpect generates correct expect function`() throws {
        let syntax = Parser.parse(source: "subscript(key: Int) -> String { get set }").statements.first?.item
        let declaration = try #require(SubscriptDeclSyntax(syntax))

        let sut = MockType.Subscript(declaration: declaration, mockName: "TestMock")

        #expect(sut.setterExpect.formatted().description == """
        public func expect(
            set expectation: SubscriptExpectation<(Int, String) -> Void>,
            to newValue: Parameter<String >,
            fileID: String = #fileID,
            filePath: StaticString = #filePath,
            line: UInt = #line,
            column: Int = #column,
            perform: @escaping (Int, String) -> Void = { _, _ in
            }
        ) {
            _record(
                expectation.setterExpectation(newValue.anyParameter),
                fileID,
                filePath,
                line,
                column,
                perform
            )
        }
        """)
    }

    @Test(arguments: [
        (false, ""),
        (true, "public "),
    ]) func `subscriptExpectationsSubscript for getter`(isPublic: Bool, accessModifier: String) throws {
        let syntax = Parser.parse(source: "subscript(key: Int) -> String { get }").statements.first?.item
        let declaration = try #require(SubscriptDeclSyntax(syntax))

        let sut = MockType.Subscript(declaration: declaration, mockName: "TestMock")

        #expect(sut.subscriptExpectationsSubscript(isGetter: true, isPublic: isPublic).formatted().description == """
        \(accessModifier)subscript(key: Parameter<Int>) -> TestMock.SubscriptExpectation<(Int) -> String > {
            .init(
                method: Methods.\(sut.getterStubIdentifier),
                parameters: [key.anyParameter]
            )
        }
        """)
    }

    @Test(arguments: [
        (false, ""),
        (true, "public "),
    ]) func `subscriptExpectationsSubscript for setter`(isPublic: Bool, accessModifier: String) throws {
        let syntax = Parser.parse(source: "subscript(key: Int) -> String { get set }").statements.first?.item
        let declaration = try #require(SubscriptDeclSyntax(syntax))

        let sut = MockType.Subscript(declaration: declaration, mockName: "TestMock")

        #expect(sut.subscriptExpectationsSubscript(isGetter: false, isPublic: isPublic).formatted().description == """
        \(accessModifier)subscript(key: Parameter<Int>) -> TestMock.SubscriptExpectation<(Int, String) -> Void> {
            .init(
                method: Methods.\(sut.setterStubIdentifier),
                parameters: [key.anyParameter]
            )
        }
        """)
    }

    @Test func `subscriptExpectationsSubscript for multiple parameters`() throws {
        let syntax = Parser.parse(source: "subscript(key: Int, secondary: String) -> Bool { get }").statements.first?.item
        let declaration = try #require(SubscriptDeclSyntax(syntax))

        let sut = MockType.Subscript(declaration: declaration, mockName: "TestMock")

        #expect(sut.subscriptExpectationsSubscript(isGetter: true, isPublic: true).formatted().description == """
        public subscript(key: Parameter<Int>, secondary: Parameter<String>) -> TestMock.SubscriptExpectation<(Int, String) -> Bool > {
            .init(
                method: Methods.\(sut.getterStubIdentifier),
                parameters: [key.anyParameter, secondary.anyParameter]
            )
        }
        """)
    }

    @Test func `getterFunctionType for single labeled parameter`() throws {
        let syntax = Parser.parse(source: "subscript(key: Int) -> String { get }").statements.first?.item
        let declaration = try #require(SubscriptDeclSyntax(syntax))

        let sut = MockType.Subscript(declaration: declaration, mockName: "TestMock")

        #expect(sut.getterFunctionType.formatted().trimmedDescription == "(Int) -> String")
    }

    @Test func `setterFunctionType for single parameter`() throws {
        let syntax = Parser.parse(source: "subscript(key: Int) -> String { get set }").statements.first?.item
        let declaration = try #require(SubscriptDeclSyntax(syntax))

        let sut = MockType.Subscript(declaration: declaration, mockName: "TestMock")

        #expect(sut.setterFunctionType.formatted().trimmedDescription == "(Int, String) -> Void")
    }

    @Test(arguments: [
        ("subscript(key: String) -> Int { get }", #"[key: \"\($0[0] ?? "nil")\"]"#),
        ("subscript(key: Int) -> String { get }", #"[key: \($0[0] ?? "nil")]"#),
        ("subscript(id: Int, name: String) -> Bool { get }", #"[id: \($0[0] ?? "nil"), name: \"\($0[1] ?? "nil")\"]"#),
    ])
    func `callDescription quotes String key parameters`(source: String, expectedDescription: String) throws {
        let syntax = Parser.parse(source: source).statements.first?.item
        let declaration = try #require(SubscriptDeclSyntax(syntax))

        let sut = MockType.Subscript(declaration: declaration, mockName: "TestMock")

        #expect(sut.callDescription == expectedDescription)
    }

    @Test(arguments: [
        ("subscript(key: Int) -> String { get set }", #"[key: \($0[0] ?? "nil")] = \"\($0.last! ?? "nil")\""#),
        ("subscript(key: String) -> Int { get set }", #"[key: \"\($0[0] ?? "nil")\"] = \($0.last! ?? "nil")"#),
        ("subscript(key: String) -> String { get set }", #"[key: \"\($0[0] ?? "nil")\"] = \"\($0.last! ?? "nil")\""#),
    ])
    func `setterCallDescription quotes String parameters and return values`(source: String, expectedDescription: String) throws {
        let syntax = Parser.parse(source: source).statements.first?.item
        let declaration = try #require(SubscriptDeclSyntax(syntax))

        let sut = MockType.Subscript(declaration: declaration, mockName: "TestMock")

        #expect(sut.setterCallDescription == expectedDescription)
    }
}
