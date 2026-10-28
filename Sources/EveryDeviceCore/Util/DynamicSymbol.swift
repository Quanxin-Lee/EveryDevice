import Darwin

enum DynamicSymbol {
    static func load<T>(_ name: String, as type: T.Type, from handle: UnsafeMutableRawPointer) -> T? {
        guard let symbol = dlsym(handle, name) else { return nil }
        return unsafeBitCast(symbol, to: T.self)
    }
}
