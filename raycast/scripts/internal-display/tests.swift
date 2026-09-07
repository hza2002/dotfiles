import Foundation
import Darwin
import CoreGraphics

@main enum Tests {
    static func main() throws {
        if CommandLine.arguments.count == 2 && CommandLine.arguments[1] == "--live" {
            do { try checkLiveModes() }
            catch { fputs("FAIL: \(error)\n", stderr); exit(1) }
            return
        }
        // WindowServer's fallback after the last physical screen disappears (2026-09-06 log).
        let fallback = usableExternal(builtin: false, active: true, vendor: 0x756e6b6e, model: 0x76697274)
        guard !fallback else { throw Failure("System fallback must not count as an external display") }
        assert(usableExternal(builtin: false, active: true, vendor: 0x1326, model: 0x28))
        assert(!usableExternal(builtin: true, active: true, vendor: 0x610, model: 1))
        assert(!usableExternal(builtin: false, active: false, vendor: 0x1326, model: 0x28))
        let unplugged = Snapshot(builtin: nil, internalActive: false, externalCount: fallback ? 1 : 0,
                                 lidClosed: false, mirrored: false)
        assert(decide(Settings(automatic: true, managed: true, builtin: 1), unplugged, sleeping: false) == .on)
        let dual = Snapshot(builtin: 1, internalActive: true, externalCount: 1, lidClosed: false, mirrored: false)
        try checkRecoveryPolicy(dual: dual, unplugged: unplugged)
        try checkDisplaySleepPolicy(dual: dual, unplugged: unplugged)
        try checkRecoveryOwnership(dual: dual)
        try checkUninstall()
        var settings = Settings()
        assert(decide(settings, dual, sleeping: false) == .none)
        settings.automatic = true
        assert(decide(settings, dual, sleeping: false) == .off)
        var solo = dual
        solo.externalCount = 0
        assert(decide(settings, solo, sleeping: false) == .none)
        settings.managed = true
        solo.internalActive = false
        assert(decide(settings, solo, sleeping: false) == .on)
        settings.automatic = false
        assert(decide(settings, dual, sleeping: false) == .on)
        var closed = solo
        closed.lidClosed = true
        assert(decide(settings, closed, sleeping: false) == .none)
        assert(decide(settings, solo, sleeping: true) == .none)
        settings.automatic = true
        var mirrored = dual
        mirrored.mirrored = true
        assert(decide(settings, mirrored, sleeping: false) == .none)
        var off = dual
        off.internalActive = false
        assert(decide(settings, off, sleeping: false) == .none)
        off.externalCount = 0
        assert(decide(settings, off, sleeping: false) == .on)
        settings.automatic = false
        let data = try JSONEncoder().encode(settings)
        let restored = try JSONDecoder().decode(Settings.self, from: data)
        assert(!restored.automatic && restored.managed)
        var pair: [Int32] = [0, 0]
        assert(socketpair(AF_UNIX, SOCK_STREAM, 0, &pair) == 0)
        defer { close(pair[0]); close(pair[1]) }
        _ = fcntl(pair[0], F_SETFL, O_NONBLOCK)
        configureSocket(pair[0], seconds: 1)
        assert(fcntl(pair[0], F_GETFL) & O_NONBLOCK == 0)
        try send(Data("status".utf8), to: pair[0])
        let command = try String(decoding: receive(pair[1]), as: UTF8.self)
        assert(command == "status")
        let response = Reply(ok: true, automatic: false, internalActive: true, message: "paused")
        try send(JSONEncoder().encode(response), to: pair[1])
        let decoded = try JSONDecoder().decode(Reply.self, from: receive(pair[0]))
        assert(decoded.message == "paused")
        print("PASS: display policy, persisted pause, socket flags and request/response framing")
    }

