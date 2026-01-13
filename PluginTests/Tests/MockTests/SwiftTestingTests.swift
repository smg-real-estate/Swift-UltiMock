import Foundation
import Testing
import TestMocks
import UltiMock

struct SwiftTestingTests {
#if os(macOS)
    @Test
    func failsOnUnexpectedCalls() async {
        await #expect(processExitsWith: .success) {
            let mock = TestMockableMock(line: 10)
            withKnownIssue {
                mock.noParamsVoid()
            } matching: { issue in
                issue.sourceLocation?.line == 10
            }
        }
    }

    @Test
    func failsWhenCalledInIncorrectOrder() async {
        await #expect(processExitsWith: .success) {
            let mock = TestMockableMock()

            mock.expect(.noParamsVoid()) {}
            mock.expect(
                .withParamsVoid(
                    int: 1, label: "label", "string", nil, .value(1), 2, [2], ["1": 2], .any
                ),
                line: 20
            ) { _, _, _, _, _, _, _, _, _ in }
            mock.expect(.noParamsVoid()) {}

            mock.noParamsVoid()
            withKnownIssue {
                mock.noParamsVoid()
                var int = 2
                mock.withParamsVoid(int: 1, label: "label", "string", nil, 1, &int, [2], ["1": 2]) { _ in }
            } matching: { issue in
                issue.sourceLocation?.line == 20
            }
        }
    }
#endif

    @Test
    func failedVerifications() {
        let mock = TestMockableMock()

        mock.expect(.property) { OnlyProperty(value: 1) }

        withKnownIssue {
            mock.verify()
        } matching: { issue in
            issue.comments.first == "Missing expected call: property"
        }
    }

    @Test
    func successfulVerifications() async throws {
        let mock = TestMockableMock()

        mock.expect(.property) { .init(value: 1) }
        mock.expect(.throwingProperty) { throw TestError("throwingProperty_error") }
        mock.expect(.asyncProperty) { 12 }
        mock.expect(.asyncThrowingProperty) { throw TestError("asyncThrowingProperty_error") }
        mock.expect(.readwriteProperty) { 2 }
        mock.expect(set: .readwriteProperty, to: 3) {
            #expect($0 == 3)
        }

        // Expectations fulfillments
        #expect(mock.property == OnlyProperty(value: 1))

        #expect(throws: TestError("throwingProperty_error")) {
            try mock.throwingProperty
        }

        let asyncPropertyResult = await mock.asyncProperty
        #expect(asyncPropertyResult == 12)

        await #expect(throws: TestError("asyncThrowingProperty_error")) {
            try await mock.asyncThrowingProperty
        }

        #expect(mock.readwriteProperty == 2)
        mock.readwriteProperty = 3

        mock.verify()
    }

    @Test
    func failedAsyncVerifications() {
        let mock = TestMockableMock()

        mock.expect(.noParamsVoidAsync())

        let timeout: TimeInterval = 1
        let start = Date()

        withKnownIssue {
            mock.verifyAsync(timeout: timeout)
        } matching: { _ in
            Date().timeIntervalSince(start) > timeout
        }
    }

    @Test
    func successfulAsyncVerifications_AsyncExecution() async {
        let mock = TestMockableMock()

        mock.expect(.noParamsResultAsync()) {
            123
        }

        mock.expect(.noParamsVoidAsync())

        await confirmation { confirm in
            Task {
                let result = await mock.noParamsResultAsync()
                #expect(result == 123)
                await mock.noParamsVoidAsync()
                confirm()
            }

            let timeout: TimeInterval = 3
            let start = Date()

            await mock.verifyAsync(timeout: timeout)

            #expect(Date().timeIntervalSince(start) < timeout + 0.05)
        }

        mock.verify() // Checking if our `verifyAsync` lied to us
    }

    @Test
    func successfulAsyncVerifications_SyncContext_SyncExecution() {
        let mock = TestMockableMock()

        mock.expect(.noParamsVoid())

        mock.noParamsVoid()

        let timeout: TimeInterval = 1
        let start = Date()

        mock.verifyAsync(timeout: timeout)

        #expect(Date().timeIntervalSince(start) < timeout)

        mock.verify() // Checking if our `verifyAsync` lied to us
    }

    @Test
    func successfulTypedThrowingVerification() throws {
        let mock = TestMockableMock()

        if #available(macOS 15, iOS 18, *) {
            // Note: `perform` closure requires an explicit error type declaration,
            // otherwise the compiler cannot infer the correct error type as of Swift 6.2
            // and produces "Invalid conversion of thrown error type 'any Error' to 'SampleError'" error.
            mock.expect(.noParamsVoidTypedThrowing()) { () throws(SampleError) in
                throw .sample
            }

            #expect(throws: SampleError.sample) {
                try mock.noParamsVoidTypedThrowing()
            }
        }
        mock.verify()
    }
}
