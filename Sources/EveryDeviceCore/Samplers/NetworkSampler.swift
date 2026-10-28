import Foundation

public struct NetworkSampler {
    private struct Counters {
        var received: UInt64
        var sent: UInt64
    }

    private var reader = NetworkInterfaceReader()
    private var previous: [String: Counters] = [:]
    private var previousTime: Date?

    public init() {}

    public mutating func sample(at date: Date = Date()) -> NetworkRate {
        var current: [String: Counters] = [:]
        for interface in reader.read() {
            current[interface.name] = Counters(
                received: interface.receivedBytes,
                sent: interface.sentBytes
            )
        }

        // Tunnels (utun/ppp) are excluded implicitly: their traffic already crossed
        // an `en*` interface, so counting both would double the reported rate.
        if current.keys.contains(where: { $0.hasPrefix("en") }) {
            current = current.filter { $0.key.hasPrefix("en") }
        }

        var rate = NetworkRate()
        if let previousTime {
            let elapsed = date.timeIntervalSince(previousTime)
            if elapsed > 0 {
                var received: Double = 0
                var sent: Double = 0
                for (name, counters) in current {
                    guard let old = previous[name] else { continue }
                    received += Double(RateCalculator.delta(current: counters.received, previous: old.received))
                    sent += Double(RateCalculator.delta(current: counters.sent, previous: old.sent))
                }
                rate.downloadBytesPerSec = received / elapsed
                rate.uploadBytesPerSec = sent / elapsed
            }
        }

        previous = current
        previousTime = date
        return rate
    }

    public mutating func reset() {
        previous = [:]
        previousTime = nil
    }
}
