import Foundation
import SQLite3

/// Records one row per sampling tick and keeps only the configured retention
/// window. Process data is intentionally not recorded.
public final class MetricsRecorder {
    public static let retentionRange = 1...24

    public let databaseURL: URL

    private let queue = DispatchQueue(label: "com.everydevice.xxx.recorder", qos: .utility)
    private var db: OpaquePointer?
    private var insertStatement: OpaquePointer?
    private var retentionHours = 24
    private var nextPruneAt: Date?
    private var isRunning = false
    private var lastErrorMessage = "Unknown recorder error"

    private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    private static let insertSQL = """
    INSERT OR REPLACE INTO samples (
        ts, cpu, cpu_load, gpu, gpu_mem, gpu_stale,
        mem_total, mem_app, mem_wired, mem_compressed, mem_swap,
        net_down, net_up, disk_read, disk_write, disk_total, disk_free,
        cpu_temp, gpu_temp, thermal_pressure,
        battery_present, battery_percent, battery_charging, battery_plugged,
        battery_charged, battery_time_remaining, battery_time_to_full
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
    """

    private static let csvHeader = [
        "timestamp_utc",
        "unix_ms",
        "cpu_fraction",
        "cpu_load_average",
        "gpu_fraction",
        "gpu_memory_bytes",
        "gpu_stale",
        "memory_total_bytes",
        "memory_app_bytes",
        "memory_wired_bytes",
        "memory_compressed_bytes",
        "memory_swap_bytes",
        "network_download_bps",
        "network_upload_bps",
        "disk_read_bps",
        "disk_write_bps",
        "disk_total_bytes",
        "disk_free_bytes",
        "cpu_temperature_c",
        "gpu_temperature_c",
        "thermal_pressure",
        "battery_present",
        "battery_fraction",
        "battery_charging",
        "battery_plugged_in",
        "battery_fully_charged",
        "battery_time_remaining_seconds",
        "battery_time_to_full_seconds"
    ].joined(separator: ",")

    public init(databaseURL: URL = MetricsRecorder.defaultDatabaseURL()) {
        self.databaseURL = databaseURL
    }

    public static func defaultDatabaseURL() -> URL {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first
            ?? URL(fileURLWithPath: NSHomeDirectory())
                .appendingPathComponent("Library/Application Support", isDirectory: true)
        return base
            .appendingPathComponent("EveryDevice", isDirectory: true)
            .appendingPathComponent("metrics.sqlite")
    }

    public func start(retentionHours: Int) {
        queue.async { [weak self] in
            guard let self else { return }
            self.retentionHours = Self.clampedRetention(retentionHours)
            self.isRunning = true
            guard self.openIfNeeded() else {
                self.isRunning = false
                return
            }
            self.prune(now: Date())
        }
    }

    public func stop() {
        queue.sync { [weak self] in
            guard let self else { return }
            self.isRunning = false
            if let insertStatement {
                sqlite3_finalize(insertStatement)
                self.insertStatement = nil
            }
            if let db {
                sqlite3_close(db)
                self.db = nil
            }
        }
    }

    public func setRetention(hours: Int) {
        queue.async { [weak self] in
            guard let self else { return }
            self.retentionHours = Self.clampedRetention(hours)
            if self.db != nil {
                self.prune(now: Date())
            }
        }
    }

    public func record(_ snapshot: MetricsSnapshot) {
        queue.async { [weak self] in
            guard let self, self.isRunning, self.openIfNeeded() else { return }
            let now = snapshot.timestamp == .distantPast ? Date() : snapshot.timestamp
            self.insert(snapshot, now: now)
            self.pruneIfNeeded(now: now)
        }
    }

    public func exportAll(to url: URL) throws -> Int {
        try queue.sync {
            guard self.openIfNeeded(), let db else {
                throw self.error(lastErrorMessage)
            }
            guard FileManager.default.createFile(atPath: url.path, contents: nil) else {
                throw self.error("Could not create the export file.")
            }

            let handle = try FileHandle(forWritingTo: url)
            defer { try? handle.close() }
            try handle.truncate(atOffset: 0)
            try handle.write(contentsOf: Data((Self.csvHeader + "\n").utf8))

            guard let statement = try prepareExportStatement(db) else {
                throw error(lastErrorMessage)
            }
            defer { sqlite3_finalize(statement) }

            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            var buffer = ""
            buffer.reserveCapacity(1 << 20)
            var count = 0

            while true {
                let step = sqlite3_step(statement)
                if step == SQLITE_DONE { break }
                guard step == SQLITE_ROW else {
                    throw error(lastErrorMessage)
                }

                let ts = sqlite3_column_int64(statement, 0)
                let date = Date(timeIntervalSince1970: Double(ts) / 1000)
                let fields: [String] = [
                    formatter.string(from: date),
                    "\(ts)",
                    Self.number(statement, 1),
                    Self.number(statement, 2),
                    Self.number(statement, 3),
                    Self.integer(statement, 4),
                    Self.integer(statement, 5),
                    Self.integer(statement, 6),
                    Self.integer(statement, 7),
                    Self.integer(statement, 8),
                    Self.integer(statement, 9),
                    Self.integer(statement, 10),
                    Self.number(statement, 11),
                    Self.number(statement, 12),
                    Self.number(statement, 13),
                    Self.number(statement, 14),
                    Self.integer(statement, 15),
                    Self.integer(statement, 16),
                    Self.number(statement, 17),
                    Self.number(statement, 18),
                    Self.text(statement, 19),
                    Self.integer(statement, 20),
                    Self.number(statement, 21),
                    Self.integer(statement, 22),
                    Self.integer(statement, 23),
                    Self.integer(statement, 24),
                    Self.integer(statement, 25),
                    Self.integer(statement, 26)
                ]

                buffer += fields.joined(separator: ",") + "\n"
                count += 1

                if buffer.utf8.count >= 1 << 20 {
                    try handle.write(contentsOf: Data(buffer.utf8))
                    buffer.removeAll(keepingCapacity: true)
                }
            }

            if !buffer.isEmpty {
                try handle.write(contentsOf: Data(buffer.utf8))
            }
            return count
        }
    }

