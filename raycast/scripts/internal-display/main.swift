import AppKit
import CoreGraphics
import Darwin
import IOKit
import notify

struct Failure: Error, CustomStringConvertible {
    let description: String
    init(_ message: String) { description = message }
}

struct Settings: Codable {
    var automatic = false
    var managed = false
    var builtin: UInt32 = 0
    var boot = ""
}

struct Snapshot {
    var builtin: UInt32?
    var internalActive: Bool
    var externalCount: Int
    var lidClosed: Bool
    var mirrored: Bool
    var externalIdentity = ""
    var displaysAsleep = false
}

enum Action: Equatable { case off, on, none }

struct ControlPolicy {
    var recovering = false
    var failures = 0
    var retryAfter: TimeInterval = 0
    var stableSince: TimeInterval = 0
    var externalIdentity: String?

    mutating func invalidate(now: TimeInterval) { stableSince = now; externalIdentity = nil }

    mutating func action(settings: Settings, screen: Snapshot?, suspended: Bool, now: TimeInterval) -> Action {
        guard !suspended, screen?.displaysAsleep != true else { invalidate(now: now); return .none }
        guard let screen else {
            invalidate(now: now)
            recovering = recovering || settings.managed
            return recovering && now >= retryAfter ? .on : .none
        }
        guard !screen.lidClosed else { invalidate(now: now); return .none }
        let identity = "\(screen.externalCount):\(screen.externalIdentity):\(screen.mirrored)"
        if externalIdentity != identity { externalIdentity = identity; stableSince = now }
        if settings.managed && (!settings.automatic || screen.externalCount == 0) { recovering = true }
        guard now >= retryAfter else { return .none }
        if recovering { return .on }
        if decide(settings, screen, sleeping: false) == .off, now - stableSince >= 3 { return .off }
        return .none
    }

    mutating func completed(_ action: Action, succeeded: Bool, now: TimeInterval, settings: inout Settings) {
        settings.managed = !succeeded || action == .off
        invalidate(now: now)
        if succeeded {
            recovering = false
            if action == .off { failures = 0; retryAfter = 0 }
        } else {
            recovering = true
            failures = min(failures + 1, 6)
            // Disconnect failure gets an immediate recovery; recovery failures back off.
            retryAfter = action == .off ? now : now + min(60, pow(2, Double(failures)))
        }
        if succeeded && action == .on && failures > 0 {
            retryAfter = now + min(60, pow(2, Double(failures)))
        }
    }
}

func logEvent(_ message: String) {
    fputs("\(ISO8601DateFormatter().string(from: Date())) \(message)\n", stderr)
}

func decide(_ settings: Settings, _ screen: Snapshot, sleeping: Bool) -> Action {
    if sleeping || screen.lidClosed { return .none }
    if settings.managed && (!settings.automatic || screen.externalCount == 0) { return .on }
    if settings.automatic && screen.externalCount > 0 && screen.internalActive && !screen.mirrored {
        return .off
    }
    return .none
}

struct Reply: Codable {
    let ok: Bool
    let automatic: Bool
    let internalActive: Bool
    let message: String
    var busy = false
}

func restorationComplete(settings: Settings, screen: Snapshot?) -> Bool {
    !settings.managed && screen?.internalActive == true
}

enum Paths {
    static let home = FileManager.default.homeDirectoryForCurrentUser
    static let directory = home.appendingPathComponent("Library/Application Support/display-control")
    static let state = directory.appendingPathComponent("state.json")
    // sockaddr_un has a short path limit; the per-user temporary directory is already private.
    static let socket = NSTemporaryDirectory() + "display-control.sock"
    static let lock = directory.appendingPathComponent("daemon.lock").path
    static let binary = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL

    static func prepare() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                               attributes: [.posixPermissions: 0o700])
    }

    static func load() throws -> Settings {
        guard FileManager.default.fileExists(atPath: state.path) else { return Settings() }
        return try JSONDecoder().decode(Settings.self, from: Data(contentsOf: state))
    }

    static func save(_ settings: Settings) throws {
        try JSONEncoder().encode(settings).write(to: state, options: .atomic)
    }
}

