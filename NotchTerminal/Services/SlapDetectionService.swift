import Foundation
import Combine
import IOKit
import IOKit.hid

@MainActor
final class SlapDetectionService: ObservableObject {
    static let shared = SlapDetectionService()

    @Published private(set) var isMonitoring = false
    @Published private(set) var statusMessage: String = ""
    var onSlapDetected: (() -> Void)?

    private final class DeviceContext {
        let device: IOHIDDevice
        let reportBuffer: UnsafeMutablePointer<UInt8>
        let bufferSize: Int

        init(device: IOHIDDevice, reportBuffer: UnsafeMutablePointer<UInt8>, bufferSize: Int) {
            self.device = device
            self.reportBuffer = reportBuffer
            self.bufferSize = bufferSize
        }

        deinit {
            reportBuffer.deallocate()
        }
    }

    private var deviceContexts: [DeviceContext] = []
    private var baselineX: Double = 0
    private var baselineY: Double = 0
    private var baselineZ: Double = -1.0
    private let baselineAlpha: Double = 0.001
    private var sampleCount: Int = 0
    private var staValue: Double = 0
    private var ltaValue: Double = 1e-10
    private let staWindow = 5
    private let ltaWindow = 150
    private var staLTAOnThreshold: Double = 5.0
    private var minDeviation: Double = 0.08
    private let cooldownInterval: TimeInterval = 0.75
    private let reportBufSize = 4096

    private var requiredSlaps: Int = 2
    private var slapWindow: TimeInterval = 1.0
    private var pendingSlaps: [Date] = []

    private init() {}

    func updateSensitivity(_ value: Double) {
        let normalized = min(max(value, 0), 100) / 100.0
        staLTAOnThreshold = 8.0 - (normalized * 6.0)
        minDeviation = 0.16 - (normalized * 0.12)
        NSLog("[SlapDetection] sensitivity=%.0f threshold=%.2f minDeviation=%.4f", value, staLTAOnThreshold, minDeviation)
    }

    func updateRequiredSlaps(_ count: Int) {
        requiredSlaps = max(count, 1)
        NSLog("[SlapDetection] requiredSlaps=%d", requiredSlaps)
    }

    func startMonitoring() {
        guard !isMonitoring else { return }
        updateSensitivity(AppPreferences.experimentalFeatureConfiguration().slapDetectionSensitivity)
        updateRequiredSlaps(AppPreferences.experimentalFeatureConfiguration().slapDetectionRequiredSlaps)
        staValue = 0
        ltaValue = 1e-10
        lastSingleSlapTime = .distantPast
        pendingSlaps.removeAll()
        sampleCount = 0

        let isRoot = geteuid() == 0
        if !isRoot {
            statusMessage = "settings.experimental.slapDetection.needsRoot".localized
        }

        let driverCount = wakeSPUDrivers()
        let deviceCount = registerHIDDevices()

        NSLog("[SlapDetection] euid=%d driverCount=%d deviceCount=%d", geteuid(), driverCount, deviceCount)

        if deviceCount == 0 {
            statusMessage = "settings.experimental.slapDetection.noSensor".localized
        } else {
            statusMessage = "settings.experimental.slapDetection.active".localized
        }

        isMonitoring = true
    }

    func stopMonitoring() {
        guard isMonitoring else { return }
        teardownDevices()
        statusMessage = ""
        isMonitoring = false
    }

    @discardableResult
    private func wakeSPUDrivers() -> Int {
        let matching = IOServiceMatching("AppleSPUHIDDriver")
        var iterator: io_iterator_t = 0
        let kr = IOServiceGetMatchingServices(kIOMasterPortDefault, matching, &iterator)
        guard kr == KERN_SUCCESS, iterator != 0 else {
            NSLog("[SlapDetection] wakeSPUDrivers: IOServiceGetMatchingServices failed kr=%d", kr)
            return 0
        }

        var count = 0
        while true {
            let service = IOIteratorNext(iterator)
            guard service != 0 else { break }
            count += 1

            setRegistryInt(service, key: "SensorPropertyReportingState", value: 1)
            setRegistryInt(service, key: "SensorPropertyPowerState", value: 1)
            setRegistryInt(service, key: "ReportInterval", value: 1000)

            NSLog("[SlapDetection] woke SPU driver service %d", service)
            IOObjectRelease(service)
        }

        IOObjectRelease(iterator)
        return count
    }

