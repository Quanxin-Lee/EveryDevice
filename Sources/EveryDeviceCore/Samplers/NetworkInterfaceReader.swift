import Darwin
import Foundation

public struct NetworkInterface: Sendable, Equatable, Identifiable {
    public var name: String
    public var receivedBytes: UInt64
    public var sentBytes: UInt64

    public var id: String { name }

    public init(name: String, receivedBytes: UInt64, sentBytes: UInt64) {
        self.name = name
        self.receivedBytes = receivedBytes
        self.sentBytes = sentBytes
    }
}

struct NetworkInterfaceReader {
    private var nameCache: [UInt16: String] = [:]
    private var buffer: [UInt8] = []

    mutating func read() -> [NetworkInterface] {
        var mib: [Int32] = [
            Int32(CTL_NET), Int32(PF_ROUTE), 0, 0, Int32(NET_RT_IFLIST2), 0
        ]
        var length = 0
        guard sysctl(&mib, 6, nil, &length, nil, 0) == 0, length > 0 else { return [] }

        if buffer.count < length {
            buffer = [UInt8](repeating: 0, count: length)
        }
        var actualLength = length
        guard sysctl(&mib, 6, &buffer, &actualLength, nil, 0) == 0, actualLength > 0 else {
            return []
        }

        var result: [NetworkInterface] = []

        buffer.withUnsafeBytes { raw in
            var offset = 0
            while offset + 4 <= actualLength {
                let messageLength = Int(raw.loadUnaligned(fromByteOffset: offset, as: UInt16.self))
                guard messageLength > 0, offset + messageLength <= actualLength else { break }

                let messageType = raw.loadUnaligned(fromByteOffset: offset + 3, as: UInt8.self)
                if messageType == UInt8(RTM_IFINFO2),
                   messageLength >= MemoryLayout<if_msghdr2>.stride {
                    let header = raw.loadUnaligned(fromByteOffset: offset, as: if_msghdr2.self)
                    let name = interfaceName(for: header.ifm_index)
                    let isUp = (header.ifm_flags & IFF_UP) != 0
                    if !name.isEmpty, isUp, name.hasPrefix("en") || name.hasPrefix("ap") {
                        result.append(
                            NetworkInterface(
                                name: name,
                                receivedBytes: header.ifm_data.ifi_ibytes,
                                sentBytes: header.ifm_data.ifi_obytes
                            )
                        )
                    }
                }

                offset += messageLength
            }
        }

        return result
    }

    private mutating func interfaceName(for index: UInt16) -> String {
        if let cached = nameCache[index] { return cached }
        var nameBuffer = [CChar](repeating: 0, count: 16)
        var name = ""
        if if_indextoname(UInt32(index), &nameBuffer) != nil {
            name = String(cString: nameBuffer)
        }
        nameCache[index] = name
        return name
    }
}