func bootID() -> String {
    var bytes = [CChar](repeating: 0, count: 128)
    var size = bytes.count
    guard sysctlbyname("kern.bootsessionuuid", &bytes, &size, nil, 0) == 0 else { return "" }
    return String(cString: bytes)
}

func usableExternal(builtin: Bool, active: Bool, vendor: UInt32, model: UInt32) -> Bool {
    // WindowServer creates an "unkn"/"virt" fallback when no physical screen is active.
    // Counting it as an external screen prevents recovery of our disconnected internal panel.
    !builtin && active && !(vendor == 0x756e6b6e && model == 0x76697274)
}

func usableExternal(_ id: UInt32) -> Bool {
    usableExternal(builtin: CGDisplayIsBuiltin(id) != 0, active: CGDisplayIsActive(id) != 0,
                   vendor: CGDisplayVendorNumber(id), model: CGDisplayModelNumber(id))
}

func snapshot() throws -> Snapshot {
    var count: UInt32 = 0
    guard CGGetOnlineDisplayList(0, nil, &count) == .success else { throw Failure("Cannot read displays") }
    var displays = [UInt32](repeating: 0, count: Int(count))
    guard CGGetOnlineDisplayList(count, &displays, &count) == .success else {
        throw Failure("Cannot read displays")
    }
    let ids = Array(displays.prefix(Int(count)))
    let builtin = ids.first { CGDisplayIsBuiltin($0) != 0 }
    let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
    guard service != 0 else { throw Failure("Cannot read lid state") }
    defer { IOObjectRelease(service) }
    guard let closed = IORegistryEntryCreateCFProperty(service, "AppleClamshellState" as CFString,
                                                      kCFAllocatorDefault, 0)?.takeRetainedValue() as? Bool else {
        throw Failure("Cannot read lid state")
    }
    return Snapshot(builtin: builtin, internalActive: builtin.map { CGDisplayIsActive($0) != 0 } ?? false,
                    externalCount: ids.filter { usableExternal($0) }.count,
                    lidClosed: closed, mirrored: ids.contains { CGDisplayMirrorsDisplay($0) != 0 },
                    externalIdentity: ids.filter { usableExternal($0) }.sorted().map {
                        "\($0):\(CGDisplayCopyDisplayMode($0)?.ioDisplayModeID ?? 0)"
                    }.joined(separator: ","), displaysAsleep: CGDisplayIsAsleep(CGMainDisplayID()) != 0)
}

func externalDisplayModes() throws -> [UInt32: CGDisplayMode] {
    var count: UInt32 = 0
    guard CGGetActiveDisplayList(0, nil, &count) == .success else { throw Failure("Cannot enumerate display modes") }
    var ids = [UInt32](repeating: 0, count: Int(count))
    guard CGGetActiveDisplayList(count, &ids, &count) == .success else { throw Failure("Cannot enumerate display modes") }
    var modes: [UInt32: CGDisplayMode] = [:]
    for id in ids.prefix(Int(count)) where usableExternal(id) {
        guard let mode = CGDisplayCopyDisplayMode(id) else { throw Failure("Cannot read external display mode") }
        modes[id] = mode
    }
    return modes
}

// Private ABI declarations adapted from Clamless. Keep CoreGraphics IDs separate from framebuffer IDs.
final class DisplayAPI {
    typealias Enable = @convention(c) (OpaquePointer?, UInt32, Bool) -> Int32
    typealias Open = @convention(c) (UInt32, UInt32, UInt32, UnsafeMutablePointer<OpaquePointer?>) -> Int32
    typealias Power = @convention(c) (OpaquePointer?, UInt32) -> Int32
    let enable: Enable
    let open: Open
    let power: Power

    init() throws {
        func symbol<T>(_ framework: String, _ name: String, _: T.Type) throws -> T {
            guard let handle = dlopen("/System/Library/PrivateFrameworks/\(framework).framework/\(framework)", RTLD_LAZY),
                  let address = dlsym(handle, name) else { throw Failure("Unavailable private API: \(name)") }
            return unsafeBitCast(address, to: T.self)
        }
        enable = try symbol("SkyLight", "SLSConfigureDisplayEnabled", Enable.self)
        open = try symbol("IOMobileFramebuffer", "IOMobileFramebufferOpen", Open.self)
        power = try symbol("IOMobileFramebuffer", "IOMobileFramebufferRequestPowerChange", Power.self)
    }

