import SwiftParser
import SwiftSyntax
import Testing
@testable import UltiMockSwiftSyntaxParser

@Suite struct TypesCollectorTests {
    let collector = TypesCollector()

    @Test
    func `collect returns protocol and extension separately with their comments`() throws {
        let source = Parser.parse(source:
            """
            /// Greeter API description
            protocol Greeter {
            }

            // Extension adds defaults
            extension Greeter {
                func greet() {}
            }
            """
        )

        let types = collector.collect(from: source)

        let protocolType = try #require(types.first(where: { $0.kind == .protocol }))
        #expect(protocolType == Syntax.TypeInfo(
            kind: .protocol,
            name: "Greeter",
            localName: "Greeter",
            accessLevel: .internal,
            inheritedTypes: [],
            isExtension: false,
            comment: "/// Greeter API description\n"
        ))

        let extensionType = try #require(types.first(where: { $0.isExtension }))
        #expect(extensionType == Syntax.TypeInfo(
            kind: .extension,
            name: "Greeter",
            localName: "Greeter",
            accessLevel: .internal,
            inheritedTypes: [],
            methods: [Syntax.Method(name: "greet", definedInTypeIsExtension: true)],
            isExtension: true,
            comment: "\n\n// Extension adds defaults\n"
        ))
    }

    @Test
    func `collect returns multiple extensions with their inherited types`() {
        let source = Parser.parse(source:
            """
            protocol Worker {}

            extension Worker {
            }

            extension Worker: Sendable {}
            """
        )

        let types = collector.collect(from: source)
        let extensions = types.filter(\.isExtension)

        #expect(extensions == [
            Syntax.TypeInfo(
                kind: .extension,
                name: "Worker",
                localName: "Worker",
                accessLevel: .internal,
                inheritedTypes: [],
                isExtension: true,
                comment: nil
            ),
            Syntax.TypeInfo(
                kind: .extension,
                name: "Worker",
                localName: "Worker",
                accessLevel: .internal,
                inheritedTypes: ["Sendable"],
                isExtension: true,
                comment: nil
            )
        ])
    }

    @Test
    func `collect returns struct with modifiers and inherited types`() throws {
        let source = Parser.parse(source:
            """
            /// A user model
            public struct User: Codable, Equatable {
                let name: String
            }
            """
        )

        let types = collector.collect(from: source)
        let structType = try #require(types.first)
        #expect(structType == Syntax.TypeInfo(
            kind: .struct,
            name: "User",
            localName: "User",
            accessLevel: .public,
            inheritedTypes: ["Codable", "Equatable"],
                properties: [Syntax.Property(name: "name", type: "String", isVariable: false, writeAccess: "")],
            isExtension: false,
            comment: "/// A user model\n"
        ))
    }

    @Test
    func `collect returns class with modifiers and inherited types`() throws {
        let source = Parser.parse(source:
            """
            /// Base view controller
            open class BaseViewController: UIViewController, Loggable {
            }
            """
        )

        let types = collector.collect(from: source)
        let classType = try #require(types.first)
        #expect(classType == Syntax.TypeInfo(
            kind: .class,
            name: "BaseViewController",
            localName: "BaseViewController",
            accessLevel: .open,
            inheritedTypes: ["UIViewController", "Loggable"],
            isExtension: false,
            comment: "/// Base view controller\n"
        ))
    }

    @Test
    func `collect returns enum with modifiers and inherited types`() throws {
        let source = Parser.parse(source:
            """
            /// Network error types
            internal enum NetworkError: Error, Sendable {
                case timeout
            }
            """
        )

        let types = collector.collect(from: source)
        let enumType = try #require(types.first)
        #expect(enumType == Syntax.TypeInfo(
            kind: .enum,
            name: "NetworkError",
            localName: "NetworkError",
            accessLevel: .internal,
            inheritedTypes: ["Error", "Sendable"],
            isExtension: false,
            comment: "/// Network error types\n"
        ))
    }

    @Test
    func `collect returns public access level`() throws {
        let source = Parser.parse(source: "public struct Example {}")
        let types = collector.collect(from: source)
        let type = try #require(types.first)
        #expect(type.accessLevel == .public)
    }

    @Test
    func `collect returns private access level`() throws {
        let source = Parser.parse(source: "private struct Example {}")
        let types = collector.collect(from: source)
        let type = try #require(types.first)
        #expect(type.accessLevel == .private)
    }

    @Test
    func `collect returns fileprivate access level`() throws {
        let source = Parser.parse(source: "fileprivate struct Example {}")
        let types = collector.collect(from: source)
        let type = try #require(types.first)
        #expect(type.accessLevel == .fileprivate)
    }

    @Test
    func `collect returns open access level`() throws {
        let source = Parser.parse(source: "open class Example {}")
        let types = collector.collect(from: source)
        let type = try #require(types.first)
        #expect(type.accessLevel == .open)
    }

    @Test
    func `collect returns package access level`() throws {
        let source = Parser.parse(source: "package struct Example {}")
        let types = collector.collect(from: source)
        let type = try #require(types.first)
        #expect(type.accessLevel == .package)
    }

    @Test
    func `collect returns internal access level when no modifier specified`() throws {
        let source = Parser.parse(source: "struct Example {}")
        let types = collector.collect(from: source)
        let type = try #require(types.first)
        #expect(type.accessLevel == .internal)
    }

    @Test
    func `collect extracts localName from qualified type names`() {
        let source = Parser.parse(source:
            """
            extension Swift.Array {
            }

            extension Foundation.URL: Sendable {
            }
            """
        )

        let types = collector.collect(from: source)
        #expect(types == [
            Syntax.TypeInfo(
                kind: .extension,
                name: "Swift.Array",
                localName: "Array",
                accessLevel: .internal,
                inheritedTypes: [],
                isExtension: true,
                comment: nil
            ),
            Syntax.TypeInfo(
                kind: .extension,
                name: "Foundation.URL",
                localName: "URL",
                accessLevel: .internal,
                inheritedTypes: ["Sendable"],
                isExtension: true,
                comment: nil
            )
        ])
    }

    @Test
    func `collect extracts line comments preserving newlines`() throws {
        let source = Parser.parse(source:
            """
            // First line
            // Second line

            // Third line after blank
            protocol Example {}
            """
        )

        let types = collector.collect(from: source)
        let type = try #require(types.first)

        #expect(type == Syntax.TypeInfo(
            kind: .protocol,
            name: "Example",
            localName: "Example",
            accessLevel: .internal,
            inheritedTypes: [],
            isExtension: false,
            comment: "// First line\n// Second line\n\n// Third line after blank\n"
        ))
    }

    @Test
    func `collect extracts block comments`() throws {
        let source = Parser.parse(source:
            """
            /*
             Multi-line
             block comment
            */
            protocol Example {}
            """
        )

        let types = collector.collect(from: source)
        let type = try #require(types.first)

        #expect(type == Syntax.TypeInfo(
            kind: .protocol,
            name: "Example",
            localName: "Example",
            accessLevel: .internal,
            inheritedTypes: [],
            isExtension: false,
            comment: "/*\n Multi-line\n block comment\n*/\n"
        ))
    }

    @Test
    func `collect extracts doc comments`() throws {
        let source = Parser.parse(source:
            """
            /**
             Documentation comment
             - Parameter x: Some param
            */
            protocol Example {}
            """
        )

        let types = collector.collect(from: source)
        let type = try #require(types.first)

        #expect(type == Syntax.TypeInfo(
            kind: .protocol,
            name: "Example",
            localName: "Example",
            accessLevel: .internal,
            inheritedTypes: [],
            isExtension: false,
            comment: "/**\n Documentation comment\n - Parameter x: Some param\n*/\n"
        ))
    }

    @Test
    func `collect returns nil comment when only whitespace trivia`() throws {
        let source = Parser.parse(source:
            """


            protocol Example {}
            """
        )

        let types = collector.collect(from: source)
        let type = try #require(types.first)
        #expect(type.comment == nil)
    }

    @Test
    func `collect handles multiple types in one file`() {
        let source = Parser.parse(source:
            """
            public protocol Service {}
            private struct Implementation: Service {}
            open class BaseClass {}
            internal enum Status { case active }
            extension Service {}
            """
        )

        let types = collector.collect(from: source)
        #expect(types == [
            Syntax.TypeInfo(
                kind: .protocol,
                name: "Service",
                localName: "Service",
                accessLevel: .public,
                inheritedTypes: [],
                isExtension: false,
                comment: nil
            ),
            Syntax.TypeInfo(
                kind: .struct,
                name: "Implementation",
                localName: "Implementation",
                accessLevel: .private,
                inheritedTypes: ["Service"],
                isExtension: false,
                comment: nil
            ),
            Syntax.TypeInfo(
                kind: .class,
                name: "BaseClass",
                localName: "BaseClass",
                accessLevel: .open,
                inheritedTypes: [],
                isExtension: false,
                comment: nil
            ),
            Syntax.TypeInfo(
                kind: .enum,
                name: "Status",
                localName: "Status",
                accessLevel: .internal,
                inheritedTypes: [],
                isExtension: false,
                comment: nil
            ),
            Syntax.TypeInfo(
                kind: .extension,
                name: "Service",
                localName: "Service",
                accessLevel: .internal,
                inheritedTypes: [],
                isExtension: true,
                comment: nil
            )
        ])
    }

    @Test
    func `collect returns protocol with generic parameters`() throws {
        let source = Parser.parse(source:
            """
            protocol BaseGenericProtocol<Base> {
                associatedtype Base
            }
            """
        )

        let types = collector.collect(from: source)
        let type = try #require(types.first)
        #expect(type == Syntax.TypeInfo(
            kind: .protocol,
            name: "BaseGenericProtocol",
            localName: "BaseGenericProtocol",
            accessLevel: .internal,
            inheritedTypes: [],
            genericParameters: [Syntax.GenericParameter(name: "Base")],
            isExtension: false,
            comment: nil,
            associatedTypes: [Syntax.AssociatedType(name: "Base")]
        ))
    }

    @Test
    func `collect returns protocol with multiple generic parameters`() throws {
        let source = Parser.parse(source:
            """
            public protocol Dictionary<Key, Value> {
                associatedtype Key
                associatedtype Value
            }
            """
        )

        let types = collector.collect(from: source)
        let type = try #require(types.first)
        #expect(type == Syntax.TypeInfo(
            kind: .protocol,
            name: "Dictionary",
            localName: "Dictionary",
            accessLevel: .public,
            inheritedTypes: [],
            genericParameters: [
                Syntax.GenericParameter(name: "Key"),
                Syntax.GenericParameter(name: "Value")
            ],
            isExtension: false,
            comment: nil,
            associatedTypes: [
                Syntax.AssociatedType(name: "Key"),
                Syntax.AssociatedType(name: "Value")
            ]
        ))
    }

    @Test
    func `collect returns struct with generic parameters`() throws {
        let source = Parser.parse(source:
            """
            struct Container<T> {
                let value: T
            }
            """
        )

        let types = collector.collect(from: source)
        let type = try #require(types.first)
        #expect(type == Syntax.TypeInfo(
            kind: .struct,
            name: "Container",
            localName: "Container",
            accessLevel: .internal,
            inheritedTypes: [],
            genericParameters: [Syntax.GenericParameter(name: "T")],
            properties: [Syntax.Property(name: "value", type: "T", isVariable: false, writeAccess: "")],
            isExtension: false,
            comment: nil
        ))
    }

    @Test
    func `collect returns class with generic parameters and constraints`() throws {
        let source = Parser.parse(source:
            """
            class Stack<Element: Equatable> {
                var items: [Element] = []
            }
            """
        )

        let types = collector.collect(from: source)
        let type = try #require(types.first)
        #expect(type == Syntax.TypeInfo(
            kind: .class,
            name: "Stack",
            localName: "Stack",
            accessLevel: .internal,
            inheritedTypes: [],
            genericParameters: [Syntax.GenericParameter(name: "Element", constraints: ["Equatable"])],
            properties: [Syntax.Property(name: "items", type: "[Element]", isVariable: true)],
            isExtension: false,
            comment: nil
        ))
    }

    @Test
    func `collect returns enum with generic parameters`() throws {
        let source = Parser.parse(source:
            """
            enum Result<Success, Failure: Error> {
                case success(Success)
                case failure(Failure)
            }
            """
        )

        let types = collector.collect(from: source)
        let type = try #require(types.first)
        #expect(type == Syntax.TypeInfo(
            kind: .enum,
            name: "Result",
            localName: "Result",
            accessLevel: .internal,
            inheritedTypes: [],
            genericParameters: [
                Syntax.GenericParameter(name: "Success"),
                Syntax.GenericParameter(name: "Failure", constraints: ["Error"])
            ],
            isExtension: false,
            comment: nil
        ))
    }

    @Test
    func `collect returns final class`() throws {
        let source = Parser.parse(source:
            """
            public final class FinalClass {
                func doSomething() {}
            }
            """
        )

        let types = collector.collect(from: source)
        let type = try #require(types.first)
        #expect(type == Syntax.TypeInfo(
            kind: .class,
            name: "FinalClass",
            localName: "FinalClass",
            accessLevel: .public,
            inheritedTypes: [],
            methods: [Syntax.Method(name: "doSomething")],
            isExtension: false,
            comment: nil
        ))
    }

    @Test
    func `collect returns protocol with where clause on inherited type`() throws {
        let source = Parser.parse(source:
            """
            protocol RefinedGenericProtocol<A>: BaseGenericProtocol
                where Base: Identifiable, Base.ID == A {
                associatedtype A
            }
            """
        )

        let types = collector.collect(from: source)
        let type = try #require(types.first)
        #expect(type.inheritedTypes == ["BaseGenericProtocol"])
        #expect(type.genericParameters == [Syntax.GenericParameter(name: "A")])
    }

    @Test
    func `collect returns struct with where clause on generic parameter`() throws {
        let source = Parser.parse(source:
            """
            struct Container<T> where T: Equatable {
                let value: T
            }
            """
        )

        let types = collector.collect(from: source)
        let type = try #require(types.first)
        #expect(type == Syntax.TypeInfo(
            kind: .struct,
            name: "Container",
            localName: "Container",
            accessLevel: .internal,
            inheritedTypes: [],
            genericParameters: [Syntax.GenericParameter(name: "T")],
            properties: [Syntax.Property(name: "value", type: "T", isVariable: false, writeAccess: "")],
            isExtension: false,
            comment: nil,
            genericRequirements: [
                Syntax.GenericRequirement(
                    leftTypeName: "T",
                    rightTypeName: "Equatable",
                    relationshipSyntax: ":"
                )
            ]
        ))
    }

    @Test
    func `collect returns class with complex where clause`() throws {
        let source = Parser.parse(source:
            """
            class Repository<Model, ID> where Model: Identifiable, Model.ID == ID, ID: Hashable {
                var storage: [ID: Model] = [:]
            }
            """
        )

        let types = collector.collect(from: source)
        let type = try #require(types.first)
        #expect(type == Syntax.TypeInfo(
            kind: .class,
            name: "Repository",
            localName: "Repository",
            accessLevel: .internal,
            inheritedTypes: [],
            genericParameters: [
                Syntax.GenericParameter(name: "Model"),
                Syntax.GenericParameter(name: "ID")
            ],
            properties: [Syntax.Property(name: "storage", type: "[ID: Model]", isVariable: true)],
            isExtension: false,
            comment: nil,
            genericRequirements: [
                Syntax.GenericRequirement(leftTypeName: "Model", rightTypeName: "Identifiable", relationshipSyntax: ":"),
                Syntax.GenericRequirement(leftTypeName: "Model.ID", rightTypeName: "ID", relationshipSyntax: "=="),
                Syntax.GenericRequirement(leftTypeName: "ID", rightTypeName: "Hashable", relationshipSyntax: ":")
            ]
        ))
    }

    @Test
    func `collect returns extension with where clause`() throws {
        let source = Parser.parse(source:
            """
            extension Array where Element: Equatable {
                func containsDuplicates() -> Bool {
                    return count != Set(self).count
                }
            }
            """
        )

        let types = collector.collect(from: source)
        let type = try #require(types.first)
        #expect(type == Syntax.TypeInfo(
            kind: .extension,
            name: "Array",
            localName: "Array",
            accessLevel: .internal,
            inheritedTypes: [],
            methods: [
                Syntax.Method(
                    name: "containsDuplicates",
                    returnType: "Bool",
                    definedInTypeIsExtension: true
                )
            ],
            isExtension: true,
            comment: nil,
            genericRequirements: [
                Syntax.GenericRequirement(
                    leftTypeName: "Element",
                    rightTypeName: "Equatable",
                    relationshipSyntax: ":"
                )
            ]
        ))
    }

    @Test
    func `collect returns protocol with objc attribute`() throws {
        let source = Parser.parse(source:
            """
            @objc protocol ObjCMockable {
                func doSomething(with int: Int)
            }
            """
        )

        let types = collector.collect(from: source)
        let type = try #require(types.first)
        #expect(type == Syntax.TypeInfo(
            kind: .protocol,
            name: "ObjCMockable",
            localName: "ObjCMockable",
            accessLevel: .internal,
            inheritedTypes: [],
            methods: [Syntax.Method(name: "doSomething", parameters: [Syntax.Method.Parameter(label: "with", name: "int", type: "Int")])],
            isExtension: false,
            comment: nil
        ))
    }

    @Test
    func `collect returns class with available attribute`() throws {
        let source = Parser.parse(source:
            """
            @available(iOS 13.0, *)
            public class ModernFeature {
                func doSomething() {}
            }
            """
        )

        let types = collector.collect(from: source)
        let type = try #require(types.first)
        #expect(type == Syntax.TypeInfo(
            kind: .class,
            name: "ModernFeature",
            localName: "ModernFeature",
            accessLevel: .public,
            inheritedTypes: [],
            methods: [Syntax.Method(name: "doSomething")],
            isExtension: false,
            comment: nil
        ))
    }

    @Test
    func `collect returns struct with multiple attributes`() throws {
        let source = Parser.parse(source:
            """
            @available(iOS 13.0, *)
            @frozen
            public struct FrozenStruct {
                let value: Int
            }
            """
        )

        let types = collector.collect(from: source)
        let type = try #require(types.first)
        #expect(type == Syntax.TypeInfo(
            kind: .struct,
            name: "FrozenStruct",
            localName: "FrozenStruct",
            accessLevel: .public,
            inheritedTypes: [],
            properties: [Syntax.Property(name: "value", type: "Int", isVariable: false, writeAccess: "")],
            isExtension: false,
            comment: nil
        ))
    }

    @Test
    func `collect returns protocol with reserved keyword parameter names`() throws {
        let source = Parser.parse(source:
            """
            protocol InternalMockable {
                func doSomething(with internal: Internal)
                func doSomething(withAny any: Any)
            }
            """
        )

        let types = collector.collect(from: source)
        let type = try #require(types.first)
        #expect(type == Syntax.TypeInfo(
            kind: .protocol,
            name: "InternalMockable",
            localName: "InternalMockable",
            accessLevel: .internal,
            inheritedTypes: [],
            methods: [
                Syntax.Method(name: "doSomething", parameters: [Syntax.Method.Parameter(label: "with", name: "internal", type: "Internal")]),
                Syntax.Method(name: "doSomething", parameters: [Syntax.Method.Parameter(label: "withAny", name: "any", type: "Any")])
            ],
            isExtension: false,
            comment: nil
        ))
    }

    @Test
    func `collect returns generic type with nested member constraint`() throws {
        let source = Parser.parse(source:
            """
            protocol RefinedGenericProtocol<A>: BaseGenericProtocol
                where Base: Identifiable, Base.ID == A {
                associatedtype A
                associatedtype B where B == Base
            }
            """
        )

        let types = collector.collect(from: source)
        let type = try #require(types.first)
        #expect(type == Syntax.TypeInfo(
            kind: .protocol,
            name: "RefinedGenericProtocol",
            localName: "RefinedGenericProtocol",
            accessLevel: .internal,
            inheritedTypes: ["BaseGenericProtocol"],
            genericParameters: [Syntax.GenericParameter(name: "A")],
            isExtension: false,
            comment: nil,
            associatedTypes: [
                Syntax.AssociatedType(name: "A"),
                Syntax.AssociatedType(name: "B")
            ],
            genericRequirements: [
                Syntax.GenericRequirement(leftTypeName: "Base", rightTypeName: "Identifiable", relationshipSyntax: ":"),
                Syntax.GenericRequirement(leftTypeName: "Base.ID", rightTypeName: "A", relationshipSyntax: "==")
            ]
        ))
    }

    @Test
    func `collect parses AutoMockable annotation from protocol`() throws {
        let source = Parser.parse(source:
            """
            // sourcery:AutoMockable
            protocol TestProtocol {
                func test()
            }
            """
        )

        let types = collector.collect(from: source)
        let type = try #require(types.first)
        #expect(type.annotations["AutoMockable"] == ["AutoMockable"])
    }

    @Test
    func `collect parses AutoMockable annotation from class`() throws {
        let source = Parser.parse(source:
            """
            // sourcery:AutoMockable
            open class TestClass {
                func test() {}
            }
            """
        )

        let types = collector.collect(from: source)
        let type = try #require(types.first)
        #expect(type.annotations["AutoMockable"] == ["AutoMockable"])
    }

    @Test
    func `collect parses AutoMockable annotation from extension`() throws {
        let source = Parser.parse(source:
            """
            // sourcery:AutoMockable
            extension TestProtocol {}
            """
        )

        let types = collector.collect(from: source)
        let type = try #require(types.first)
        #expect(type.annotations["AutoMockable"] == ["AutoMockable"])
    }

    @Test
    func `collect parses annotation with key-value pair`() throws {
        let source = Parser.parse(source:
            """
            // sourcery:AutoMockable
            // sourcery:skip = ["method1", "method2"]
            protocol TestProtocol {
                func method1()
                func method2()
            }
            """
        )

        let types = collector.collect(from: source)
        let type = try #require(types.first)
        #expect(type.annotations["AutoMockable"] == ["AutoMockable"])
        #expect(type.annotations["skip"] == ["method1", "method2"])
    }

    @Test
    func `collect parses multiple annotations`() throws {
        let source = Parser.parse(source:
            """
            // sourcery:AutoMockable
            // sourcery:typealias = "A = Int"
            // sourcery:typealias = "B = String"
            protocol TestProtocol {
                associatedtype A
                associatedtype B
            }
            """
        )

        let types = collector.collect(from: source)
        let type = try #require(types.first)
        #expect(type.annotations["AutoMockable"] == ["AutoMockable"])
        #expect(type.annotations["typealias"] == ["A = Int", "B = String"])
    }

    @Test
    func `collect ignores non-sourcery comments`() throws {
        let source = Parser.parse(source:
            """
            // Regular comment
            /// Documentation comment
            protocol TestProtocol {
                func test()
            }
            """
        )

        let types = collector.collect(from: source)
        let type = try #require(types.first)
        #expect(type.annotations.isEmpty)
    }

    @Test
    func `collect parses annotation with doc comment prefix`() throws {
        let source = Parser.parse(source:
            """
            /// sourcery:AutoMockable
            protocol TestProtocol {
                func test()
            }
            """
        )

        let types = collector.collect(from: source)
        let type = try #require(types.first)
        #expect(type.annotations["AutoMockable"] == ["AutoMockable"])
    }
}
