import SwiftParser
import SwiftSyntax
import Testing
@testable import MockGenerator

struct MockTypePropertyTests {
    @Test(arguments: [
        ("var property: Int { get }", "property_Int"),
        ("var property: String? { get }", "property_String_opt"),
        ("var property: String! { get }", "property_String_impopt"),
        ("var property: Int { get set }", "property_Int"),
        ("var property: Int { get throws }", "property_throws_Int"),
        ("var property: Int { get async }", "property_async_Int"),
        ("var property: Int { get async throws }", "property_async_throws_Int"),
    ])
    func `stubIdentifier maps non-textual information`(source: String, expectedIdentifier: String) throws {
        let syntax = Parser.parse(source: source).statements.first?.item
        let declaration = try #require(VariableDeclSyntax(syntax))

        let sut = MockType.Property(declaration: declaration, mockName: "TestMock")

        #expect(sut.stubIdentifier == expectedIdentifier)
    }

    @Test func `implementation for readonly`() throws {
        let syntax = Parser.parse(source: "var readonly: Int { get }").statements.first?.item
        let declaration = try #require(VariableDeclSyntax(syntax))

        let sut = MockType.Property(declaration: declaration, mockName: "TestMock")

        #expect(sut.implementation().formatted().description == """
        var readonly: Int {
            get {
                let perform = _perform(
                    Methods.get_\(sut.stubIdentifier)
                ) as! () -> Int
                return perform()
            }
        }
        """)
    }

    @Test func `implementation for readonly throwing`() throws {
        let syntax = Parser.parse(source: "var readonlyThrowing: Double { get throws }").statements.first?.item
        let declaration = try #require(VariableDeclSyntax(syntax))

        let sut = MockType.Property(declaration: declaration, mockName: "TestMock")

        #expect(sut.implementation().formatted().description == """
        var readonlyThrowing: Double {
            get throws {
                let perform = _perform(
                    Methods.get_\(sut.stubIdentifier)
                ) as! () throws -> Double
                return try perform()
            }
        }
        """)
    }

    @Test func `implementation for readonly async`() throws {
        let syntax = Parser.parse(source: "var readonlyAsync: String { get async }").statements.first?.item
        let declaration = try #require(VariableDeclSyntax(syntax))

        let sut = MockType.Property(declaration: declaration, mockName: "TestMock")

        #expect(sut.implementation().formatted().description == """
        var readonlyAsync: String {
            get async {
                let perform = _perform(
                    Methods.get_\(sut.stubIdentifier)
                ) as! () async -> String
                return await perform()
            }
        }
        """)
    }

    @Test func `implementation for readonly async throwing`() throws {
        let syntax = Parser.parse(source: "var readonlyAsyncThrowing: Int { get async throws }").statements.first?.item
        let declaration = try #require(VariableDeclSyntax(syntax))

        let sut = MockType.Property(declaration: declaration, mockName: "TestMock")

        #expect(sut.implementation().formatted().description == """
        var readonlyAsyncThrowing: Int {
            get async throws {
                let perform = _perform(
                    Methods.get_\(sut.stubIdentifier)
                ) as! () async throws -> Int
                return try await perform()
            }
        }
        """)
    }

    @Test func `implementation for readwrite`() throws {
        let syntax = Parser.parse(source: "var readwrite: Int { get set }").statements.first?.item
        let declaration = try #require(VariableDeclSyntax(syntax))

        let sut = MockType.Property(declaration: declaration, mockName: "TestMock")

        #expect(sut.implementation().formatted().description == """
        var readwrite: Int {
            get {
                let perform = _perform(
                    Methods.get_\(sut.stubIdentifier)
                ) as! () -> Int
                return perform()
            }
            set {
                let perform = _perform(
                    Methods.set_\(sut.stubIdentifier),
                    [newValue]
                ) as! (Int) -> Void
                return perform(newValue)
            }
        }
        """)
    }

    @Test func `implementation replaces ! with ? for force-unwrapped type`() throws {
        let syntax = Parser.parse(source: "var readwrite: Int! { get set }").statements.first?.item
        let declaration = try #require(VariableDeclSyntax(syntax))

        let sut = MockType.Property(declaration: declaration, mockName: "TestMock")

        #expect(sut.implementation().formatted().description == """
        var readwrite: Int! {
            get {
                let perform = _perform(
                    Methods.get_\(sut.stubIdentifier)
                ) as! () -> Int?
                return perform()
            }
            set {
                let perform = _perform(
                    Methods.set_\(sut.stubIdentifier),
                    [newValue]
                ) as! (Int?) -> Void
                return perform(newValue)
            }
        }
        """)
    }

    @Test func `getterExpect for async throwing`() throws {
        let syntax = Parser.parse(source: "var readonly: Int! { get async throws }").statements.first?.item
        let declaration = try #require(VariableDeclSyntax(syntax))

        let sut = MockType.Property(declaration: declaration, mockName: "TestMock")

        #expect(sut.getterExpect.formatted().description == """
        public func expect(
            _ expectation: PropertyExpectation<() async throws -> Int?>,
            fileID: String = #fileID,
            filePath: StaticString = #filePath,
            line: UInt = #line,
            column: Int = #column,
            perform: @escaping () async throws -> Int?
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

    @Test func `getterExpect for readwrite`() throws {
        let syntax = Parser.parse(source: "var readwrite: Int! { get set }").statements.first?.item
        let declaration = try #require(VariableDeclSyntax(syntax))

        let sut = MockType.Property(declaration: declaration, mockName: "TestMock")

        #expect(sut.getterExpect.formatted().description == """
        public func expect(
            _ expectation: PropertyExpectation<() -> Int?>,
            fileID: String = #fileID,
            filePath: StaticString = #filePath,
            line: UInt = #line,
            column: Int = #column,
            perform: @escaping () -> Int?
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

    @Test func `setterExpect for readwrite`() throws {
        let syntax = Parser.parse(source: "var readwrite: Int! { get set }").statements.first?.item
        let declaration = try #require(VariableDeclSyntax(syntax))

        let sut = MockType.Property(declaration: declaration, mockName: "TestMock")

        #expect(sut.setterExpect.formatted().description == """
        public func expect(
            set expectation: PropertyExpectation<(Int?) -> Void>,
            to newValue: Parameter<Int?>,
            fileID: String = #fileID,
            filePath: StaticString = #filePath,
            line: UInt = #line,
            column: Int = #column,
            perform: @escaping (Int?) -> Void = { _ in
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
        (true, "public ")
    ]) func `getterExpectationExtension for readonly async throwing`(isPublic: Bool, accessModifier: String) throws {
        let syntax = Parser.parse(source: "var readonly: Int! { get async throws }").statements.first?.item
        let declaration = try #require(VariableDeclSyntax(syntax))

        let sut = MockType.Property(declaration: declaration, mockName: "TestMock")

        #expect(sut.getterExpectationExtension(isPublic: isPublic).formatted().description == """
        \(accessModifier)extension TestMock.PropertyExpectation where Signature == () async throws -> Int? {
            static var readonly: Self {
                .init(method: TestMock.Methods.get_\(sut.stubIdentifier))
            }
        }
        """)
    }

    @Test(arguments: [
        (false, ""),
        (true, "public ")
    ]) func `getterExpectationExtension for readwrite`(isPublic: Bool, accessModifier: String) throws {
        let syntax = Parser.parse(source: "var readwrite: Int! { get set }").statements.first?.item
        let declaration = try #require(VariableDeclSyntax(syntax))

        let sut = MockType.Property(declaration: declaration, mockName: "TestMock")

        #expect(sut.getterExpectationExtension(isPublic: isPublic).formatted().description == """
        \(accessModifier)extension TestMock.PropertyExpectation where Signature == () -> Int? {
            static var readwrite: Self {
                .init(method: TestMock.Methods.get_\(sut.stubIdentifier))
            }
        }
        """)
    }

    @Test(arguments: [
        (false, ""),
        (true, "public ")
    ]) func `setterExpectationExtension for readwrite`(isPublic: Bool, accessModifier: String) throws {
        let syntax = Parser.parse(source: "var readwrite: Int! { get set }").statements.first?.item
        let declaration = try #require(VariableDeclSyntax(syntax))

        let sut = MockType.Property(declaration: declaration, mockName: "TestMock")

        #expect(sut.setterExpectationExtension(isPublic: isPublic)?.formatted().description == """
        \(accessModifier)extension TestMock.PropertyExpectation where Signature == (Int?) -> Void {
            static var readwrite: Self {
                .init(method: TestMock.Methods.set_\(sut.stubIdentifier))
            }
        }
        """)
    }
}
