import Foundation

struct FastRNG: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

enum Sorts {
    // Merge sort, O(n log n) time, O(n) extra space, stable
    static func mergeSort<T>(_ a: inout DynamicArray<T>, key: (T) -> Int) {
        let n = a.count
        if n < 2 { return }
        var src = a.toArray()
        var tmp = src
        sort(&src, &tmp, 0, n, key)
        for i in 0..<n { a[i] = src[i] }
    }

    private static func sort<T>(_ a: inout [T], _ tmp: inout [T], _ lo: Int, _ hi: Int, _ key: (T) -> Int) {
        if hi - lo < 2 { return }
        let mid = (lo + hi) / 2
        sort(&a, &tmp, lo, mid, key)
        sort(&a, &tmp, mid, hi, key)
        var i = lo, j = mid, k = lo
        while i < mid && j < hi {
            if key(a[i]) <= key(a[j]) { tmp[k] = a[i]; i += 1 } else { tmp[k] = a[j]; j += 1 }
            k += 1
        }
        while i < mid { tmp[k] = a[i]; i += 1; k += 1 }
        while j < hi { tmp[k] = a[j]; j += 1; k += 1 }
        for x in lo..<hi { a[x] = tmp[x] }
    }

    // Counting sort, O(n + k) time, O(k) counters (+ output), stable
    static func countingSort<T>(_ items: [T], k: Int, key: (T) -> Int) -> [T] {
        var counts = [Int](repeating: 0, count: k + 1)
        for x in items { counts[key(x) + 1] += 1 }
        for i in 0..<k { counts[i + 1] += counts[i] }
        var out = [T?](repeating: nil, count: items.count)
        for x in items {
            let kk = key(x)
            out[counts[kk]] = x
            counts[kk] += 1
        }
        return out.map { $0! }
    }

    // Fisher-Yates shuffle, O(n)
    static func fisherYates<T, G: RandomNumberGenerator>(_ a: inout DynamicArray<T>, using g: inout G) {
        var i = a.count - 1
        while i > 0 {
            let j = Int.random(in: 0...i, using: &g)
            let t = a[i]
            a[i] = a[j]
            a[j] = t
            i -= 1
        }
    }
}

enum Bench {
    static func run() -> String {
        var rng = FastRNG(seed: 12345)
        var out = "Сортировка 36-карточных ключей, среднее из 50 запусков\n\n"
        for n in [36, 1000, 10000, 100000] {
            var base = [Card]()
            for _ in 0..<n { base.append(Card(id: Int.random(in: 0..<36, using: &rng))) }
            var tm: UInt64 = 0
            var tc: UInt64 = 0
            for _ in 0..<50 {
                var arr = DynamicArray<Card>(base)
                let t0 = DispatchTime.now().uptimeNanoseconds
                Sorts.mergeSort(&arr, key: { $0.id })
                tm += DispatchTime.now().uptimeNanoseconds - t0
                let t1 = DispatchTime.now().uptimeNanoseconds
                let r = Sorts.countingSort(base, k: 36, key: { $0.id })
                tc += DispatchTime.now().uptimeNanoseconds - t1
                if r.count != n || arr.count != n { out += "ошибка\n" }
            }
            out += String(format: "n=%d\n  merge: %.3f ms\n  counting: %.3f ms\n", n, Double(tm) / 50 / 1e6, Double(tc) / 50 / 1e6)
        }
        return out
    }
}