    static func checkRecoveryPolicy(dual: Snapshot, unplugged: Snapshot) throws {
        func expect(_ actual: Action, _ expected: Action, _ message: String) throws {
            guard actual == expected else { throw Failure(message) }
        }
        var settings = Settings(automatic: true, managed: true, builtin: 1)
        var policy = ControlPolicy()
        try expect(policy.action(settings: settings, screen: unplugged, suspended: false, now: 0), .on,
                   "Unplug recovery must bypass disconnect settling")
        policy.completed(.on, succeeded: false, now: 0, settings: &settings)
        guard settings.automatic && settings.managed else {
            throw Failure("Recovery timeout must preserve automatic intent and recovery responsibility")
        }
        try expect(policy.action(settings: settings, screen: unplugged, suspended: false, now: 1), .none,
                   "Failed recovery must back off")
        try expect(policy.action(settings: settings, screen: nil, suspended: false, now: 2), .on,
                   "Lost events and unreadable state must not abandon recovery")
        for time in stride(from: 2.0, through: 302.0, by: 60) {
            policy.completed(.on, succeeded: false, now: time, settings: &settings)
            try expect(policy.action(settings: settings, screen: unplugged, suspended: false, now: time + 60), .on,
                       "Recovery responsibility must survive repeated failures")
        }
        try expect(policy.action(settings: settings, screen: unplugged, suspended: true, now: 400), .none,
                   "Sleep must suspend recovery without discarding it")
        try expect(policy.action(settings: settings, screen: dual, suspended: false, now: 401), .on,
                   "Wake must complete outstanding recovery before disconnecting")
        policy.completed(.on, succeeded: true, now: 402, settings: &settings)
        settings.managed = false
        try expect(policy.action(settings: settings, screen: dual, suspended: false, now: 402), .none,
                   "Recovery success must not immediately close the panel again")
        try expect(policy.action(settings: settings, screen: dual, suspended: false, now: 463), .off,
                   "Automatic intent must resume after recovery and cooldown")
        policy.completed(.off, succeeded: false, now: 464, settings: &settings)
        settings.managed = true
        try expect(policy.action(settings: settings, screen: dual, suspended: false, now: 464), .on,
                   "Failed disconnect requires immediate recovery")
        policy.completed(.on, succeeded: true, now: 465, settings: &settings)
        settings.automatic = false
        settings.managed = false
        try expect(policy.action(settings: settings, screen: dual, suspended: false, now: 600), .none,
                   "Explicit pause must survive successful recovery")

        settings.automatic = true
        policy = ControlPolicy()
        _ = policy.action(settings: settings, screen: dual, suspended: false, now: 0)
        var changed = dual
        changed.externalIdentity = "replacement-or-new-mode"
        try expect(policy.action(settings: settings, screen: changed, suspended: false, now: 3), .none,
                   "Hardware topology changes must restart settling even without CG callback")
        try expect(policy.action(settings: settings, screen: changed, suspended: false, now: 6), .off,
                   "Stable replacement must eventually disconnect")
        settings.managed = true
        settings.automatic = false
        policy.completed(.off, succeeded: true, now: 7, settings: &settings)
        try expect(policy.action(settings: settings, screen: changed, suspended: false, now: 7), .on,
                   "Pause received during disconnect must restore after worker completes")
        policy = ControlPolicy(recovering: true)
        settings.automatic = true
        try expect(policy.action(settings: settings, screen: changed, suspended: false, now: 10), .on,
                   "Restart with persisted recovery responsibility must restore first")
        print("PASS: recovery retry, sleep/wake, unknown state, reconnect, explicit pause and restart policy")
    }

