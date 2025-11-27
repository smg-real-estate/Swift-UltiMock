import Foundation

extension String {
    func indented(_ level: Int = 1, width: Int = 4) -> Self {
        components(separatedBy: "\n")
            .map { String(repeating: " ", count: level * width) + $0 }
            .joined(separator: "\n")
    }

    var trimmedBackticks: Self {
        trimmingCharacters(in: .init(charactersIn: "`"))
    }

    var backticked: Self {
        "`\(self)`"
    }

    var trimmed: Self {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var unquoted: Self {
        trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
    }
}

extension Sequence<String> {
    func indented(_ level: Int = 1, width: Int = 4) -> [String] {
        map {
            $0.indented(level, width: width)
        }
    }
}