    func panel(_ enabled: Bool) throws {
        logEvent("api panel power=\(enabled) begin")
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOMobileFramebuffer"), &iterator) == 0 else {
            throw Failure("Cannot enumerate panel services")
        }
        defer { IOObjectRelease(iterator) }
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            let name = IORegistryEntryCreateCFProperty(service, "IONameMatched" as CFString,
                                                       kCFAllocatorDefault, 0)?.takeRetainedValue() as? String
            guard name?.hasPrefix("disp0,") == true || name == "disp0" else { continue }
            var framebuffer: OpaquePointer?
            logEvent("api panel framebuffer open")
            guard open(service, mach_task_self_, 0, &framebuffer) == 0, framebuffer != nil else {
                throw Failure("Cannot open panel framebuffer")
            }
            logEvent("api panel power request=\(enabled)")
            guard power(framebuffer, enabled ? 1 : 0) == 0 else { throw Failure("Panel power request failed") }
            logEvent("api panel power=\(enabled) complete")
            return
        }
        throw Failure("Built-in panel service not found")
    }

    func layout(_ id: UInt32, enabled: Bool, preserveModes: Bool = true) throws {
        logEvent("api layout display=\(id) enabled=\(enabled) begin")
        guard id != 0 else { throw Failure("Built-in display ID unavailable; open the lid and retry") }
        let modes = preserveModes ? try externalDisplayModes() : [:]
        var config: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&config) == .success, let config else {
            throw Failure("Cannot begin display configuration")
        }
        logEvent("api layout configure enabled=\(enabled)")
        guard enable(config, id, enabled) == 0 else {
            CGCancelDisplayConfiguration(config)
            throw Failure("Cannot \(enabled ? "restore" : "disconnect") display layout")
        }
        logEvent("api layout commit enabled=\(enabled)")
        guard CGCompleteDisplayConfiguration(config, .forSession) == .success else {
            throw Failure("Cannot commit display configuration")
        }
        logEvent("api layout enabled=\(enabled) complete")
        // The internal hotplug loads a saved topology AFTER the transaction, overriding
        // mode requests within it. Correct only modes that actually changed.
        let changed = modes.filter { CGDisplayIsActive($0.key) != 0 &&
            CGDisplayCopyDisplayMode($0.key)?.ioDisplayModeID != $0.value.ioDisplayModeID }
        guard !changed.isEmpty else { return }
        logEvent("api external modes restore begin")
        var restore: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&restore) == .success, let restore else {
            throw Failure("Cannot begin external mode restoration")
        }
        for (display, mode) in changed {
            guard CGConfigureDisplayWithDisplayMode(restore, display, mode, nil) == .success else {
                CGCancelDisplayConfiguration(restore)
                throw Failure("Cannot restore external display mode for \(display)")
            }
        }
        // CGDisplaySetDisplayMode is app-scoped and would revert when this worker exits.
        guard CGCompleteDisplayConfiguration(restore, .forSession) == .success else {
            throw Failure("Cannot commit external mode restoration")
        }
        for (display, mode) in changed where CGDisplayIsActive(display) != 0 {
            guard CGDisplayCopyDisplayMode(display)?.ioDisplayModeID == mode.ioDisplayModeID else {
                throw Failure("Cannot restore external display mode for \(display)")
            }
        }
        logEvent("api external modes restore complete")
    }

    func apply(_ action: Action, cachedID: UInt32) throws {
        if action == .off {
            let screen = try snapshot()
            guard !screen.lidClosed, CGDisplayIsAsleep(CGMainDisplayID()) == 0 else {
                throw Failure("Display session is asleep or lid is closed")
            }
            let id = screen.builtin ?? cachedID
            guard screen.externalCount > 0, screen.internalActive, !screen.mirrored else {
                throw Failure("Disconnect requires an active external display and extended desktop")
            }
            do {
                try layout(id, enabled: false)
                // Hot-unplug can race the first configuration request.
                guard try snapshot().externalCount > 0 else { throw Failure("External display disconnected") }
                try panel(false)
            } catch {
                try? panel(true)
                try? layout(id, enabled: true, preserveModes: false)
                throw error
            }
        } else {
            let initial = try? snapshot()
            guard initial?.lidClosed != true else { throw Failure("Lid is closed; restore deferred") }
            guard initial?.displaysAsleep != true else { throw Failure("Display session is asleep; restore deferred") }
            let id = initial?.builtin ?? cachedID
            // External mode discovery/restoration must never prevent emergency recovery.
            let modes = (try? externalDisplayModes()) ?? [:]
            var lastError: Error = Failure("Restore failed")
            for _ in 0..<4 {
                var powered = false
                do { try panel(true); powered = true } catch { lastError = error }
                do {
                    let current = try? snapshot()
                    if current?.internalActive != true {
                        try layout(current?.builtin ?? id, enabled: true, preserveModes: false)
                    }
                    Thread.sleep(forTimeInterval: 0.3)
                    if powered, try snapshot().internalActive {
                        // Best effort only: the recovery result describes the internal panel.
                        for (display, mode) in modes where CGDisplayIsActive(display) != 0 &&
                            CGDisplayCopyDisplayMode(display)?.ioDisplayModeID != mode.ioDisplayModeID {
                            var config: CGDisplayConfigRef?
                            logEvent("api recovery external mode display=\(display) begin")
                            if CGBeginDisplayConfiguration(&config) == .success, let config {
                                if CGConfigureDisplayWithDisplayMode(config, display, mode, nil) == .success {
                                    if CGCompleteDisplayConfiguration(config, .forSession) != .success {
                                        logEvent("restore: external mode preservation failed for \(display)")
                                    }
                                } else { CGCancelDisplayConfiguration(config) }
                            }
                            logEvent("api recovery external mode display=\(display) complete")
                        }
                        return
                    }
                } catch { lastError = error }
                Thread.sleep(forTimeInterval: 0.3)
            }
            throw lastError
        }
    }
}

