import Darwin
import Foundation

private let ioHIDEventTypeTemperature: Int64 = 15
private let ioHIDEventFieldTemperature: Int32 = 15 << 16

private typealias HIDCreateFn = @convention(c) (CFAllocator?) -> OpaquePointer?
private typealias HIDSetMatchingFn = @convention(c) (OpaquePointer?, CFDictionary?) -> Void
private typealias HIDCopyServicesFn = @convention(c) (OpaquePointer?) -> OpaquePointer?
private typealias HIDCopyPropertyFn = @convention(c) (OpaquePointer?, CFString) -> OpaquePointer?
private typealias HIDCopyEventFn = @convention(c) (OpaquePointer?, Int64, Int32, Int64) -> OpaquePointer?
private typealias HIDGetFloatFn = @convention(c) (OpaquePointer?, Int32) -> Double

/// Resolves the private IOHID temperature symbols at runtime. Linking them with
/// @_silgen_name makes them strong undefined symbols, so a future macOS that drops
/// one would prevent the whole app from launching.
private struct ThermalAPI {
    let create: HIDCreateFn
    let setMatching: HIDSetMatchingFn
    let copyServices: HIDCopyServicesFn
    let copyProperty: HIDCopyPropertyFn
    let copyEvent: HIDCopyEventFn
    let getFloat: HIDGetFloatFn

    static let shared: ThermalAPI? = {
        guard let handle = dlopen(
            "/System/Library/Frameworks/IOKit.framework/IOKit",
            RTLD_LAZY
        ) else { return nil }

        guard
            let create: HIDCreateFn = DynamicSymbol.load(
                "IOHIDEventSystemClientCreate", as: HIDCreateFn.self, from: handle
            ),
            let setMatching: HIDSetMatchingFn = DynamicSymbol.load(
                "IOHIDEventSystemClientSetMatching", as: HIDSetMatchingFn.self, from: handle
            ),
            let copyServices: HIDCopyServicesFn = DynamicSymbol.load(
                "IOHIDEventSystemClientCopyServices", as: HIDCopyServicesFn.self, from: handle
            ),
            let copyProperty: HIDCopyPropertyFn = DynamicSymbol.load(
                "IOHIDServiceClientCopyProperty", as: HIDCopyPropertyFn.self, from: handle
            ),
            let copyEvent: HIDCopyEventFn = DynamicSymbol.load(
                "IOHIDServiceClientCopyEvent", as: HIDCopyEventFn.self, from: handle
            ),
            let getFloat: HIDGetFloatFn = DynamicSymbol.load(
                "IOHIDEventGetFloatValue", as: HIDGetFloatFn.self, from: handle
            )
        else {
            dlclose(handle)
            return nil
        }

        // The handle stays open for the lifetime of the process; the resolved
        // function pointers point into it.
        return ThermalAPI(
            create: create,
            setMatching: setMatching,
            copyServices: copyServices,
            copyProperty: copyProperty,
            copyEvent: copyEvent,
            getFloat: getFloat
        )
    }()
}

public final class ThermalSampler {
    // Resolved lazily so the HID client setup stays off the main thread.
    private lazy var api: ThermalAPI? = ThermalAPI.shared
    private var client: OpaquePointer?

    public init() {}

    deinit {
        if let client {
            Unmanaged<AnyObject>.fromOpaque(UnsafeRawPointer(client)).release()
        }
    }

    public func sample(includeGPU: Bool = true) -> ThermalInfo {
        guard let api = self.api else { return fallback() }
        ensureClient(api)

        guard let client,
              let rawServices = api.copyServices(client) else {
            return fallback()
        }

        let services = Unmanaged<CFArray>
            .fromOpaque(UnsafeRawPointer(rawServices))
            .takeRetainedValue()

        var cpuValues: [Double] = []
        var gpuValues: [Double] = []
        var foundReading = false

        for index in 0..<CFArrayGetCount(services) {
            guard let rawService = CFArrayGetValueAtIndex(services, index) else { continue }
            let service = OpaquePointer(rawService)

            guard let rawName = api.copyProperty(service, "Product" as CFString) else {
                continue
            }
            let name = Unmanaged<CFString>
                .fromOpaque(UnsafeRawPointer(rawName))
                .takeRetainedValue() as String

            let isCPU = Self.isCPUSensor(name)
            let isGPU = Self.isGPUSensor(name)
            guard isCPU || (includeGPU && isGPU) else { continue }

            // Copying an event is a synchronous round-trip per sensor, so only
            // sensors we actually display are polled.
            guard let rawEvent = api.copyEvent(
                service,
                ioHIDEventTypeTemperature,
                0,
                0
            ) else { continue }

            let celsius = api.getFloat(rawEvent, ioHIDEventFieldTemperature)
            Unmanaged<AnyObject>.fromOpaque(UnsafeRawPointer(rawEvent)).release()

            guard celsius.isFinite, celsius > 1, celsius < 125 else { continue }
            foundReading = true

            if isCPU {
                cpuValues.append(celsius)
            } else {
                gpuValues.append(celsius)
            }
        }

        guard foundReading else { return fallback() }

        var info = ThermalInfo()
        info.sensorAvailable = true
        info.cpuCelsius = average(cpuValues)
        info.gpuCelsius = average(gpuValues)
        info.pressure = Self.currentPressure()
        return info
    }

    private static func isCPUSensor(_ name: String) -> Bool {
        name.hasPrefix("PMU tdie")
            || name.hasPrefix("PMU2 tdie")
            || name.contains("MTR Temp")
            || name.hasPrefix("CPU")
    }

    private static func isGPUSensor(_ name: String) -> Bool {
        name.contains("tdev") || name.lowercased().contains("gpu")
    }

    private func ensureClient(_ api: ThermalAPI) {
        guard client == nil else { return }
        client = api.create(nil)
        if let client {
            let matching: [String: Any] = [
                "PrimaryUsagePage": 0xFF00,
                "PrimaryUsage": 5
            ]
            api.setMatching(client, matching as CFDictionary)
        }
    }

    private func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private func fallback() -> ThermalInfo {
        ThermalInfo(
            cpuCelsius: nil,
            gpuCelsius: nil,
            sensorAvailable: false,
            pressure: Self.currentPressure()
        )
    }

    private static func currentPressure() -> ThermalPressure {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: return .nominal
        case .fair: return .fair
        case .serious: return .serious
        case .critical: return .critical
        @unknown default: return .nominal
        }
    }
}
