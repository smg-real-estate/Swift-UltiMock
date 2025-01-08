import Foundation

struct SimpleError: LocalizedError {
    private let localizedDescription: String

    init(_ localizedDescription: String) {
        self.localizedDescription = localizedDescription
    }

    var errorDescription: String? {
        localizedDescription
    }
}
