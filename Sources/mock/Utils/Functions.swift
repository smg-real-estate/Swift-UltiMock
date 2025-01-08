import Foundation

func cast<T2>(_ value: some Any, to type: T2.Type = T2.self, throwing error: Error) throws -> T2 {
    try (value as? T2).unwrap(throwing: error)
}

func cast<T2>(_ value: some Any, to type: T2.Type = T2.self) throws -> T2 {
    try cast(value, to: type, throwing: SimpleError("Failed to cast \(value) to \(T2.self)"))
}
