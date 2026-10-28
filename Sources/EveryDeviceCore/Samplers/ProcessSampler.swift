import Darwin
import Foundation

public struct ProcessSampler {
    private struct Previous {
        var cpuNanos: UInt64
        var startTime: UInt64
    }

    private var previous: [Int32: Previous] = [:]
    private var previousTime: Date?
    private var nameCache: [Int32: (startTime: UInt64, name: String)] = [:]
    private var lastNameRefresh: Date?

    public init() {}

    public mutating func sample(at date: Date = Date()) -> (processes: [ProcessUsage], unreadable: Int) {
        let pids = allPIDs()
        let elapsed = previousTime.map { date.timeIntervalSince($0) } ?? 0

        if let last = lastNameRefresh, date.timeIntervalSince(last) >= 60 {
            nameCache.removeAll(keepingCapacity: true)
            lastNameRefresh = date
        }
        if lastNameRefresh == nil {
            lastNameRefresh = date
        }

        var result: [ProcessUsage] = []
        result.reserveCapacity(pids.count)
        var newPrevious: [Int32: Previous] = [:]
        newPrevious.reserveCapacity(pids.count)
        var updatedNames: [Int32: (startTime: UInt64, name: String)] = [:]
        updatedNames.reserveCapacity(pids.count)
        var unreadable = 0

        for pid in pids where pid > 0 {
            guard let usage = readUsage(pid) else {
                unreadable += 1
                continue
            }

            newPrevious[pid] = Previous(cpuNanos: usage.cpuNanos, startTime: usage.startTime)

            var cpuFraction: Double = 0
            if elapsed > 0,
               let old = previous[pid],
               old.startTime == usage.startTime {
                cpuFraction = Double(
                    RateCalculator.delta(current: usage.cpuNanos, previous: old.cpuNanos)
                ) / (elapsed * 1_000_000_000)
            }

            let name: String
            if let cached = nameCache[pid], cached.startTime == usage.startTime {
                name = cached.name
            } else {
                name = processName(pid) ?? "PID \(pid)"
            }
            updatedNames[pid] = (usage.startTime, name)

            result.append(
                ProcessUsage(
                    pid: pid,
                    name: name,
                    cpuFraction: max(0, cpuFraction),
                    memoryBytes: usage.memoryBytes
                )
            )
        }

        previous = newPrevious
        nameCache = updatedNames
        previousTime = date
        return (result, unreadable)
    }

    public mutating func reset() {
        previous = [:]
        previousTime = nil
        nameCache.removeAll(keepingCapacity: true)
        lastNameRefresh = nil
    }

    private func allPIDs() -> [pid_t] {
        let estimate = proc_listallpids(nil, 0)
        guard estimate > 0 else { return [] }

        var pids = [pid_t](repeating: 0, count: Int(estimate) + 64)
        let capacityBytes = Int32(pids.count * MemoryLayout<pid_t>.size)
        let returned = proc_listallpids(&pids, capacityBytes)
        guard returned > 0 else { return [] }

        let count = min(Int(returned), pids.count)
        return pids.prefix(count).filter { $0 > 0 }
    }

    private func readUsage(_ pid: Int32) -> (cpuNanos: UInt64, memoryBytes: UInt64, startTime: UInt64)? {
        var info = rusage_info_v4()
        let status: Int32 = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { rebound in
                proc_pid_rusage(pid, RUSAGE_INFO_V4, rebound)
            }
        }

        if status == 0 {
            return (
                info.ri_user_time &+ info.ri_system_time,
                info.ri_phys_footprint,
                info.ri_proc_start_abstime
            )
        }

        var taskInfo = proc_taskinfo()
        let size = Int32(MemoryLayout<proc_taskinfo>.size)
        let read = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &taskInfo, size)

        if read == size {
            return (
                taskInfo.pti_total_user &+ taskInfo.pti_total_system,
                taskInfo.pti_resident_size,
                0
            )
        }

        return nil
    }

    private func processName(_ pid: Int32) -> String? {
        var buffer = [CChar](repeating: 0, count: 64)
        let length = proc_name(pid, &buffer, UInt32(buffer.count))
        guard length > 0 else { return nil }
        return String(cString: buffer)
    }
}
