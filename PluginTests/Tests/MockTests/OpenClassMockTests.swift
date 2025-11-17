import CoreLocation
import TestMocks
import XCTest

final class OpenClassMockTests: XCTestCase {
    func test_unexpectedCalls() {
        // Failures in async methods cannot be tested this way for the time being
        let mock = TestMockableClassMock(int: 0)

        XCTExpectFailure {
            mock.superNoParamsVoid()
        }

        XCTExpectFailure {
            mock.noParamsVoid()
        }

        XCTExpectFailure {
            mock.withParamsVoid(int: 0, label: "label", "string")
        }

        XCTExpectFailure {
            _ = mock.withParamsResult(int: 0, label: "label", "string")
        }
    }

    func test_failedVerifications() {
        let mock = TestMockableClassMock(int: 0)

        mock.expect(.superNoParamsVoid())
        mock.expect(.noParamsVoid())
        mock.expect(.noParamsVoidAsync())
        mock.expect(.noParamsVoidAsyncThrowing())
        mock.expect(.withParamsVoid(int: 1, label: "label", "string"))
        mock.expect(.withParamsVoidAsync(int: 1, label: "label", "string"))
        mock.expect(.withParamsVoidAsyncThrowing(int: 1, label: "label", "string"))
        mock.expect(.withParamsResult(int: 1, label: "label", "string")) { _, _, _, _ in 1 }
        mock.expect(.withParamsResultAsync(int: 1, label: "label", "string")) { _, _, _, _ in 2 }
        mock.expect(.withParamsAsyncThrowingResult(int: 1, label: "label", "string")) { _, _, _, _ in 3 }

        XCTExpectFailure {
            mock.verify()
        }

        mock.verify() // Should reset expectations after verification
    }

    func test_resetExpectations() {
        let mock = TestMockableClassMock(int: 0)

        mock.expect(.noParamsVoid())
        mock.expect(.noParamsVoidAsync())
        mock.expect(.noParamsVoidAsyncThrowing())

        mock.expect(.noParamsResult()) { _ in 1 }
        mock.expect(.noParamsResultAsync()) { _ in 2 }
        mock.expect(.noParamsAsyncThrowingResult()) { _ in 3 }

        mock.expect(.withParamsVoid(int: 1, label: "label", "string"))
        mock.expect(.withParamsVoidAsync(int: 1, label: "label", "string"))
        mock.expect(.withParamsVoidAsyncThrowing(int: 1, label: "label", "string"))

        mock.expect(.withParamsResult(int: 1, label: "label", "string")) { _, _, _, _ in 1 }
        mock.expect(.withParamsResultAsync(int: 1, label: "label", "string")) { _, _, _, _ in 2 }
        mock.expect(.withParamsAsyncThrowingResult(int: 1, label: "label", "string")) { _, _, _, _ in 3 }

        mock.resetExpectations()

        mock.verify()
    }

    func test_failesWhenCalledInIncorrectOrder() {
        let mock = TestMockableClassMock(int: 0)

        mock.expect(.noParamsVoid())
        mock.expect(.withParamsVoid(int: 1, label: "label", "string"))
        mock.expect(.noParamsVoid())

        XCTExpectFailure {
            mock.noParamsVoid()
            mock.noParamsVoid()
            mock.withParamsVoid(int: 1, label: "label", "string")
        }
    }