func address<T>(_ body: (UnsafePointer<sockaddr>, socklen_t) throws -> T) throws -> T {
    var value = sockaddr_un()
    value.sun_family = sa_family_t(AF_UNIX)
    let bytes = Array(Paths.socket.utf8CString)
    guard bytes.count <= MemoryLayout.size(ofValue: value.sun_path) else { throw Failure("Socket path too long") }
    withUnsafeMutableBytes(of: &value.sun_path) { target in
        bytes.withUnsafeBytes { target.copyBytes(from: $0) }
    }
    let length = socklen_t(MemoryLayout<sockaddr_un>.size)
    value.sun_len = UInt8(length)
    return try withUnsafePointer(to: &value) {
        try $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { try body($0, length) }
    }
}

func configureSocket(_ fd: Int32, seconds: Int) {
    // Accepted sockets inherit the listener's nonblocking flag on macOS.
    _ = fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) & ~O_NONBLOCK)
    _ = fcntl(fd, F_SETFD, FD_CLOEXEC)
    var timeout = timeval(tv_sec: seconds, tv_usec: 0)
    setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout.size(ofValue: timeout)))
    setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout.size(ofValue: timeout)))
    var one: Int32 = 1
    setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &one, socklen_t(MemoryLayout.size(ofValue: one)))
}

func receive(_ fd: Int32) throws -> Data {
    var result = Data()
    var byte: UInt8 = 0
    while result.count < 4096 {
        guard read(fd, &byte, 1) == 1 else { throw Failure("Service disconnected or timed out") }
        if byte == 10 { return result }
        result.append(byte)
    }
    throw Failure("Oversized service message")
}

func send(_ data: Data, to fd: Int32) throws {
    let frame = data + Data([10])
    try frame.withUnsafeBytes { bytes in
        var offset = 0
        while offset < bytes.count {
            let n = write(fd, bytes.baseAddress!.advanced(by: offset), bytes.count - offset)
            guard n > 0 else { throw Failure("Cannot send service message") }
            offset += n
        }
    }
}

