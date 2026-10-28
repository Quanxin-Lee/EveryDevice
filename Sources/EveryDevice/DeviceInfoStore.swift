import Combine
import Darwin
import EveryDeviceCore
import Foundation

final class DeviceInfoStore: ObservableObject {
    @Published private(set) var info: DeviceInfo

    private enum Key {
        static let identifier = "deviceModelIdentifier"
        static let name = "deviceModelName"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let identifier = Self.sysctlString("hw.model")
        let chip = Self.sysctlString("machdep.cpu.brand_string")?
            .replacingOccurrences(of: "Apple ", with: "")

        let cachedIdentifier = defaults.string(forKey: Key.identifier)
        let cachedName = cachedIdentifier == identifier
            ? defaults.string(forKey: Key.name)
            : nil

        info = DeviceInfo(
            modelName: cachedName,
            chipName: chip
        )

        if cachedName == nil {
            loadMarketingName()
        }
    }

    private func loadMarketingName() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            guard let hardware = Self.queryHardware() else { return }

            DispatchQueue.main.async {
                self.info.modelName = hardware.name
                if !hardware.identifier.isEmpty {
                    self.defaults.set(hardware.identifier, forKey: Key.identifier)
                    self.defaults.set(hardware.name, forKey: Key.name)
                }
            }
        }
    }

    private static func queryHardware() -> (name: String, identifier: String)? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        process.arguments = ["SPHardwareDataType", "-json"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return nil
        }

        let pid = process.processIdentifier
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 5) {
            guard process.isRunning else { return }
            process.terminate()
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1) {
                if process.isRunning {
                    kill(pid, SIGKILL)
                }
            }
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0,
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let list = root["SPHardwareDataType"] as? [[String: Any]],
              let item = list.first,
              let name = item["machine_name"] as? String,
              !name.isEmpty else {
            return nil
        }

        let identifier = item["machine_model"] as? String ?? ""
        return (name, identifier)
    }

    private static func sysctlString(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }

        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }

        let value = String(cString: buffer).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