    func test_successfulVerifications() async throws {
        let mock = TestMockableClassMock(int: 0)

        mock.expect(set: .readwriteProperty, to: 123)
        mock.expect(.readwriteProperty) { _ in 321 }
        mock.expect(.noParamsVoid())
        mock.expect(.noParamsVoid())
        mock.expect(.noParamsVoidAsync())
        mock.expect(.noParamsVoidAsyncThrowing())
        mock.expect(.withParamsVoid(int: 1, label: "label", "string"))
        mock.expect(.withParamsVoidAsync(int: 1, label: "label", "string"))
        mock.expect(.withParamsVoidAsyncThrowing(int: 1, label: "label", "string"))
        mock.expect(.noParamsResultAsync()) { _ in 1 }
        mock.expect(.noParamsAsyncThrowingResult()) { _ in 1 }
        mock.expect(.withParamsResult(int: 1, label: "label", "string")) { _, _, _, _ in 1 }
        mock.expect(.withParamsResultAsync(int: 1, label: "label", "string")) { _, _, _, _ in 2 }
        mock.expect(.withParamsAsyncThrowingResult(int: 1, label: "label", "string")) { _, _, _, _ in 3 }

        mock.readwriteProperty = 123
        XCTAssertEqual(mock.readwriteProperty, 321)
        mock.noParamsVoid()
        mock.noParamsVoid()
        await mock.noParamsVoidAsync()
        try await mock.noParamsVoidAsyncThrowing()
        mock.withParamsVoid(int: 1, label: "label", "string")
        await mock.withParamsVoidAsync(int: 1, label: "label", "string")
        try await mock.withParamsVoidAsyncThrowing(int: 1, label: "label", "string")
        _ = await mock.noParamsResultAsync()
        _ = try await mock.noParamsAsyncThrowingResult()
        _ = mock.withParamsResult(int: 1, label: "label", "string")
        _ = await mock.withParamsResultAsync(int: 1, label: "label", "string")
        _ = try await mock.withParamsAsyncThrowingResult(int: 1, label: "label", "string")

        mock.verify()
    }

    func test_superInitializer() {
        _ = CLLocationManagerMock()
        _ = TestMockableClassMock(string: "String")
    }

    func test_forwardingToSuper_VoidResult() {
        let mock = TestMockableClassMock(int: 0)

        mock.expect(.noParamsVoid()) { original in
            original()
        }

        mock.noParamsVoid()

        XCTAssertTrue(mock.forwarded)

        mock.verify()
    }

    func test_forwardingToSuperByDefault_VoidResult() {
        let mock = TestMockableClassMock(int: 0)

        mock.expect(.noParamsVoid())

        mock.noParamsVoid()

        XCTAssertTrue(mock.forwarded)

        mock.verify()
    }

    func test_forwardingToSuper_NonVoidResult() async throws {
        let mock = TestMockableClassMock(int: 0)

        mock.expect(.noParamsResult()) { original in
            original()
        }

        mock.expect(.noParamsResultAsync())
        mock.expect(.noParamsAsyncThrowingResult())

        mock.expectedResult = .random(in: 0 ... 10)

        XCTAssertEqual(mock.noParamsResult(), mock.expectedResult)

        let asyncResult = await mock.noParamsResultAsync()
        XCTAssertEqual(asyncResult, mock.expectedResult)

        let asyncThrowingResult = try await mock.noParamsAsyncThrowingResult()
        XCTAssertEqual(asyncThrowingResult, mock.expectedResult)

        XCTAssertTrue(mock.forwarded)

        mock.verify()
    }

    func test_forwardingToSuperByDefault_NonVoidResult() {
        let mock = TestMockableClassMock(int: 0)

        mock.expect(.noParamsResult())

        mock.expectedResult = .random(in: 0 ... 10)

        XCTAssertEqual(mock.noParamsResult(), mock.expectedResult)

        XCTAssertTrue(mock.forwarded)

        mock.verify()
    }

    func test_autoForwarding_SuccessfulVerification() async throws {
        let mock = TestMockableClassMock(int: 0)

        mock.autoForwardingEnabled = true

        XCTAssertEqual(mock.readwriteProperty, 0)
        mock.noParamsVoid()
        mock.noParamsVoid()
        await mock.noParamsVoidAsync()
        try await mock.noParamsVoidAsyncThrowing()
        mock.withParamsVoid(int: 1, label: "label", "string")

        mock.expectedResult = .random(in: 0 ... 10)

        XCTAssertEqual(mock.withParamsResult(int: 1, label: "label", "string"), mock.expectedResult)

        let asyncResult = await mock.noParamsResultAsync()
        XCTAssertEqual(asyncResult, mock.expectedResult)

        let asyncThrowingResult = try await mock.noParamsAsyncThrowingResult()
        XCTAssertEqual(asyncThrowingResult, mock.expectedResult)

        mock.verify()
    }
}
