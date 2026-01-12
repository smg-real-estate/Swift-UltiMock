import TestMocks
import XCTest

final class MockTests: XCTestCase {
    func test_unexpectedCalls1() {
        // Failures in async methods cannot be tested this way for the time being
        XCTExpectFailure {
            let mock = TestMockableMock()
            mock.noParamsVoid()
        } issueMatcher: { issue in
            issue.sourceCodeContext.location == .init(filePath: #filePath, lineNumber: #line - 2)
        }
    }

    func test_unexpectedCalls2() {
        XCTExpectFailure {
            let mock = TestMockableMock()
            var int = 2
            mock.withParamsVoid(int: 0, label: "label", "string", nil, 1, &int, [2], ["1": 2]) { _ in }
        }
    }

    func test_unexpectedCalls3() {
        XCTExpectFailure {
            let mock = TestMockableMock()
            _ = mock.withParamsResult(int: 0, label: "label", "string")
        }
    }

    func test_unexpectedCalls_subscriptGetter() {
        XCTExpectFailure {
            let mock = TestMockableMock()
            _ = mock[1]
        }
    }

    func test_unexpectedCalls_subscriptSetter() {
        XCTExpectFailure {
            let mock = TestMockableMock()
            mock["string1"] = 1
        }
    }

    func test_unexpectedPropertyCall() {
        XCTExpectFailure {
            let mock = TestMockableMock()
            _ = mock.property
        }
    }

    func test_unexpectedPropertySetterCall() {
        XCTExpectFailure {
            let mock = TestMockableMock()
            mock.expect(set: .readwriteProperty, to: 3)
            _ = mock.readwriteProperty = 0
            mock.verify()
        }
    }

    func test_failedVerifications() {
        let mock = TestMockableMock()

        mock.expect(.property) { OnlyProperty(value: 1) }
        mock.expect(.throwingProperty) { 11 }
        mock.expect(.asyncProperty) { 12 }
        mock.expect(.asyncThrowingProperty) { 13 }
        mock.expect(.readwriteProperty) { 2 }
        mock.expect(set: .readwriteProperty, to: 3) { _ in }
        mock.expect(.forceUnwrapped) { nil }

        mock.expect(.subscript[1]) { _ in "2" }
        mock.expect(set: .subscript["1"], to: 2)

        mock.expect(.forceUnwrappedResult()) { nil }
        mock.expect(.noParamsVoid()) {}
        mock.expect(.noParamsVoidAsync()) {}
        mock.expect(.noParamsVoidAsyncThrowing()) {}

        mock.expect(.noParamsResult()) { 1 as Int }
        mock.expect(.noParamsResult()) { nil }
        mock.expect(.noParamsArrayResult()) { [1] }
        mock.expect(.noParamsDictionaryResult()) { ["1": 2] }
        mock.expect(.noParamsClosureResult()) { { _ in } }
        mock.expect(.noParamsResultAsync()) { 2 }
        mock.expect(.noParamsAsyncThrowingResult()) { 3 }

        mock.expect(.withOptionalClosure(.any)) { $0?(1) }
        mock.expect(.withAnnotatedClosure(.any)) { _ in }

        mock.expect(
            .withParamsVoid(
                int: 1, label: "label", "string", nil, .value(1), 2, [2], ["1": 2], .any
            )
        ) { _, _, _, _, _, _, _, _, _ in }
        mock.expect(.withParamsVoidAsync(int: 1, label: "label", "string", nil)) { _, _, _, _ in }
        mock.expect(.withParamsVoidAsyncThrowing(int: 1, label: "label", "string", nil)) { _, _, _, _ in }

        mock.expect(.withParamsResult(int: 1, label: "label", "string")) { _, _, _ in 1 }
        mock.expect(.withParamsResultAsync(int: 1, label: "label", "string")) { _, _, _ in 2 }
        mock.expect(.withParamsAsyncThrowingResult(int: 1, label: "label", "string")) { _, _, _ in 3 }

        mock.expect(.`func`()) {}
        mock.expect(.withSelf(.any)) { $0 }

        var issueDescription = ""
        let options = XCTExpectedFailure.Options()
        options.issueMatcher = { issue in
            issueDescription = issue.compactDescription
            return true
        }

        XCTExpectFailure(options: options) {
            mock.verify()
        }

        XCTAssertEqual(issueDescription, """
        failed - Missing expected calls:
          property
          throwingProperty
          asyncProperty
          asyncThrowingProperty
          readwriteProperty
          readwriteProperty = 3
          forceUnwrapped
          [key: 1]
          [key: "1"] = 2
          forceUnwrappedResult()
          noParamsVoid()
          noParamsVoidAsync()
          noParamsVoidAsyncThrowing()
          noParamsResult()
          noParamsResult()
          noParamsArrayResult()
          noParamsDictionaryResult()
          noParamsClosureResult()
          noParamsResultAsync()
          noParamsAsyncThrowingResult()
          withOptionalClosure(<any>)
          withAnnotatedClosure(<any>)
          withParamsVoid(int: 1, label: "label", "string", nil, Optional(1), 2, [2], ["1": 2], <any>)
          withParamsVoidAsync(int: 1, label: "label", "string", nil)
          withParamsVoidAsyncThrowing(int: 1, label: "label", "string", nil)
          withParamsResult(int: 1, label: "label", "string")
          withParamsResultAsync(int: 1, label: "label", "string")
          withParamsAsyncThrowingResult(int: 1, label: "label", "string")
          `func`()
          withSelf(<any>)
        """)

        mock.verify() // Should reset expectations after verification
    }

    func test_resetExpectations() {
        let mock = TestMockableMock()

        mock.expect(.property) { .init(value: 1) }
        mock.expect(.throwingProperty) { 11 }
        mock.expect(.asyncProperty) { 12 }
        mock.expect(.asyncThrowingProperty) { 13 }
        mock.expect(.readwriteProperty) { 2 }
        mock.expect(set: .readwriteProperty, to: 3) { _ in }
        mock.expect(.forceUnwrapped) { nil }

        mock.expect(.subscript[1]) { _ in "2" }
        mock.expect(set: .subscript["1"], to: 2)

        mock.expect(.forceUnwrappedResult()) { nil }
        mock.expect(.noParamsVoid()) {}
        mock.expect(.noParamsVoidAsync()) {}
        mock.expect(.noParamsVoidAsyncThrowing()) {}

        mock.expect(.noParamsResult()) { 1 as Int }
        mock.expect(.noParamsResult()) { nil }
        mock.expect(.noParamsArrayResult()) { [1] }
        mock.expect(.noParamsDictionaryResult()) { ["1": 2] }
        mock.expect(.noParamsClosureResult()) { { _ in } }
        mock.expect(.noParamsResultAsync()) { 2 }
        mock.expect(.noParamsAsyncThrowingResult()) { 3 }

        mock.expect(.withOptionalClosure(.any)) { $0?(1) }
        mock.expect(.withAnnotatedClosure(.any)) { _ in }

        mock.expect(.withParamsVoid(int: 1, label: "label", "string", nil, .value(1), 2, [2], ["1": 2], .any)) { _, _, _, _, _, _, _, _, _ in }
        mock.expect(.withParamsVoidAsync(int: 1, label: "label", "string", nil)) { _, _, _, _ in }
        mock.expect(.withParamsVoidAsyncThrowing(int: 1, label: "label", "string", nil)) { _, _, _, _ in }
        mock.expect(.withParamsResult(int: 1, label: "label", "string")) { _, _, _ in 1 }
        mock.expect(.withParamsResult(otherInt: 2, label: "label2", "string2")) { _, _, _ in 2 }
        mock.expect(.withParamsResultAsync(int: 1, label: "label", "string")) { _, _, _ in 2 }
        mock.expect(.withParamsAsyncThrowingResult(int: 1, label: "label", "string")) { _, _, _ in 3 }

        mock.expect(.`func`()) {}
        mock.expect(.withSelf(.any)) { $0 }

        mock.resetExpectations()

        mock.verify()
    }

    func test_failsWhenCalledInIncorrectOrder() {
        let mock = TestMockableMock()

        mock.expect(.noParamsVoid()) {}
        mock.expect(
            .withParamsVoid(
                int: 1, label: "label", "string", nil, .value(1), 2, [2], ["1": 2], .any
            )
        ) { _, _, _, _, _, _, _, _, _ in }
        mock.expect(.noParamsVoid()) {}

        var int = 2
        XCTExpectFailure {
            mock.noParamsVoid()
            mock.noParamsVoid()
            mock.withParamsVoid(int: 1, label: "label", "string", nil, 1, &int, [2], ["1": 2]) { _ in }
        }
    }

    func test_successfulVerifications() async throws {
        let mock = TestMockableMock()

        mock.expect(.property) { .init(value: 1) }
        mock.expect(.throwingProperty) { throw TestError("throwingProperty_error") }
        mock.expect(.asyncProperty) { 12 }
        mock.expect(.asyncThrowingProperty) { throw TestError("asyncThrowingProperty_error") }
        mock.expect(.readwriteProperty) { 2 }
        mock.expect(set: .readwriteProperty, to: 3) {
            XCTAssertEqual($0, 3)
        }
        mock.expect(.forceUnwrapped) { nil }
        mock.expect(set: .forceUnwrapped, to: .value("some")) {
            XCTAssertEqual($0, "some")
        }

        mock.expect(.subscript[1]) { _ in "2" }
        mock.expect(set: .subscript["1"], to: 2) { _, _ in }

        mock.expect(.forceUnwrappedResult()) { nil }
        mock.expect(.newAPI())
        mock.expect(.noParamsVoid()) {}
        mock.expect(.noParamsVoid()) {}
        mock.expect(.noParamsVoidAsync()) {}
        mock.expect(.noParamsVoidAsyncThrowing()) {}

        mock.expect(.noParamsResult()) { 1 as Int }
        mock.expect(.noParamsResult()) { nil }
        mock.expect(.noParamsImplicitOptionalResult()) { nil }
        mock.expect(.noParamsArrayResult()) { [1] }
        mock.expect(.noParamsDictionaryResult()) { ["1": 2] }
        mock.expect(.noParamsClosureResult()) { { XCTAssertEqual($0, 15) } }
        mock.expect(.noParamsResultAsync()) { 2 }
        mock.expect(.noParamsAsyncThrowingResult()) { 3 }

        mock.expect(.withOptionalClosure(.any)) { $0?(1) }
        mock.expect(.withAnnotatedClosure(.any)) { closure in
            Task { @MainActor in
                closure?(2)
            }
        }

        mock.expect(.withParamsVoid(int: 1, label: "label", "string", nil, .value(1), 2, [2], ["1": 2], .any)) {
            XCTAssertEqual($0, 1)
            XCTAssertEqual($1, "label")
            XCTAssertEqual($2, "string")
            XCTAssertNil($3)
            XCTAssertEqual($4, 1)
            XCTAssertEqual($5, 2)
            $5 = 117
            XCTAssertEqual($6, [2])
            XCTAssertEqual($7, ["1": 2])
            $8(7)
        }
        mock.expect(.withParamsVoidAsync(int: 1, label: "label", "string", nil)) { _, _, _, _ in }
        mock.expect(.withParamsVoidAsyncThrowing(int: 1, label: "label", "string", nil)) { _, _, _, _ in }
        mock.expect(.withParamsResult(int: 1, label: "label", "string")) { _, _, _ in 1 }
        mock.expect(.withParamsResult(otherInt: 2, label: "label2", "string2")) { _, _, _ in 2 }
        mock.expect(.withParamsResultAsync(int: 1, label: "label", "string")) { _, _, _ in 2 }
        mock.expect(.withParamsAsyncThrowingResult(int: 1, label: "label", "string")) { _, _, _ in 3 }

        mock.expect(.generic(parameter1: .value(123), .value("string"))) { _, _ in 4 }
        if #available(iOS 16, *) {
            mock.expect(.generic(some: .value(TestGenericStruct(123)), any: .matching {
                $0 as! TestGenericStruct<String> == TestGenericStruct("string")
            })) { _, _ in 5 }
        }

        // Expectations fulfillments
        XCTAssertEqual(mock.property, OnlyProperty(value: 1))

        XCTAssertThrowsError(try mock.throwingProperty) { error in
            XCTAssertEqual(error as? TestError, TestError("throwingProperty_error"))
        }

        let asyncPropertyResult = await mock.asyncProperty
        XCTAssertEqual(asyncPropertyResult, 12)

        do {
            _ = try await mock.asyncThrowingProperty
            XCTFail("Did not throw")
        } catch {
            XCTAssertEqual(
                error as? TestError,
                TestError("asyncThrowingProperty_error")
            )
        }

        XCTAssertEqual(mock.readwriteProperty, 2)
        mock.readwriteProperty = 3
        XCTAssertNil(mock.forceUnwrapped)
        mock.forceUnwrapped = "some"

        XCTAssertEqual(mock[1], "2")
        mock["1"] = 2

        XCTAssertNil(mock.forceUnwrappedResult())
        mock.newAPI()
        mock.noParamsVoid()
        mock.noParamsVoid()
        await mock.noParamsVoidAsync()
        try await mock.noParamsVoidAsyncThrowing()

        mock.expect(.`func`()) {}
        mock.expect(.withSelf(.any)) { $0 }

        XCTAssertEqual(mock.noParamsResult(), 1)
        XCTAssertEqual(mock.noParamsResult(), nil)
        XCTAssertEqual(mock.noParamsImplicitOptionalResult(), nil)
        XCTAssertEqual(mock.noParamsArrayResult(), [1])
        XCTAssertEqual(mock.noParamsDictionaryResult(), ["1": 2])
        mock.noParamsClosureResult()(15)
        _ = await mock.noParamsResultAsync()
        _ = try await mock.noParamsAsyncThrowingResult()

        mock.withOptionalClosure {
            XCTAssertEqual($0, 1)
        }

        mock.withAnnotatedClosure {
            XCTAssertEqual($0, 2)
        }

        var int = 2
        mock.withParamsVoid(int: 1, label: "label", "string", nil, 1, &int, [2], ["1": 2]) {
            XCTAssertEqual($0, 7)
        }

        XCTAssertEqual(int, 117) // Verifying inout mutation in `perform` closure

        await mock.withParamsVoidAsync(int: 1, label: "label", "string", nil)
        try await mock.withParamsVoidAsyncThrowing(int: 1, label: "label", "string", nil)
        XCTAssertEqual(mock.withParamsResult(int: 1, label: "label", "string"), 1)
        XCTAssertEqual(mock.withParamsResult(otherInt: 2, label: "label2", "string2"), 2)
        _ = await mock.withParamsResultAsync(int: 1, label: "label", "string")
        _ = try await mock.withParamsAsyncThrowingResult(int: 1, label: "label", "string")

        XCTAssertEqual(mock.generic(parameter1: 123, "string"), 4)
        if #available(iOS 16, *) {
            XCTAssertEqual(mock.generic(some: TestGenericStruct(123), any: TestGenericStruct("string")), 5)
        }

