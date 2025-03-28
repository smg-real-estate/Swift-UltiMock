import os
import Testing
import XCTest
import XCTestExtensions

public protocol Mock {
    var recorder: Recorder { get }

    func verify(
        fileID: String,
        filePath: StaticString,
        line: UInt,
        column: Int
    )

    var isEnabled: Bool { get }
}

public extension Mock {
    func verify(
        fileID: String = #fileID,
        filePath: StaticString = #filePath,
        line: UInt = #line,
        column: Int = #column
    ) {
        recorder.verify(
            fileID: fileID,
            filePath: filePath,
            line: line,
            column: column
        )
    }

    func verifyAsync(
        timeout: TimeInterval,
        fileID: String = #fileID,
        filePath: StaticString = #filePath,
        line: UInt = #line,
        column: Int = #column
    ) {
        recorder.verifyAsync(
            timeout: timeout,
            fileID: fileID,
            filePath: filePath,
            line: line,
            column: column
        )
    }

    func verifyAsync(
        timeout: TimeInterval,
        fileID: String = #fileID,
        filePath: StaticString = #filePath,
        line: UInt = #line,
        column: Int = #column
    ) async {
        recorder.verifyAsync(
            timeout: timeout,
            fileID: fileID,
            filePath: filePath,
            line: line,
            column: column
        )
    }

    func resetExpectations() {
        recorder.reset()
    }

    var isEnabled: Bool { true }
}

public extension Recorder {
    struct Expectation: Identifiable, CustomStringConvertible {
        public let id: String
        public let description: String
        let parameters: [AnyParameter]

        public init(method: MockMethod, parameters: [AnyParameter]) {
            self.id = method.id
            self.description = method.description(parameters)
            self.parameters = parameters
        }

        func matches(_ invocation: Invocation) -> Bool {
            id == invocation.method.id
                && zip(parameters, invocation.parameters)
                .reduce(into: true) { result, pair in
                    result = result && pair.0.match(pair.1)
                }
        }
    }

    struct Stub {
        public let expectation: Expectation
        public let perform: Any
        public let fileID: String
        public let filePath: StaticString
        public let line: UInt
        public let column: Int

        public init(
            _ expectation: Expectation,
            _ perform: Any,
            _ fileID: String,
            _ filePath: StaticString,
            _ line: UInt,
            _ column: Int
        ) {
            self.expectation = expectation
            self.perform = perform
            self.fileID = fileID
            self.filePath = filePath
            self.line = line
            self.column = column
        }

        public func matches(_ invocation: Invocation) -> Bool {
            expectation.matches(invocation)
        }
    }
}

func fail(
    _ message: String,
    fileID: String,
    filePath: StaticString,
    line: UInt,
    column: Int
) {
    XCTFail(message, file: filePath, line: line)
    Issue.record(
        "\(message)",
        sourceLocation: .init(
            fileID: fileID,
            filePath: "\(filePath)",
            line: Int(line),
            column: column
        )
    )
}

private struct FatalError: Error {
    let localizedDescription: String
}

public func handleFatalFailure(
    _ message: String,
    fileID: String,
    filePath: StaticString,
    line: UInt,
    column: Int
) -> Never {
    guard let testCase = CurrentTestCaseObserver.currentTestCase else {
        let actualLine = XCTSourceCodeContext().callStack.first { frame in
            frame.symbolInfo?.location?.fileURL.path == "\(filePath)"
        }?.symbolInfo?.location?.lineNumber ?? Int(line)

        fail("[FATAL] \(message)", fileID: fileID, filePath: filePath, line: UInt(actualLine), column: column)
        // Extra delay for issue reporting.
        // Not necessary after https://github.com/swiftlang/swift-evolution/blob/main/proposals/testing/0008-exit-tests.md is done.
        sleep(1)
        exit(0)
    }

    let continueAfterFailure = testCase.continueAfterFailure
    testCase.continueAfterFailure = false

    defer {
        testCase.continueAfterFailure = continueAfterFailure
    }

    let callStack = testCase.invocation.flatMap { invocation in
        XCTSourceCodeContext().callStack.drop { frame in
            frame.symbolInfo?.symbolName.hasSuffix("\(testCase.classForCoder).\(invocation.selector)()") != true
        }
    }

    let fail: () -> Never = {
        if let callStack {
            testCase.record(
                XCTIssue(
                    type: .assertionFailure,
                    compactDescription: message,
                    sourceCodeContext: .init(callStack: Array(callStack), location: nil)
                )
            )
        } else {
            XCTFail(message, file: filePath, line: line)
        }
        exit(0)
    }

    if Thread.isMainThread {
        fail()
    } else {
        DispatchQueue.main.sync(execute: fail)
    }
}

public struct Parameter<T>: CustomStringConvertible {
    public let description: String
    public let match: (Any?) -> Bool
}

public extension Parameter {
    static var any: Self {
        .init(description: "<any>") { _ in true }
    }