func request(_ command: String) throws -> Reply {
    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    guard fd >= 0 else { throw Failure("Cannot create socket") }
    defer { close(fd) }
    configureSocket(fd, seconds: 25)
    guard try address({ connect(fd, $0, $1) }) == 0 else {
        throw Failure("Display service is not running; run ./manage.sh start from raycast/scripts/internal-display")
    }
    try send(Data(command.utf8), to: fd)
    return try JSONDecoder().decode(Reply.self, from: receive(fd))
}

final class Daemon {
    var settings: Settings
    var policy = ControlPolicy()
    var busy = false
    var sleeping = false
    var displaysSleeping = false
    var powerToken: Int32 = -1
    var eventPending = false
    var waitingForStability = false
    var observedState: String?
    var terminating = false
    var lastError: String?
    var timer: DispatchWorkItem?
    var observers: [NSObjectProtocol] = []
    var signals: [DispatchSourceSignal] = []
    var socketSource: DispatchSourceRead?
    var ioPort: IONotificationPortRef?
    var ioObjects: [io_object_t] = []
    var interests: [UInt64: io_object_t] = [:]
    var lockFD: Int32 = -1

    init() throws {
        try Paths.prepare()
        lockFD = Darwin.open(Paths.lock, O_CREAT | O_RDWR, 0o600)
        guard lockFD >= 0, flock(lockFD, LOCK_EX | LOCK_NB) == 0 else { throw Failure("Service already running") }
        _ = fcntl(lockFD, F_SETFD, FD_CLOEXEC)
        settings = try Paths.load()
        let boot = bootID()
        if boot.isEmpty || settings.boot != boot {
            settings.builtin = 0
            settings.managed = false
        }
        settings.boot = boot
        policy.recovering = settings.managed
        if let id = try? snapshot().builtin { settings.builtin = id }
        try Paths.save(settings)
    }

    func reply(_ ok: Bool = true, message: String? = nil) -> Reply {
        let screen = try? snapshot()
        let text = message ?? lastError ?? (settings.automatic
            ? (screen?.externalCount == 0 ? "自动模式已开启 · 等待外接显示器" : "自动模式已开启 · 内屏\(screen?.internalActive == true ? "使用中" : "已关闭")")
            : "自动模式已暂停 · 内屏\(screen?.internalActive == true ? "已恢复" : "待恢复")")
        return Reply(ok: ok && lastError == nil, automatic: settings.automatic,
                     internalActive: screen?.internalActive ?? false, message: text, busy: busy)
    }

    func persist() throws { try Paths.save(settings) }

