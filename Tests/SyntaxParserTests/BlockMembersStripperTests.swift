import SwiftParser
import Testing
@testable import SyntaxParser

struct BlockMembersStripperTests {
    @Test func `strips function implementation`() {
        let source = Parser.parse(source: """
            func example<T>(_ value: T) -> Int {
                return 42
            }
        """)

        let expected = Parser.parse(source: """
            func example<T>(_ value: T) -> Int {}
        """)

        let stripped = source.strippingImplementation()

        #expect(stripped.description == expected.description)
    }

    @Test func `strips function implementation in a class`() {
        let source = Parser.parse(source: """
            class MyClass {
                func example<T>(_ value: T) -> Int {
                    return 42
                }
            }
        """)

        let expected = Parser.parse(source: """
            class MyClass {
                func example<T>(_ value: T) -> Int {}
            }
        """)

        let stripped = source.strippingImplementation()

        #expect(stripped.description == expected.description)
    }

    @Test func `strips computed property implementation`() {
        let source = Parser.parse(source: """
            struct Foo {
                var readonly: Int {
                    return 42
                }
                 
                var readwrite: Int {
                    get {
                        return 42
                    }
                    set {
                        print(newValue)
                    }
                }
            }
        """)

        let expected = Parser.parse(source: """
            struct Foo {
                var readonly: Int { get }
                 
                var readwrite: Int { get set }
            }
        """)

        let stripped = source.strippingImplementation()

        #expect(stripped.description == expected.description)
    }
}
