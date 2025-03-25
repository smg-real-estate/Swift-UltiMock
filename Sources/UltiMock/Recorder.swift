import os
import XCTest

public final class Recorder: Sendable {
    private struct State {
        var stubs: [Stub] = []
        var onEmpty: (() -> Void)?

        mutating func next() -> Stub? {
            stubs.isEmpty ? nil : stubs.removeFirst()
        }

        mutating func reset() {
            onEmpty = nil
            stubs.removeAll()
        }
    }

    private let state = AllocatedUnfairLock(uncheckedState: State())

    public init() {}

    public var stubs: [Stub] {
        state.withLock(\.stubs)
    }

    public func record(_ stub: Stub) {
        state.withLock {
            $0.stubs.append(stub)
        }
    }

    public func next() -> Stub? {
        state.withLock {
            $0.next()
        }
    }

    public func checkVerification() {
        state.withLock {
            if $0.stubs.isEmpty {
                $0.onEmpty?()
            }
        }
    }

    func reset() {
        state.withLock {
            $0.reset()
        }
    }

    func verify(
        fileID: String = #fileID,
        filePath: StaticString = #filePath,
        line: UInt = #line,
        column: Int = #column
    ) {
        if stubs.count > 1 {
            fail(
                "Missing expected calls:\n\(stubs.map { "  \($0.expectation)" }.joined(separator: "\n"))",
                fileID: fileID,
                filePath: filePath,
                line: line,
                column: column
            )
        } else if stubs.count == 1 {
            fail(
                "Missing expected call: \(stubs[0].expectation)",
                fileID: fileID,
                filePath: filePath,
                line: line,
                column: column
            )
        }
        reset()
    }

    func verifyAsync(
        timeout: TimeInterval,
        fileID: String = #fileID,
        filePath: StaticString = #filePath,
        line: UInt = #line,
        column: Int = #column
    ) {
        guard stubs.count > 0 else {
            return
        }

        let expectation = XCTestExpectation(description: "Mock verify \(filePath):\(line)")
        state.withLock {
            guard $0.onEmpty == nil else {
                fail(
                    "Attempt to verify the mock multiple times.",
                    fileID: fileID,
                    filePath: filePath,
                    line: line,
                    column: column
                )
                return
            }
            $0.onEmpty = {
                expectation.fulfill()
            }
        }
        XCTWaiter().wait(for: [expectation], timeout: timeout)
        verify(
            fileID: fileID,
            filePath: filePath,
            line: line,
            column: column
        )
    }
}