    static func checkDisplaySleepPolicy(dual: Snapshot, unplugged: Snapshot) throws {
        var settings = Settings(automatic: true, managed: true, builtin: 1)
        var policy = ControlPolicy()
        var asleep = unplugged
        asleep.displaysAsleep = true
        // Replay 11:16 / 11:51: display sleep drops active external count before system sleep.
        // No AppKit notification has set the caller's suspended flag.
        for time in stride(from: 0.0, through: 60.0, by: 2) {
            guard policy.action(settings: settings, screen: asleep, suspended: false, now: time) == .none else {
                throw Failure("Fresh display sleep state must prevent recovery even when AppKit missed sleep")
            }
        }
        guard settings.automatic && settings.managed && policy.failures == 0 else {
            throw Failure("Display sleep must retain intent and recovery ownership without failed workers")
        }
        // If unplugged during sleep, the next awake sample must recover without a wake notification.
        guard policy.action(settings: settings, screen: unplugged, suspended: false, now: 62) == .on else {
            throw Failure("Wake without external display must restore internal on the next safety check")
        }
        policy.completed(.on, succeeded: true, now: 63, settings: &settings)
        var sleepingDual = dual
        sleepingDual.displaysAsleep = true
        guard policy.action(settings: settings, screen: sleepingDual, suspended: false, now: 70) == .none,
              policy.action(settings: settings, screen: sleepingDual, suspended: false, now: 80) == .none else {
            throw Failure("Display sleep must also prevent automatic disconnect")
        }
        guard policy.action(settings: settings, screen: dual, suspended: false, now: 82) == .none,
              policy.action(settings: settings, screen: dual, suspended: false, now: 85) == .off else {
            throw Failure("Wake with external display must settle then resume automatic disconnect")
        }
        settings.automatic = false
        settings.managed = true
        policy.recovering = true
        guard policy.action(settings: settings, screen: asleep, suspended: false, now: 90) == .none,
              policy.action(settings: settings, screen: unplugged, suspended: false, now: 92) == .on else {
            throw Failure("Pause during display sleep must persist and restore when awake")
        }
        print("PASS: missed display sleep/wake events, sleep-time unplug and deferred pause recovery")
    }

    static func managedCycle(command: (String) throws -> Reply, verify: (Bool) throws -> Void) throws {
        guard try !command("status").automatic else { throw Failure("Pause automatic mode before the live check") }
        var needsPause = true
        defer {
            if needsPause {
                do {
                    let response = try command("pause")
                    if !response.ok { fputs("Cleanup pending: \(response.message)\n", stderr) }
                } catch { fputs("Cleanup pending in the installed service: \(error)\n", stderr) }
            }
        }
        let enabled = try command("toggle")
        guard enabled.ok && enabled.automatic else { throw Failure(enabled.message) }
        try verify(false)
        let paused = try command("pause")
        guard paused.ok && !paused.automatic else { throw Failure(paused.message) }
        try verify(true)
        needsPause = false
    }

    static func checkRecoveryOwnership(dual: Snapshot) throws {
        let pending = Settings(automatic: false, managed: true, builtin: 1)
        guard !restorationComplete(settings: pending, screen: dual),
              !restorationComplete(settings: Settings(), screen: nil),
              restorationComplete(settings: Settings(), screen: dual) else {
            throw Failure("Uninstall requires both restored state and completed recovery responsibility")
        }
        var inactive = dual
        inactive.internalActive = false
        guard !restorationComplete(settings: Settings(), screen: inactive) else {
            throw Failure("Uninstall must reject an inactive panel even without persisted responsibility")
        }
        var commands: [String] = []
        var verified: [Bool] = []
        func command(_ name: String) -> Reply {
            commands.append(name)
            return Reply(ok: true, automatic: name == "toggle", internalActive: true, message: "test")
        }
        try managedCycle(command: command) { verified.append($0) }
        guard commands == ["status", "toggle", "pause"], verified == [false, true] else {
            throw Failure("Live test must use the installed daemon for both display transitions")
        }
        commands = []
        do {
            try managedCycle(command: command) { _ in throw Failure("simulated display sleep") }
            throw Failure("Live test swallowed verification failure")
        } catch let error as Failure where error.description == "simulated display sleep" {}
        guard commands == ["status", "toggle", "pause"] else {
            throw Failure("Interrupted live test must hand restoration back to the daemon")
        }
        print("PASS: uninstall completion guard and live-test recovery handoff")
    }

