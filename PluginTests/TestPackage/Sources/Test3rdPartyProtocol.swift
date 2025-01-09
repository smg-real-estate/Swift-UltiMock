public protocol Test3rdPartyProtocol {
    associatedtype Input
    associatedtype Output

    func doSomething(_ string: Input) -> Output
}
