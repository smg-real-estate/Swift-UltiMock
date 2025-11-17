import Foundation

#if IOS_SDK_16
typealias AllocatedUnfairLock<State> = OSAllocatedUnfairLock<State>
#else
@available(iOS, introduced: 15.0, obsoleted: 16.0)
struct AllocatedUnfairLock<State>: @unchecked Swift.Sendable {
    let lock: Swift.ManagedBuffer<State, os_unfair_lock>

    init(uncheckedState initialState: State) {
        self.lock = .create(minimumCapacity: 1) { buffer in
            // Storing lock in the `elements` as it is shared between all references.
            // 'header' doesn't have a fixed address, as it can be inlined into the struct.
            buffer.withUnsafeMutablePointerToElements { lock in
                lock.initialize(to: .init())
            }
            return initialState
        }
    }

    func withLock<R>(_ body: (inout State) throws -> R) rethrows -> R {
        try lock.withUnsafeMutablePointers { header, lock in
            os_unfair_lock_lock(lock)
            defer {
                os_unfair_lock_unlock(lock)
            }
            return try body(&header.pointee)
        }
    }
}
#endif
