import Foundation

typealias HIDClientRef = CFTypeRef
typealias HIDServiceRef = CFTypeRef
typealias HIDEventRef = CFTypeRef

private let kTempEventType: Int32 = 15

private typealias CreateClientFn   = @convention(c) (CFAllocator?) -> HIDClientRef?
private typealias CopyServicesFn   = @convention(c) (HIDClientRef) -> CFArray?
private typealias CopyEventFn      = @convention(c) (HIDServiceRef, Int32, Int64, Int32) -> HIDEventRef?
private typealias GetFloatFn       = @convention(c) (HIDEventRef, Int32) -> Double
private typealias CopyPropertyFn   = @convention(c) (HIDServiceRef, CFString) -> CFTypeRef?

struct ThermalReading {
    let name: String
    let celsius: Double
}

final class TempReader {
    static let shared = TempReader()

    private let createClient: CreateClientFn
    private let copyServices: CopyServicesFn
    private let copyEvent:    CopyEventFn
    private let getFloat:     GetFloatFn
    private let copyProperty: CopyPropertyFn

    private let client: HIDClientRef

    private init?() { return nil }

    static func make() -> TempReader? {
        let h = dlopen(nil, RTLD_LAZY)
        guard
            let cs  = dlsym(h, "IOHIDEventSystemClientCreate"),
            let csvc = dlsym(h, "IOHIDEventSystemClientCopyServices"),
            let ce  = dlsym(h, "IOHIDServiceClientCopyEvent"),
            let gf  = dlsym(h, "IOHIDEventGetFloatValue"),
            let cp  = dlsym(h, "IOHIDServiceClientCopyProperty")
        else { return nil }

        let createFn   = unsafeBitCast(cs,   to: CreateClientFn.self)
        let servicesFn = unsafeBitCast(csvc, to: CopyServicesFn.self)
        let eventFn    = unsafeBitCast(ce,   to: CopyEventFn.self)
        let floatFn    = unsafeBitCast(gf,   to: GetFloatFn.self)
        let propFn     = unsafeBitCast(cp,   to: CopyPropertyFn.self)

        guard let client = createFn(kCFAllocatorDefault) else { return nil }

        return TempReader(
            createClient: createFn,
            copyServices: servicesFn,
            copyEvent: eventFn,
            getFloat: floatFn,
            copyProperty: propFn,
            client: client
        )
    }

    private init(
        createClient: @escaping CreateClientFn,
        copyServices: @escaping CopyServicesFn,
        copyEvent:    @escaping CopyEventFn,
        getFloat:     @escaping GetFloatFn,
        copyProperty: @escaping CopyPropertyFn,
        client: HIDClientRef
    ) {
        self.createClient = createClient
        self.copyServices = copyServices
        self.copyEvent    = copyEvent
        self.getFloat     = getFloat
        self.copyProperty = copyProperty
        self.client       = client
    }

    func readAll() -> [ThermalReading] {
        guard let arr = copyServices(client) else { return [] }
        let count = CFArrayGetCount(arr)
        var results: [ThermalReading] = []
        let field = (kTempEventType << 16) | 0

        for i in 0..<count {
            let raw = CFArrayGetValueAtIndex(arr, i)!
            let svc = Unmanaged<CFTypeRef>.fromOpaque(raw).takeUnretainedValue()
            guard let event = copyEvent(svc, kTempEventType, 0, 0) else { continue }
            let temp = getFloat(event, field)
            guard temp > 0, temp < 200 else { continue }
            let name = copyProperty(svc, "Product" as CFString) as? String ?? "unknown"
            results.append(ThermalReading(name: name, celsius: temp))
        }
        return results
    }

    func summary() -> (cpu: Double, battery: Double?, ssd: Double?) {
        let all = readAll()

        let cpuReadings = all.filter {
            $0.name.hasPrefix("PMU tdie") || $0.name.hasPrefix("PMU2 tdie")
        }.map(\.celsius)

        let cpu = cpuReadings.isEmpty ? 0 :
            cpuReadings.reduce(0, +) / Double(cpuReadings.count)

        let battery = all.filter { $0.name.contains("battery") }.map(\.celsius).max()
        let ssd = all.filter { $0.name.lowercased().contains("nand") }.map(\.celsius).first

        return (cpu: cpu, battery: battery, ssd: ssd)
    }
}
