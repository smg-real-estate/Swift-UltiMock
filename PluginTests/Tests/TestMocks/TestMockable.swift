import CoreLocation
import TestPackage

/// A type for distinguishing `expect` method's `perform` parameter.
public struct OnlyProperty: Equatable {
    let value: Int

    public init(value: Int) {
        self.value = value
    }
}

// sourcery:AutoMockable
public protocol TestMockable: Sendable {
    var property: OnlyProperty { get }
    var throwingProperty: Int { get throws }
    var asyncProperty: Int { get async }
    var asyncThrowingProperty: Int { get async throws }
    var readwriteProperty: Int { get set }
    var forceUnwrapped: String! { get set }

    subscript(key: Int) -> String { get }
    subscript(key: String) -> Int { get set }

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

    func `func`()
    func withSelf(_ self: Self) -> Self

    func withOptionalClosure(_ closure: ((Int) -> Void)?)
    func withAnnotatedClosure(_ closure: (@MainActor @Sendable (Int) -> Void)?)

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
    func withParamsResult(otherInt: Int, label labelString: String, _ string: String) -> Int // For `expect` redeclaration
    func withParamsResultAsync(int: Int, label labelString: String, _ string: String) async -> Int
    func withParamsAsyncThrowingResult(int: Int, label labelString: String, _ string: String) async throws -> Int

    // swiftformat:disable:next opaqueGenericParameters
    func generic<P1: Equatable, P2>(parameter1: P1, _ parameter2: P2) -> Int where P2: Hashable
    @available(macOS 13, iOS 16, *)
    func generic(some: some TestGenericProtocol<Int>, any: any TestGenericProtocol<String>) -> Int

    @discardableResult
    func discardableResult() -> String

    func closureAliasResult(_ closure: @escaping ClosureAlias<Int>) -> ClosureAlias<Int>
    func closureAliasResultEquivalent(_ closure: @escaping (Int) -> Void) -> (Int) -> Void
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

open class TestMockableSuperclass {
    init(int: Int) {}

    open func openMethod() { fatalError() }
    public func superNoParamsVoid() { fatalError() }
    public func noParamsVoid() { fatalError() }
    public var sideEffectProperty: Int = 0

    // Non-mockable methods
    private func privateMethod() {}
    static func staticMethod() {}
    open class func openClassMethod() {}
}

// sourcery:AutoMockable
extension Test3rdPartyProtocol {}

public typealias ClosureAlias<T> = (T) -> Void
