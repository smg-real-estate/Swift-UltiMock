extension Sequence {
    @inlinable
    func sorted<ID>(by id: (Element) -> ID, _ areInIncreasingOrder: (ID, ID) throws -> Bool) rethrows -> [Element] {
        try sorted { try areInIncreasingOrder(id($0), id($1)) }
    }

    @inlinable
    func unique<ID: Hashable>(ids: inout Set<ID>, by id: (Element) -> ID) -> [Element] {
        filter {
            ids.insert(id($0)).inserted
        }
    }

    @inlinable
    func unique<ID: Hashable>(by id: (Element) -> ID) -> [Element] {
        var ids: Set<ID> = []
        return unique(ids: &ids, by: id)
    }

    @inlinable
    func unique(by id: (Element) -> some Hashable, finalValue: (Element, Element) -> Element) -> [Element] {
        Dictionary(
            map { element in
                (id(element), element)
            },
            uniquingKeysWith: finalValue
        )
        .map(\.value)
    }
}