        mock.`func`()
        _ = mock.withSelf(mock)

        mock.verify()
    }

    func test_failedAsyncVerifications() {
        let mock = TestMockableMock()

        mock.expect(.noParamsVoidAsync())

        let timeout: TimeInterval = 1
        let start = Date()

        let options = XCTExpectedFailure.Options()
        options.issueMatcher = { _ in
            Date().timeIntervalSince(start) > timeout
        }

        XCTExpectFailure(options: options) {
            mock.verifyAsync(timeout: timeout)
        }
    }

    func test_successfulAsyncVerifications_SyncContext_AsyncExecution() {
        let mock = TestMockableMock()

        mock.expect(.noParamsResultAsync()) {
            123
        }

        mock.expect(.noParamsVoidAsync())

        let expectation = expectation(description: "Async task completion")
        Task {
            let result = await mock.noParamsResultAsync()
            XCTAssertEqual(result, 123)
            await mock.noParamsVoidAsync()
            expectation.fulfill()
        }

        let timeout: TimeInterval = 3
        let start = Date()

        mock.verifyAsync(timeout: timeout)

        XCTAssertLessThan(Date().timeIntervalSince(start), timeout + 0.05)

        wait(for: [expectation])
        mock.verify() // Checking if our `verifyAsync` lied to us
    }

    func test_successfulAsyncVerifications_SyncContext_SyncExecution() {
        let mock = TestMockableMock()

        mock.expect(.noParamsVoid())

        mock.noParamsVoid()

        let timeout: TimeInterval = 1
        let start = Date()

        mock.verifyAsync(timeout: timeout)

        XCTAssertLessThan(Date().timeIntervalSince(start), timeout)

        mock.verify() // Checking if our `verifyAsync` lied to us
    }

    func test_successfulAsyncVerifications_AsyncContext() async {
        let mock = TestMockableMock()

        mock.expect(.noParamsResultAsync()) {
            123
        }

        mock.expect(.noParamsVoidAsync())

        let expectation = expectation(description: "Async task completion")
        Task {
            let result = await mock.noParamsResultAsync()
            XCTAssertEqual(result, 123)
            await mock.noParamsVoidAsync()
            expectation.fulfill()
        }

        let timeout: TimeInterval = 3
        let start = Date()

        await mock.verifyAsync(timeout: timeout)

        XCTAssertLessThan(Date().timeIntervalSince(start), timeout + 0.05)

        await XCTWaiter().fulfillment(of: [expectation])

        mock.verify() // Checking if our `verifyAsync` lied to us
    }

    func test_MockingAssociatedTypes() {
        let mock = GenericTestMockableMock<Int, String>()

        mock.expect(.doSomething(with: .value("string"))) { _ in }
        mock.expect(.doSomething(with: 1)) { _ in }
        mock.doSomething(with: "string")
        mock.doSomething(with: 1)
        mock.verify()
    }

    func test_mockingMethodsConstrainedToAssociatedTypes() {
        let mock = GenericTestMockableMock<([Int]) -> String, Int>()

        // Note: The parameter type should be inferred without the need of `.value()`
        // which means correct generation of the parameter constraints
        mock.expect(.doSomethingWithInput([1, 2, 3])) { _ in "123" }
        XCTAssertEqual(mock.doSomethingWithInput([1, 2, 3]), "123")
        mock.verify()
    }

    func test_3DPartyModuleMock_Generated() {
        _ = Test3rdPartyProtocolMock<Int, String>()
    }

    func test_threadSafety() async {
        let mock = TestMockableMock()

        let count = 100

        for _ in 0 ..< count {
            mock.expect(.noParamsVoid())
        }

        await withTaskGroup(of: Void.self) { group in
            for _ in 0 ..< count {
                group.addTask {
                    mock.noParamsVoid()
                }
            }
        }

        mock.verify()
    }
}

// Ensure the mock class is `open`
final class ExtendedTestMockableMock: TestMockableMock, @unchecked Sendable {}

struct TestError: LocalizedError, Equatable {
    private let localizedDescription: String

    init(_ localizedDescription: String) {
        self.localizedDescription = localizedDescription
    }

    var errorDescription: String? {
        localizedDescription
    }
}