    func event() {
        guard !terminating, !eventPending else { return }
        eventPending = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.eventPending = false
            self?.reconcile()
        }
    }

    func topologyEvent() {
        policy.invalidate(now: ProcessInfo.processInfo.systemUptime)
        event()
    }

    func refreshDisplaySleep(source: String) {
        let asleep = CGDisplayIsAsleep(CGMainDisplayID()) != 0
        guard asleep != displaysSleeping else { return }
        displaysSleeping = asleep
        policy.invalidate(now: ProcessInfo.processInfo.systemUptime)
        logEvent("displays \(asleep ? "sleep" : "wake"); source=\(source)")
    }

    func scheduleCheck() {
        timer?.cancel()
        // Keep the existing safety check through display-only sleep: AppKit can miss wake too.
        guard !terminating, !sleeping,
              (settings.automatic && waitingForStability) || settings.managed || policy.recovering else { return }
        let work = DispatchWorkItem { [weak self] in self?.reconcile() }
        timer = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: work)
    }

    func reconcile(completion: ((Reply) -> Void)? = nil) {
        guard !terminating else { completion?(reply(false, message: "服务正在退出")); return }
        refreshDisplaySleep(source: "reconcile")
        guard !busy else { completion?(reply(false, message: "正在切换，请稍后再试")); return }
        do {
            let screen = try? snapshot()
            let observed = screen.map {
                "internal=\($0.internalActive) external=\($0.externalCount) modes=\($0.externalIdentity) lidClosed=\($0.lidClosed) displaysAsleep=\($0.displaysAsleep)"
            } ?? "display state unavailable"
            if observedState != observed { observedState = observed; logEvent(observed) }
            waitingForStability = screen.map { $0.externalCount > 0 && $0.internalActive && !$0.lidClosed && !$0.mirrored } ?? false
            if let id = screen?.builtin, settings.builtin != id {
                settings.builtin = id
                try? persist()
            }
            let action = policy.action(settings: settings, screen: screen,
                                       suspended: sleeping || displaysSleeping,
                                       now: ProcessInfo.processInfo.systemUptime)
            guard action != .none else {
                if settings.automatic && screen?.mirrored == true {
                    completion?(reply(false, message: "自动模式已开启；请先将显示器设为扩展桌面"))
                } else { completion?(reply()) }
                scheduleCheck()
                return
            }
            settings.managed = true
            // Persist before disconnect; failure to persist must not block recovery.
            if action == .off { try persist() } else { try? persist() }
            busy = true
            timer?.cancel()
            logEvent("worker \(action) started; automatic=\(settings.automatic) external=\(screen?.externalCount ?? -1)")
            runWorker(action) { [self] error in
                busy = false
                policy.completed(action, succeeded: error == nil, now: ProcessInfo.processInfo.systemUptime, settings: &settings)
                if let error {
                    lastError = "内屏恢复待完成：\(error)"
                    logEvent("worker \(action) failed: \(error); recovery retained; attempt=\(policy.failures)")
                } else {
                    lastError = nil
                    logEvent("worker \(action) succeeded; automatic=\(settings.automatic)")
                }
                do { try persist() } catch { lastError = "Cannot save mode: \(error)" }
                completion?(reply(error == nil))
                scheduleCheck()
                if !terminating { event() }
            }
        } catch {
            lastError = String(describing: error)
            completion?(reply(false))
            scheduleCheck()
        }
    }

    func runWorker(_ action: Action, completion: @escaping (String?) -> Void) {
        let id = settings.builtin
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = Paths.binary
            process.arguments = ["worker", action == .off ? "off" : "on", String(id)]
            let pipe = Pipe()
            process.standardError = pipe
            process.standardOutput = FileHandle.nullDevice
            let done = DispatchSemaphore(value: 0)
            process.terminationHandler = { _ in done.signal() }
            var failure: String?
            let started = ProcessInfo.processInfo.systemUptime
            do {
                try process.run()
                pipe.fileHandleForWriting.closeFile()
                var exited = true
                if done.wait(timeout: .now() + 8) == .timedOut {
                    kill(process.processIdentifier, SIGKILL)
                    exited = done.wait(timeout: .now() + 1) == .success
                    failure = "Display operation timed out"
                }
                if exited {
                    let output = pipe.fileHandleForReading.readDataToEndOfFile()
                    // Forward success warnings and timeout breadcrumbs as well as failures.
                    FileHandle.standardError.write(output)
                    if failure == nil, process.terminationStatus != 0 {
                        failure = String(decoding: output, as: UTF8.self).split(separator: "\n").last.map(String.init)
                            ?? "Display operation failed"
                    }
                }
                logEvent("worker \(action) finished; exited=\(exited) duration=\(String(format: "%.2f", ProcessInfo.processInfo.systemUptime - started))s")
            } catch { failure = String(describing: error) }
            let result = failure
            DispatchQueue.main.async { completion(result) }
        }
    }

    func command(_ command: String, completion: @escaping (Reply) -> Void) {
        if command == "status" { completion(reply()); return }
        guard command == "toggle" || command == "pause" else {
            completion(reply(false, message: "Unknown command")); return
        }
        guard !terminating else {
            completion(reply(false, message: "正在切换，请稍后再试")); return
        }
        let previous = settings
        settings.automatic = command == "toggle" ? !settings.automatic : false
        // Explicit pause also restores a screen disconnected by another application.
        if !settings.automatic { settings.managed = true; policy.recovering = true }
        do { try persist() } catch {
            settings = previous
            completion(reply(false, message: "Cannot save mode: \(error)")); return
        }
        lastError = nil
        policy.retryAfter = 0
        policy.failures = 0
        policy.invalidate(now: ProcessInfo.processInfo.systemUptime)
        logEvent("command \(command); automatic=\(settings.automatic)")
        if busy { completion(reply(message: settings.automatic ? "自动模式已开启" : "自动模式已暂停 · 正在恢复内屏")); return }
        reconcile(completion: completion)
    }

    func start() throws {
        displaysSleeping = CGDisplayIsAsleep(CGMainDisplayID()) != 0
        logEvent("daemon started; automatic=\(settings.automatic) recovery=\(settings.managed) displaysSleeping=\(displaysSleeping)")
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw Failure("Cannot create server socket") }
        unlink(Paths.socket)
        guard try address({ bind(fd, $0, $1) }) == 0, listen(fd, 8) == 0 else {
            close(fd); throw Failure("Cannot bind server socket")
        }
        chmod(Paths.socket, 0o600)
        _ = fcntl(fd, F_SETFD, FD_CLOEXEC)
        _ = fcntl(fd, F_SETFL, O_NONBLOCK)
        socketSource = DispatchSource.makeReadSource(fileDescriptor: fd, queue: .main)
        socketSource?.setEventHandler { [weak self] in
            let client = accept(fd, nil, nil)
            guard client >= 0 else { return }
            configureSocket(client, seconds: 2)
            DispatchQueue.global().async {
                do {
                    var user: uid_t = 0
                    var group: gid_t = 0
                    guard getpeereid(client, &user, &group) == 0, user == getuid() else {
                        close(client); return
                    }
                    let command = String(decoding: try receive(client), as: UTF8.self)
                    DispatchQueue.main.async {
                        guard let self else { close(client); return }
                        self.command(command) { response in
                            DispatchQueue.global().async {
                                defer { close(client) }
                                if let data = try? JSONEncoder().encode(response) { try? send(data, to: client) }
                            }
                        }
                    }
                } catch { close(client) }
            }
        }
        socketSource?.resume()
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        guard CGDisplayRegisterReconfigurationCallback({ _, flags, context in
            guard let context else { return }
            let daemon = Unmanaged<Daemon>.fromOpaque(context).takeUnretainedValue()
            DispatchQueue.main.async {
                daemon.policy.invalidate(now: ProcessInfo.processInfo.systemUptime)
                if !flags.contains(.beginConfigurationFlag) { daemon.event() }
            }
        }, pointer) == .success else { throw Failure("Cannot subscribe to display changes") }
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            self?.sleeping = true; self?.timer?.cancel()
            logEvent("system sleep")
        })
        observers.append(center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.sleeping = false; self?.event()
            self?.policy.invalidate(now: ProcessInfo.processInfo.systemUptime)
            logEvent("system wake")
        })
        observers.append(center.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { [weak self] _ in
            self?.refreshDisplaySleep(source: "workspace sleep")
            self?.event()
        })
        observers.append(center.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.refreshDisplaySleep(source: "workspace wake")
            self?.event()
        })
        // powerd publishes this on display/user activity changes on Apple Silicon.
        // Use it only to trigger a fresh CG query, not as a physical-display count.
        let powerResult = notify_register_dispatch("com.apple.system.powermanagement.useractivity2", &powerToken, .main) { [weak self] _ in
            self?.refreshDisplaySleep(source: "powerd")
            self?.event()
        }
        if powerResult != NOTIFY_STATUS_OK { logEvent("power event subscription failed: \(powerResult); safety checks remain active") }
        subscribeHardware(pointer)
        for number in [SIGTERM, SIGINT] {
            signal(number, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: number, queue: .main)
            source.setEventHandler { [weak self] in self?.stop() }
            source.resume()
            signals.append(source)
        }
        event()
    }

    func subscribeHardware(_ pointer: UnsafeMutableRawPointer) {
        guard let port = IONotificationPortCreate(kIOMainPortDefault) else { return }
        ioPort = port
        IONotificationPortSetDispatchQueue(port, .main)
        for name in ["IODisplayConnect", "IOMobileFramebuffer", "AppleDCPDPTXRemotePortUFP", "AppleATCDPAltModePort"] {
            for kind in [kIOFirstMatchNotification, kIOTerminatedNotification] {
                var iterator: io_iterator_t = 0
                let result = IOServiceAddMatchingNotification(port, kind, IOServiceMatching(name), { context, iterator in
                    guard let context else { return }
                    let daemon = Unmanaged<Daemon>.fromOpaque(context).takeUnretainedValue()
                    daemon.watchServices(iterator)
                    daemon.topologyEvent()
                }, pointer, &iterator)
                if result == 0 {
                    ioObjects.append(iterator)
                    watchServices(iterator)
                }
            }
        }
        let root = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        if root != 0 {
            defer { IOObjectRelease(root) }
            var notifier: io_object_t = 0
            if IOServiceAddInterestNotification(port, root, kIOGeneralInterest, { context, _, _, _ in
                guard let context else { return }
                Unmanaged<Daemon>.fromOpaque(context).takeUnretainedValue().event()
            }, pointer, &notifier) == 0 { ioObjects.append(notifier) }
        }
    }

    func watchServices(_ iterator: io_iterator_t) {
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            var id: UInt64 = 0
            guard let port = ioPort, IORegistryEntryGetRegistryEntryID(service, &id) == 0,
                  interests[id] == nil else { continue }
            var notifier: io_object_t = 0
            let pointer = Unmanaged.passUnretained(self).toOpaque()
            if IOServiceAddInterestNotification(port, service, kIOGeneralInterest, { context, service, message, _ in
                guard let context else { return }
                let daemon = Unmanaged<Daemon>.fromOpaque(context).takeUnretainedValue()
                // IOMessage.h's function-like macro is not imported into Swift.
                if message == 0xe0000010 {
                    var id: UInt64 = 0
                    if IORegistryEntryGetRegistryEntryID(service, &id) == 0,
                       let notifier = daemon.interests.removeValue(forKey: id) { IOObjectRelease(notifier) }
                }
                daemon.topologyEvent()
            }, pointer, &notifier) == 0 { interests[id] = notifier }
        }
    }

    func stop() {
        guard !terminating else { return }
        terminating = true
        timer?.cancel()
        func finish() {
            if busy {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: finish)
                return
            }
            if settings.managed, let screen = try? snapshot(), !screen.lidClosed, !screen.displaysAsleep, !sleeping {
                busy = true
                runWorker(.on) { [self] error in
                    settings.managed = error != nil
                    try? persist()
                    unlink(Paths.socket)
                    exit(error == nil ? 0 : 1)
                }
            } else { unlink(Paths.socket); exit(0) }
        }
        finish()
    }
}