    static func checkUninstall() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let files = FileManager.default
        func fixture(_ name: String, _ text: String) throws {
            let url = root.appendingPathComponent(name)
            try files.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(text.utf8).write(to: url)
            try files.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        }
        try fixture("mock-bin/launchctl", "#!/bin/sh\nprintf '%s\\n' \"$*\" >> \"$HOME/calls\"\n[ \"$1\" != print ] || [ \"$TEST_LOADED\" = 1 ]\n")
        let program = ".local/libexec/display-control"
        let plist = "Library/LaunchAgents/com.ghot.display-control.plist"
        let mock = "#!/bin/sh\nprintf '%s\\n' \"$1\" >> \"$HOME/calls\"\n[ \"$1\" != check-restored ] || [ \"$TEST_RESTORED\" = 1 ]\n"
        let manager = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("manage.sh")
        func uninstall(loaded: Bool, restored: Bool) throws -> Int32 {
            try fixture(program, mock)
            try fixture(plist, "fixture")
            try fixture("calls", "")
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = [manager.path, "uninstall"]
            var environment = ProcessInfo.processInfo.environment
            environment["HOME"] = root.path
            environment["PATH"] = root.appendingPathComponent("mock-bin").path + ":/usr/bin:/bin"
            environment["TEST_LOADED"] = loaded ? "1" : "0"
            environment["TEST_RESTORED"] = restored ? "1" : "0"
            process.environment = environment
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try process.run(); process.waitUntilExit()
            return process.terminationStatus
        }
        for loaded in [true, false] {
            guard try uninstall(loaded: loaded, restored: false) != 0,
                  files.fileExists(atPath: root.appendingPathComponent(program).path),
                  files.fileExists(atPath: root.appendingPathComponent(plist).path),
                  !(try String(contentsOf: root.appendingPathComponent("calls"), encoding: .utf8)).contains("bootout") else {
                throw Failure("Deferred recovery must retain service and binary during uninstall")
            }
        }
        guard try uninstall(loaded: true, restored: true) == 0,
              !files.fileExists(atPath: root.appendingPathComponent(program).path),
              !files.fileExists(atPath: root.appendingPathComponent(plist).path),
              (try String(contentsOf: root.appendingPathComponent("calls"), encoding: .utf8)).contains("bootout") else {
            throw Failure("Completed recovery must allow normal uninstall")
        }
        print("PASS: uninstall retains pending recovery and removes a restored installation")
    }

    static func checkLiveModes() throws {
        let screen = try snapshot()
        guard screen.builtin != nil, screen.internalActive, screen.externalCount > 0,
              !screen.lidClosed, !screen.mirrored else { throw Failure("Live check requires an open lid and extended external display") }
        let before = try externalDisplayModes()
        func verify(_ stage: String) throws {
            let current = try externalDisplayModes()
            for (id, mode) in before {
                guard current[id]?.ioDisplayModeID == mode.ioDisplayModeID else {
                    throw Failure("\(stage): external \(id) changed from \(mode.refreshRate) Hz to \(current[id]?.refreshRate ?? 0) Hz")
                }
            }
        }
        try managedCycle(command: request) { enabled in
            let deadline = ProcessInfo.processInfo.systemUptime + 15
            while true {
                let status = try request("status")
                guard status.ok else { throw Failure(status.message) }
                if !status.busy && status.internalActive == enabled { break }
                guard ProcessInfo.processInfo.systemUptime < deadline else { throw Failure("Live check transition timed out; recovery remains with daemon") }
                Thread.sleep(forTimeInterval: 0.2)
            }
            Thread.sleep(forTimeInterval: 1)
            try verify(enabled ? "reconnect" : "disconnect")
        }
        print("PASS: live disconnect/reconnect preserves external modes and restores internal display")
    }
}
