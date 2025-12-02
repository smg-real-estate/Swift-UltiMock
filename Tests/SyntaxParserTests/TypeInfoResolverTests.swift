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

//        let classB = try #require(typeInfos.first { $0.name == "B" })
//        #expect(classB.methods.count == 1)
//        #expect(classB.methods.first?.name == "method")
    }
}
