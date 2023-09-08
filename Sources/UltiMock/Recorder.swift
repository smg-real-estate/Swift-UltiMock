import os

public final class Recorder {
    private let protectedStubs = AllocatedUnfairLock(uncheckedState: [Stub]())

    public init() {}

    public var stubs: [Stub] {
        protectedStubs.withLock { $0 }
    }

    public func record(_ stub: Stub) {
        protectedStubs.withLock { stubs in
            stubs.append(stub)
        }
    }

    public func next() -> Stub? {
        protectedStubs.withLock { stubs in
            stubs.isEmpty ? nil : stubs.removeFirst()
        }
    }

    func reset() {
        protectedStubs.withLock { stubs in
            stubs.removeAll()
        }
    }
}