    private func registerHIDDevices() -> Int {
        let matching = IOServiceMatching("AppleSPUHIDDevice")
        var iterator: io_iterator_t = 0
        let kr = IOServiceGetMatchingServices(kIOMasterPortDefault, matching, &iterator)
        guard kr == KERN_SUCCESS, iterator != 0 else {
            NSLog("[SlapDetection] registerHIDDevices: IOServiceGetMatchingServices failed kr=%d", kr)
            return 0
        }

        var count = 0
        while true {
            let service = IOIteratorNext(iterator)
            guard service != 0 else { break }
            defer { IOObjectRelease(service) }

            let usagePage = registryInt(service, key: "PrimaryUsagePage")
            let usage = registryInt(service, key: "PrimaryUsage")
            NSLog("[SlapDetection] found HID device service=%d usagePage=%lld usage=%lld", service, usagePage ?? -1, usage ?? -1)

            guard let up = usagePage, let u = usage, up == 0xFF00, u == 3 else { continue }

            guard let device = IOHIDDeviceCreate(kCFAllocatorDefault, service) else {
                NSLog("[SlapDetection] IOHIDDeviceCreate failed")
                continue
            }

            let openResult = IOHIDDeviceOpen(device, 0)
            guard openResult == kIOReturnSuccess else {
                NSLog("[SlapDetection] IOHIDDeviceOpen failed kr=%d", openResult)
                continue
            }

            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: reportBufSize)
            buffer.initialize(repeating: 0, count: reportBufSize)

            let ctx = DeviceContext(device: device, reportBuffer: buffer, bufferSize: reportBufSize)
            let contextPtr = Unmanaged.passUnretained(self).toOpaque()

            IOHIDDeviceRegisterInputReportCallback(
                device,
                buffer,
                CFIndex(reportBufSize),
                slapReportCallback,
                contextPtr
            )

            let runLoopMode = CFRunLoopMode.defaultMode!.rawValue as CFString
            IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetMain(), runLoopMode)

            deviceContexts.append(ctx)
            count += 1
            NSLog("[SlapDetection] registered accel device %d", count)
        }

        IOObjectRelease(iterator)
        return count
    }

    private let slapReportCallback: IOHIDReportCallback = { context, result, _, _, _, report, reportLength in
        guard let context else { return }
        let svc = Unmanaged<SlapDetectionService>.fromOpaque(context).takeUnretainedValue()

        let length = Int(reportLength)
        let imuReportLen = 22
        let imuDataOffset = 6

        guard length == imuReportLen else { return }

        let xRaw = report.advanced(by: imuDataOffset).withMemoryRebound(to: Int32.self, capacity: 1) {
            Int32(littleEndian: $0.pointee)
        }
        let yRaw = report.advanced(by: imuDataOffset + 4).withMemoryRebound(to: Int32.self, capacity: 1) {
            Int32(littleEndian: $0.pointee)
        }
        let zRaw = report.advanced(by: imuDataOffset + 8).withMemoryRebound(to: Int32.self, capacity: 1) {
            Int32(littleEndian: $0.pointee)
        }

        let scale = 65536.0
        let fx = Double(xRaw) / scale
        let fy = Double(yRaw) / scale
        let fz = Double(zRaw) / scale

        Task { @MainActor in
            svc.processSample(x: fx, y: fy, z: fz)
        }
    }

    private func setRegistryInt(_ service: io_object_t, key: String, value: Int32) {
        var mutableValue = value
        let cfKey = key as CFString
        let cfValue = CFNumberCreate(kCFAllocatorDefault, .sInt32Type, &mutableValue)
        IORegistryEntrySetCFProperty(service, cfKey, cfValue!)
    }

    private func registryInt(_ service: io_object_t, key: String) -> Int64? {
        guard let unmanaged = IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0) else {
            return nil
        }
        let ref = unmanaged.takeRetainedValue()
        guard CFGetTypeID(ref) == CFNumberGetTypeID() else { return nil }
        var value: Int64 = 0
        guard CFNumberGetValue(ref as! CFNumber, .sInt64Type, &value) else { return nil }
        return value
    }

    private func teardownDevices() {
        let runLoopMode = CFRunLoopMode.defaultMode!.rawValue as CFString
        for ctx in deviceContexts {
            IOHIDDeviceUnscheduleFromRunLoop(ctx.device, CFRunLoopGetMain(), runLoopMode)
            IOHIDDeviceClose(ctx.device, 0)
        }
        deviceContexts.removeAll()
    }

    private var lastSingleSlapTime: Date = .distantPast

    private func processSample(x: Double, y: Double, z: Double) {
        sampleCount += 1

        baselineX += (x - baselineX) * baselineAlpha
        baselineY += (y - baselineY) * baselineAlpha
        baselineZ += (z - baselineZ) * baselineAlpha

        let dx = x - baselineX
        let dy = y - baselineY
        let dz = z - baselineZ
        let deviation = sqrt(dx * dx + dy * dy + dz * dz)

        let energy = deviation * deviation
        staValue += (energy - staValue) / Double(staWindow)
        ltaValue += (energy - ltaValue) / Double(ltaWindow)

        let ratio = staValue / (ltaValue + 1e-30)
        let now = Date()

        if sampleCount % 100 == 0 {
            NSLog("[SlapDetection] sample #%d dev=%.4f ratio=%.2f pendingSlaps=%d", sampleCount, deviation, ratio, pendingSlaps.count)
        }

        guard ratio > staLTAOnThreshold
            && deviation > minDeviation
            && now.timeIntervalSince(lastSingleSlapTime) > cooldownInterval
        else { return }

        lastSingleSlapTime = now

        pendingSlaps.append(now)
        pendingSlaps = pendingSlaps.filter { now.timeIntervalSince($0) < slapWindow }

        NSLog("[SlapDetection] single slap #%d (need %d) dev=%.4f ratio=%.2f", pendingSlaps.count, requiredSlaps, deviation, ratio)

        if pendingSlaps.count >= requiredSlaps {
            NSLog("[SlapDetection] TRIGGERED — %d slaps in %.1fs", pendingSlaps.count, slapWindow)
            pendingSlaps.removeAll()
            onSlapDetected?()
        }
    }
}
