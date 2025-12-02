protocol MockedType {}

struct MockedTypesResolver {
    let typeAliases: [String: [String: AliasDefinition]]
    var annotationKeys: [String] = ["sourcery", "UltiMock"]

    func resolve(_ types: [Syntax.TypeInfo]) -> [MockedType] {
        []
    }
}
