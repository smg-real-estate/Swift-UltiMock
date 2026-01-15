import Foundation
@testable import TestableMockables

// UltiMock:AutoMockable
protocol InternalMockable {
    func doSomething(with internal: Internal)
    func doSomething(withAny any: Any)
}

struct Internal {}

// UltiMock:AutoMockable
extension TestableMockable {}

// swiftformat:disable preferFinalClasses
public class PublicMockableClass {
    public func doSomething() {}
    public var value: Int = 0
}

// UltiMock:AutoMockable
class InternalSubclassOfAPublicClass: PublicMockableClass {}
// swiftformat:enable preferFinalClasses

// UltiMock:AutoMockable
@objc protocol ObjCMockable {
    @objc(doSomethingWith:)
    func doSomething(with int: Int)
    @objc optional func optionalMethod()
}

// Ensure mock generation
typealias ObjCMock = ObjCMockableMock

protocol BaseGenericProtocol<Base> {
    associatedtype Base
    var base: Base { get set }

    subscript(key: Int) -> String { get }
}

// UltiMock:AutoMockable
protocol RefinedGenericProtocol<A>: BaseGenericProtocol
    // The edge case needs Base.ID == A and not A == Base.ID
    where Base: Identifiable, Base.ID == A {
    associatedtype A
    associatedtype B where B == Base

    var a: A { get set }

    subscript(key: A) -> B { get set }
    func value(for key: A) -> B

    // Subscript overriding
    subscript(key: Int) -> String { get set }
}

// UltiMock:AutoMockable
@MainActor
protocol IsolatedMockable {
    func isolatedMethod()
    nonisolated func nonisolatedMethod()
}

// Ensure mock generation
typealias IsolatedMock = IsolatedMockableMock

protocol BaseProtocol {
    var a: Int { get }
    var b: Int { get }
    subscript(key: String) -> String { get }
    func doSomething()
}

// UltiMock:AutoMockable
protocol OverridingProtocol: BaseProtocol {
    var a: Int { get }
    var b: Int { get set }
    subscript(key: String) -> String { get set }
    func doSomething()
}

// Ensure mock generation
typealias OverridingMock = OverridingProtocolMock
