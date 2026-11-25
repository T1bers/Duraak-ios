import Foundation

// MARK: - Dynamic array (own growth logic, capacity doubling)
struct DynamicArray<T>: Collection {
    private var storage: [T?]
    private(set) var count: Int = 0

    init() { storage = [T?](repeating: nil, count: 8) }
    init(_ items: [T]) {
        self.init()
        for x in items { append(x) }
    }

    var startIndex: Int { 0 }
    var endIndex: Int { count }
    func index(after i: Int) -> Int { i + 1 }

    subscript(i: Int) -> T {
        get { storage[i]! }
        set { storage[i] = newValue }
    }

    var last: T? { count == 0 ? nil : storage[count - 1] }

    mutating func append(_ x: T) {
        if count == storage.count { grow() }
        storage[count] = x
        count += 1
    }

    private mutating func grow() {
        var bigger = [T?](repeating: nil, count: storage.count * 2)
        for i in 0..<count { bigger[i] = storage[i] }
        storage = bigger
    }

    @discardableResult
    mutating func removeLast() -> T {
        precondition(count > 0)
        count -= 1
        let x = storage[count]!
        storage[count] = nil
        return x
    }

    @discardableResult
    mutating func remove(at i: Int) -> T {
        let x = storage[i]!
        var j = i
        while j < count - 1 {
            storage[j] = storage[j + 1]
            j += 1
        }
        storage[count - 1] = nil
        count -= 1
        return x
    }

    mutating func removeAll() {
        storage = [T?](repeating: nil, count: 8)
        count = 0
    }

    func toArray() -> [T] {
        var r = [T]()
        r.reserveCapacity(count)
        for i in 0..<count { r.append(storage[i]!) }
        return r
    }
}
extension DynamicArray: Sendable where T: Sendable {}

// MARK: - Stack
struct Stack<T> {
    private(set) var items = DynamicArray<T>()
    var count: Int { items.count }
    var isEmpty: Bool { items.isEmpty }
    mutating func push(_ x: T) { items.append(x) }
    @discardableResult
    mutating func pop() -> T { items.removeLast() }
    func peek() -> T? { items.last }
    mutating func removeAll() { items.removeAll() }
}
extension Stack: Sendable where T: Sendable {}

// MARK: - Circular queue (ring buffer)
struct CircularQueue<T: Equatable> {
    private var buf: [T?]
    private var head = 0
    private(set) var count = 0

    init(capacity: Int) { buf = [T?](repeating: nil, count: max(capacity, 1)) }

    /// i-th element from the front
    subscript(i: Int) -> T { buf[(head + i) % buf.count]! }

    mutating func enqueue(_ x: T) {
        precondition(count < buf.count)
        buf[(head + count) % buf.count] = x
        count += 1
    }

    @discardableResult
    mutating func dequeue() -> T {
        precondition(count > 0)
        let x = buf[head]!
        buf[head] = nil
        head = (head + 1) % buf.count
        count -= 1
        return x
    }

    mutating func rotate(by k: Int) {
        if count == 0 { return }
        for _ in 0..<(k % count) {
            let x = dequeue()
            enqueue(x)
        }
    }

    func contains(_ x: T) -> Bool {
        for i in 0..<count where self[i] == x { return true }
        return false
    }

    mutating func remove(_ x: T) {
        var kept = [T]()
        for i in 0..<count where self[i] != x { kept.append(self[i]) }
        for i in 0..<buf.count { buf[i] = nil }
        head = 0
        count = 0
        for k in kept { enqueue(k) }
    }
}
extension CircularQueue: Sendable where T: Sendable {}

// MARK: - Hash table, separate chaining (Int -> Int)
struct HashTable {
    private struct Entry { var key: Int; var value: Int }
    private var buckets: [[Entry]]
    private(set) var count = 0

    init(capacity: Int = 16) { buckets = [[Entry]](repeating: [], count: capacity) }

    private static func slot(_ key: Int, _ n: Int) -> Int {
        Int((UInt(bitPattern: key) &* 2654435761) % UInt(n))
    }

    func get(_ key: Int) -> Int? {
        for e in buckets[Self.slot(key, buckets.count)] where e.key == key { return e.value }
        return nil
    }

    func contains(_ key: Int) -> Bool { get(key) != nil }

    mutating func set(_ key: Int, _ value: Int) {
        let s = Self.slot(key, buckets.count)
        for i in 0..<buckets[s].count where buckets[s][i].key == key {
            buckets[s][i].value = value
            return
        }
        buckets[s].append(Entry(key: key, value: value))
        count += 1
        if count > buckets.count * 2 { resize() }
    }

    mutating func increment(_ key: Int) { set(key, (get(key) ?? 0) + 1) }

    @discardableResult
    mutating func remove(_ key: Int) -> Bool {
        let s = Self.slot(key, buckets.count)
        for i in 0..<buckets[s].count where buckets[s][i].key == key {
            buckets[s].remove(at: i)
            count -= 1
            return true
        }
        return false
    }

    private mutating func resize() {
        let old = buckets
        buckets = [[Entry]](repeating: [], count: old.count * 2)
        for b in old {
            for e in b { buckets[Self.slot(e.key, buckets.count)].append(e) }
        }
    }
}
extension HashTable: Sendable {}
