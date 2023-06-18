protocol TestableMockable {
    func doSomething(with internal: InternalMockableParameter)
}

struct InternalMockableParameter {}
