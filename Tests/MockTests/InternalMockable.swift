// sourcery:AutoMockable
protocol InternalMockable {
    func doSomething(with internal: Internal)
}

struct Internal {}
