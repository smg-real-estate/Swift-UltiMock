protocol TestableMockable {
    func doSomething(with internal: InternalMockableParameter)
}

struct InternalMockableParameter {}

typealias ParameterAlias = TestableMockables.InternalMockableParameter
