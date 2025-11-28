import SyntaxParser
import Testing

struct Test {
    let resolver = TypeInfoResolver()

    @Test func `merges overridden methods`() throws {
        let sources: [() throws -> String?] = [
            {
                """
                class A {
                    func method() {}
                }
                """
            },
            {
                """
                class B: A {
                    override func method() {}
                }
                """
            }
        ]

        let typeInfos = try resolver.resolve(from: sources)

        let classB = try #require(typeInfos.first { $0.name == "B" })
        #expect(classB.methods.count == 1)
        #expect(classB.methods.first?.name == "method")
    }

    @Test func `resolves types from a different source`() throws {
        let sources: [() throws -> String?] = [
            {
                """
                typealias Foo = Int
                """
            },
            {
                """
                protocol Bar {
                    var foo: Foo
                }
                """
            }
        ]

        let typeInfos = try resolver.resolve(from: sources)

        let protocolInfo = try #require(typeInfos.first)
        let property = try #require(protocolInfo.properties.first)
        #expect(property.type == "Foo")
        #expect(property.resolvedType == "Int")
    }
}