    static func any(_ type: T.Type) -> Self {
        .init(description: "<any>") { _ in true }
    }

    static func matching(_ type: T.Type = T.self, isMatching: @escaping (T) -> Bool) -> Self {
        .init(description: "<matching>") {
            isMatching($0 as! T)
        }
    }

    static func casted<Other: Equatable>(_ value: Other, as: Other.Type = Other.self) -> Self {
        .init(description: "\(value)") { other in
            (other as? Other) == value
        }
    }
}

public extension Parameter where T: Equatable {
    static func value(_ value: T) -> Self {
        .init(description: "\(value)") { other in
            (other as? T) == value
        }
    }
}

public extension Parameter where T: AnyObject {
    static func identical(to object: T) -> Self {
        .init(description: "\(object)") { other in
            (other as? T) === object
        }
    }
}

extension Parameter: ExpressibleByNilLiteral where T: Equatable, T: OptionalProtocol {
    public init(nilLiteral: ()) {
        self = .isNil
    }
}

public protocol OptionalProtocol: ExpressibleByNilLiteral {
    associatedtype Wrapped
    var optional: Wrapped? { get }

    static func == (lhs: Self, rhs: _OptionalNilComparisonType) -> Bool
    static func != (lhs: Self, rhs: _OptionalNilComparisonType) -> Bool
}

extension Optional: OptionalProtocol {
    public var optional: Wrapped? {
        self
    }
}

public extension Parameter where T: OptionalProtocol {
    static var `isNil`: Self {
        self.init(description: "nil") { $0 == nil }
    }

    static var `isNotNil`: Self {
        self.init(description: "<non-nil>") { $0 != nil }
    }
}

extension Parameter: ExpressibleByArrayLiteral
    where T: ExpressibleByArrayLiteral,
    T: Sequence,
    T.Element: Equatable,
    T.ArrayLiteralElement == T.Element {
    public init(arrayLiteral elements: T.ArrayLiteralElement...) {
        self.init(description: "\(elements)") { other in
            (other as? T).map {
                elements == Array($0)
            } ?? false
        }
    }
}

extension Parameter: ExpressibleByDictionaryLiteral
where T: ExpressibleByDictionaryLiteral, T: Sequence, T.Element == (key: T.Key, value: T.Value), T.Key: Hashable, T.Value: Equatable {
    public init(dictionaryLiteral elements: (T.Key, T.Value)...) {
        self.init(description: "\(Dictionary(uniqueKeysWithValues: elements))") { other in
            (other as? T).map { dictionary in
                Dictionary(uniqueKeysWithValues: elements) == Dictionary(uniqueKeysWithValues: dictionary.map { ($0.key, $0.value) })
            } ?? false
        }
    }
}

extension Parameter: ExpressibleByIntegerLiteral where T: ExpressibleByIntegerLiteral, T: Equatable {
    public init(integerLiteral value: T.IntegerLiteralType) {
        self = .value(.init(integerLiteral: value))
    }
}

extension Parameter: ExpressibleByBooleanLiteral where T: ExpressibleByBooleanLiteral, T: Equatable {
    public init(booleanLiteral value: T.BooleanLiteralType) {
        self = .value(.init(booleanLiteral: value))
    }
}

extension Parameter: ExpressibleByUnicodeScalarLiteral where T: ExpressibleByUnicodeScalarLiteral, T: Equatable {
    public init(unicodeScalarLiteral value: T.UnicodeScalarLiteralType) {
        self = .value(.init(unicodeScalarLiteral: value))
    }
}

extension Parameter: ExpressibleByExtendedGraphemeClusterLiteral where T: ExpressibleByExtendedGraphemeClusterLiteral, T: Equatable {
    public init(extendedGraphemeClusterLiteral value: T.ExtendedGraphemeClusterLiteralType) {
        self = .value(.init(extendedGraphemeClusterLiteral: value))
    }
}

extension Parameter: ExpressibleByStringLiteral where T: ExpressibleByStringLiteral, T: Equatable {
    public init(stringLiteral value: T.StringLiteralType) {
        self = .value(.init(stringLiteral: value))
    }
}

public extension Parameter {
    var anyParameter: AnyParameter {
        .init(description: description, match: match)
    }
}

public struct AnyParameter: CustomStringConvertible {
    public let description: String
    public let match: (Any?) -> Bool

    public init(description: String, match: @escaping (Any?) -> Bool) {
        self.description = description
        self.match = match
    }
}

public struct Invocation: CustomStringConvertible {
    public let method: MockMethod
    public let parameters: [Any?]

    public var description: String {
        method.description(parameters)
    }

    public init(method: MockMethod, parameters: [Any?]) {
        self.method = method
        self.parameters = parameters
    }
}

public struct MockMethod {
    public let id: String
    public let description: ([Any?]) -> String

    public init(id: String = #function, description: @escaping ([Any?]) -> String) {
        self.id = id
        self.description = description
    }
}
