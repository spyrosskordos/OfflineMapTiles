import Foundation

internal final class ProtectedSet<Element: Hashable>: @unchecked Sendable {
    private var set: Set<Element> = []
    private let lock = NSLock()
    
    func insert(_ element: Element) {
        _ = lock.withLock {
            set.insert(element)
        }
    }
    
    func remove(_ element: Element) {
        _ = lock.withLock {
            set.remove(element)
        }
    }
    
    func removeAll() -> [Element] {
        lock.withLock {
            let elements = Array(set)
            set.removeAll()
            return elements
        }
    }
    
    var count: Int {
        lock.withLock {
            set.count
        }
    }
}