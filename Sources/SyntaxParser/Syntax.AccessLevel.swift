import Foundation

public extension Syntax {
    enum AccessLevel: String, Equatable, Sendable {
        case `public`
        case `open`
        case `internal`
        case `fileprivate`
        case `private`
        case `package`
    }
}