    private func openIfNeeded() -> Bool {
        if db != nil { return true }

        let directory = databaseURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
        } catch {
            lastErrorMessage = error.localizedDescription
            return false
        }

        var handle: OpaquePointer?
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE
        guard sqlite3_open_v2(databaseURL.path, &handle, flags, nil) == SQLITE_OK,
              let handle else {
            lastErrorMessage = handle.map { String(cString: sqlite3_errmsg($0)) }
                ?? "Could not open the metrics database."
            if let handle { sqlite3_close(handle) }
            return false
        }

        db = handle
        sqlite3_busy_timeout(handle, 1_000)
        _ = execute("PRAGMA journal_mode=WAL;")
        _ = execute("PRAGMA synchronous=NORMAL;")
        _ = execute("PRAGMA auto_vacuum=INCREMENTAL;")
        guard createSchema() else {
            sqlite3_close(handle)
            db = nil
            return false
        }
        guard sqlite3_prepare_v2(handle, Self.insertSQL, -1, &insertStatement, nil) == SQLITE_OK else {
            lastErrorMessage = String(cString: sqlite3_errmsg(handle))
            sqlite3_close(handle)
            db = nil
            return false
        }
        return true
    }

    private func createSchema() -> Bool {
        execute(
            """
            CREATE TABLE IF NOT EXISTS samples (
                ts INTEGER PRIMARY KEY,
                cpu REAL NOT NULL,
                cpu_load REAL,
                gpu REAL,
                gpu_mem INTEGER,
                gpu_stale INTEGER,
                mem_total INTEGER,
                mem_app INTEGER,
                mem_wired INTEGER,
                mem_compressed INTEGER,
                mem_swap INTEGER,
                net_down REAL,
                net_up REAL,
                disk_read REAL,
                disk_write REAL,
                disk_total INTEGER,
                disk_free INTEGER,
                cpu_temp REAL,
                gpu_temp REAL,
                thermal_pressure TEXT,
                battery_present INTEGER,
                battery_percent REAL,
                battery_charging INTEGER,
                battery_plugged INTEGER,
                battery_charged INTEGER,
                battery_time_remaining INTEGER,
                battery_time_to_full INTEGER
            );
            """
        ) && execute("PRAGMA user_version=1;")
    }

    private func insert(_ snapshot: MetricsSnapshot, now: Date) {
        guard let db, let statement = insertStatement else { return }

        sqlite3_reset(statement)
        sqlite3_clear_bindings(statement)

        let ts = Int64((now.timeIntervalSince1970 * 1000).rounded())
        sqlite3_bind_int64(statement, 1, ts)
        sqlite3_bind_double(statement, 2, snapshot.cpu.total)
        sqlite3_bind_double(statement, 3, snapshot.cpu.loadAverage)
        Self.bindDouble(statement, 4, snapshot.gpu.utilization)
        if let memory = snapshot.gpu.memoryInUseBytes {
            sqlite3_bind_int64(statement, 5, Int64(clamping: memory))
        } else {
            sqlite3_bind_null(statement, 5)
        }
        sqlite3_bind_int(statement, 6, snapshot.gpu.isStale ? 1 : 0)

        sqlite3_bind_int64(statement, 7, Int64(clamping: snapshot.memory.totalBytes))
        sqlite3_bind_int64(statement, 8, Int64(clamping: snapshot.memory.appBytes))
        sqlite3_bind_int64(statement, 9, Int64(clamping: snapshot.memory.wiredBytes))
        sqlite3_bind_int64(statement, 10, Int64(clamping: snapshot.memory.compressedBytes))
        sqlite3_bind_int64(statement, 11, Int64(clamping: snapshot.memory.swapUsedBytes))

        sqlite3_bind_double(statement, 12, snapshot.network.downloadBytesPerSec)
        sqlite3_bind_double(statement, 13, snapshot.network.uploadBytesPerSec)
        sqlite3_bind_double(statement, 14, snapshot.disk.readBytesPerSec)
        sqlite3_bind_double(statement, 15, snapshot.disk.writeBytesPerSec)
        sqlite3_bind_int64(statement, 16, Int64(clamping: snapshot.disk.totalBytes))
        sqlite3_bind_int64(statement, 17, Int64(clamping: snapshot.disk.freeBytes))

        Self.bindDouble(statement, 18, snapshot.thermal.cpuCelsius)
        Self.bindDouble(statement, 19, snapshot.thermal.gpuCelsius)
        _ = snapshot.thermal.pressure.rawValue.withCString {
            sqlite3_bind_text(statement, 20, $0, -1, Self.transient)
        }

        sqlite3_bind_int(statement, 21, snapshot.battery.isPresent ? 1 : 0)
        Self.bindDouble(statement, 22, snapshot.battery.percentage)
        sqlite3_bind_int(statement, 23, snapshot.battery.isCharging ? 1 : 0)
        sqlite3_bind_int(statement, 24, snapshot.battery.isPluggedIn ? 1 : 0)
        sqlite3_bind_int(statement, 25, snapshot.battery.isFullyCharged ? 1 : 0)
        Self.bindInt(statement, 26, snapshot.battery.timeRemainingSeconds)
        Self.bindInt(statement, 27, snapshot.battery.timeToFullSeconds)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            lastErrorMessage = String(cString: sqlite3_errmsg(db))
            return
        }
    }

    private func pruneIfNeeded(now: Date) {
        guard let nextPruneAt else {
            prune(now: now)
            return
        }
        if now >= nextPruneAt {
            prune(now: now)
        }
    }

    private func prune(now: Date) {
        guard let db else { return }

        let cutoff = Int64(
            (now.timeIntervalSince1970 - Double(retentionHours) * 3600) * 1000
        )
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(
            db,
            "DELETE FROM samples WHERE ts < ?;",
            -1,
            &statement,
            nil
        ) == SQLITE_OK else {
            lastErrorMessage = String(cString: sqlite3_errmsg(db))
            return
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_int64(statement, 1, cutoff)
        if sqlite3_step(statement) != SQLITE_DONE {
            lastErrorMessage = String(cString: sqlite3_errmsg(db))
            return
        }
        _ = execute("PRAGMA incremental_vacuum;")
        nextPruneAt = now.addingTimeInterval(60)
    }

    private func prepareExportStatement(_ db: OpaquePointer) throws -> OpaquePointer? {
        var statement: OpaquePointer?
        let sql = """
        SELECT ts, cpu, cpu_load, gpu, gpu_mem, gpu_stale,
               mem_total, mem_app, mem_wired, mem_compressed, mem_swap,
               net_down, net_up, disk_read, disk_write, disk_total, disk_free,
               cpu_temp, gpu_temp, thermal_pressure,
               battery_present, battery_percent, battery_charging, battery_plugged,
               battery_charged, battery_time_remaining, battery_time_to_full
        FROM samples
        ORDER BY ts ASC;
        """
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            lastErrorMessage = String(cString: sqlite3_errmsg(db))
            return nil
        }
        return statement
    }

    @discardableResult
    private func execute(_ sql: String) -> Bool {
        guard let db else { return false }
        var errorPointer: UnsafeMutablePointer<CChar>?
        let result = sqlite3_exec(db, sql, nil, nil, &errorPointer)
        if result != SQLITE_OK {
            if let errorPointer {
                lastErrorMessage = String(cString: errorPointer)
                sqlite3_free(errorPointer)
            } else {
                lastErrorMessage = String(cString: sqlite3_errmsg(db))
            }
            return false
        }
        return true
    }

    private func error(_ message: String) -> NSError {
        NSError(
            domain: "EveryDevice.MetricsRecorder",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }

    private static func clampedRetention(_ hours: Int) -> Int {
        min(retentionRange.upperBound, max(retentionRange.lowerBound, hours))
    }

    private static func bindDouble(_ statement: OpaquePointer?, _ index: Int32, _ value: Double?) {
        guard let value, value.isFinite else {
            sqlite3_bind_null(statement, index)
            return
        }
        sqlite3_bind_double(statement, index, value)
    }

    private static func bindInt(_ statement: OpaquePointer?, _ index: Int32, _ value: Int?) {
        guard let value else {
            sqlite3_bind_null(statement, index)
            return
        }
        sqlite3_bind_int64(statement, index, Int64(value))
    }

    private static func number(_ statement: OpaquePointer?, _ index: Int32) -> String {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else { return "" }
        return number(sqlite3_column_double(statement, index))
    }

    private static func number(_ value: Double) -> String {
        guard value.isFinite else { return "" }
        return String(
            format: "%.6f",
            locale: Locale(identifier: "en_US_POSIX"),
            value
        )
    }

    private static func integer(_ statement: OpaquePointer?, _ index: Int32) -> String {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else { return "" }
        return "\(sqlite3_column_int64(statement, index))"
    }

    private static func text(_ statement: OpaquePointer?, _ index: Int32) -> String {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL,
              let pointer = sqlite3_column_text(statement, index) else {
            return ""
        }
        return String(cString: pointer)
    }
}