#if !TESTING
@main enum Main {
    static func main() {
        umask(0o077)
        do {
            let args = Array(CommandLine.arguments.dropFirst())
            switch args.first {
            case "daemon":
                let daemon = try Daemon()
                try daemon.start()
                withExtendedLifetime(daemon) { RunLoop.main.run() }
            case "toggle", "status", "pause":
                let response = try request(args[0])
                print(response.message)
                if !response.ok { exit(1) }
            case "probe":
                _ = try DisplayAPI()
                let screen = try snapshot()
                print("private APIs available; internal=\(screen.internalActive) external=\(screen.externalCount) lidClosed=\(screen.lidClosed) mirrored=\(screen.mirrored)")
            case "check-restored":
                guard restorationComplete(settings: try Paths.load(), screen: try? snapshot()) else {
                    throw Failure("内屏尚未恢复，保留服务；请唤醒并打开屏幕后重试卸载")
                }
            case "worker":
                guard args.count == 3, ["on", "off"].contains(args[1]), let id = UInt32(args[2]) else {
                    throw Failure("Invalid worker arguments")
                }
                try DisplayAPI().apply(args[1] == "off" ? .off : .on, cachedID: id)
            default: throw Failure("Usage: display-control daemon|toggle|status|probe")
            }
        } catch { fputs("\(error)\n", stderr); exit(1) }
    }
}
#endif
