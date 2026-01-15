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
    func unique<ID: Hashable>(by id: (Element) -> ID, finalValue: (Element, Element) -> Element) -> [Element] {
        var indexes: [ID: Int] = [:]
        var elements: [Element] = []
        for element in self {
            let elementID = id(element)
            if let index = indexes[elementID] {
                elements[index] = finalValue(elements[index], element)
            } else {
                indexes[elementID] = elements.count
                elements.append(element)
            }
        }
        return elements
    }
}
