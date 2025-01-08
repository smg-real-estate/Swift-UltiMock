extension Optional {
    func unwrap(throwing error: @autoclosure () -> Error) throws -> Wrapped {
        guard let wrapped = self else {
            throw error()
        }
        return wrapped
    }

    func unwrap(_ errorMessage: String) throws -> Wrapped {
        try unwrap(throwing: SimpleError(errorMessage))
    }

    var wrapped: Wrapped {
        get throws {
            try unwrap(throwing: SimpleError("Unexpectedly found nil while implicitly unwrapping an Optional value."))
        }
    }
}
