import XFoundation

/// A type for distinguishing `expect` method's `perform` parameter.
public struct OnlyProperty: Equatable {
    let value: Int

    public init(value: Int) {
        self.value = value
    }
}

// sourcery:AutoMockable
public protocol TestMockable {
    var property: OnlyProperty { get }
    var readwriteProperty: Int { get set }
    var forceUnwrapped: String! { get set }

    func forceUnwrappedResult() -> String!

    @available(iOS 15.0, *)
    func newAPI()

    func noParamsVoid()
    func noParamsVoidAsync() async
    func noParamsVoidAsyncThrowing() async throws

    func noParamsResult() -> Swift.Int
    func noParamsResult() -> Int?
    func noParamsImplicitOptionalResult() -> Int!
    func noParamsArrayResult() -> [Int]
    func noParamsDictionaryResult() -> [String: Int]
    func noParamsClosureResult() -> (Int) -> Void
    func noParamsResultAsync() async -> Int
    func noParamsAsyncThrowingResult() async throws -> Int

    func `func`() -> Void
    func withSelf(_ self: Self) -> Self

    func withOptionalClosure(_ closure: ((Int) -> Void)?)

    func withParamsVoid(
        int: Swift.Int,
        label labelString: String,
        _ string: String,
        _ optional: Int?,
        _ implicitOptional: Int!,
        _ `inout`: inout Int,
        _ array: [Int],
        _ dictionary: [String: Int],
        _ escapingClosure: @escaping (Int) -> Void
    )
    func withParamsVoidAsync(int: Int, label labelString: String, _ string: String, _ optional: Int?) async
    func withParamsVoidAsyncThrowing(int: Int, label labelString: String, _ string: String, _ optional: Int?) async throws

    func withParamsResult(int: Int, label labelString: String, _ string: String) -> Int
    func withParamsResultAsync(int: Int, label labelString: String, _ string: String) async -> Int
    func withParamsAsyncThrowingResult(int: Int, label labelString: String, _ string: String) async throws -> Int

    func generic<P1: Equatable, P2>(parameter1: P1, _ parameter2: P2) -> Int where P2: Hashable
    func generic(some: some TestGenericProtocol<Int>, any: any TestGenericProtocol<String>) -> Int
}

public protocol TestGenericProtocol<T> {
    associatedtype T
}

public struct TestGenericStruct<T: Equatable>: TestGenericProtocol, Equatable {
    let value: T

    public init(_ value: T) {
        self.value = value
    }
}

extension TestMockable {
    func extensionMethod() {}
    func noParamsVoid() {}
}

// sourcery:AutoMockable
public protocol GenericTestMockable {
    associatedtype Value
    associatedtype ConstrainedValue: Equatable

    func doSomething(with value: Value)
    func doSomething(with value: ConstrainedValue)
    func doSomethingWithInput<I, O>(_ input: I) -> O where Value == (I) -> O
}

protocol RequiringInitializer {
    init()
}

public class TestMockableSuperclass {
    init(int: Int) {}
    public func superNoParamsVoid() { fatalError() }
    public func noParamsVoid() { fatalError() }
    public var sideEffectProperty: Int = 0
}

public class TestMockableClass: TestMockableSuperclass {
    public var forwarded = false
    public var expectedResult: Int!

    override init(int: Int) {
        super.init(int: int)
        // Side effect in initializer should be autoforwarded
        self.sideEffectProperty = 0
    }

    init(string: String) {
        super.init(int: 0)
    }

    var readwriteProperty: Int = 0

    override public func noParamsVoid() {
        forwarded = true
    }

    public func noParamsVoidAsync() async {
        forwarded = true
    }

    public func noParamsVoidAsyncThrowing() async throws {
        forwarded = true
    }

    public func noParamsResult() -> Int {
        forwarded = true
        return expectedResult
    }

    public func noParamsResultAsync() async -> Int {
        forwarded = true
        return expectedResult
    }

    public func noParamsAsyncThrowingResult() async throws -> Int {
        forwarded = true
        return expectedResult
    }

    public func withParamsVoid(int: Int, label labelString: String, _ string: String) {
        forwarded = true
    }

    public func withParamsVoidAsync(int: Int, label labelString: String, _ string: String) async {
        forwarded = true
    }

    public func withParamsVoidAsyncThrowing(int: Int, label labelString: String, _ string: String) async throws {
        forwarded = true
    }

    public func withParamsResult(int: Int, label labelString: String, _ string: String) -> Int {
        forwarded = true
        return expectedResult
    }

    public func withParamsResultAsync(int: Int, label labelString: String, _ string: String) async -> Int {
        forwarded = true
        return expectedResult
    }

    public func withParamsAsyncThrowingResult(int: Int, label labelString: String, _ string: String) async throws -> Int {
        forwarded = true
        return expectedResult
    }
}

// sourcery:AutoMockable
// sourcery:skip = "forwarded"
// sourcery:skip = "expectedResult"
extension TestMockableClass {}

// sourcery:AutoMockable
extension NSObjectProtocol {}

// sourcery:AutoMockable
extension Servicing {}
