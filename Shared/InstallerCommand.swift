import Darwin
import Foundation

/// Only fixed installer tools, with a dedicated process group per invocation. No shell or XPC API.
nonisolated enum InstallerCommand: Sendable {
    case listCompatible
    case verifyPackage(URL)
    case expand(package: URL, destination: URL)
    case createWorkspace(image: URL, gibibytes: Int)
    case attachWorkspace(image: URL, mount: URL)
    case detachWorkspace(device: String)
    case attachSupport(image: URL, mount: URL)

    enum Failure: Error {
        case launch, lostProcess, outputLimit, timedOut
        case failed(Int32)
    }

    private var invocation: (String, [String]) {
        switch self {
        case .listCompatible: ("/usr/sbin/softwareupdate", ["--list-full-installers"])
        case .verifyPackage(let url): ("/usr/sbin/pkgutil", ["--check-signature", url.path])
        case .expand(let package, let destination):
            ("/usr/sbin/pkgutil", ["--expand-full", package.path, destination.path])
        case .createWorkspace(let image, let size):
            (
                "/usr/bin/hdiutil",
                [
                    "create", "-size", "\(size)g", "-type", "SPARSEBUNDLE", "-fs", "APFS", "-volname",
                    "RelentePreparation", image.path,
                ]
            )
        case .attachWorkspace(let image, let mount):
            (
                "/usr/bin/hdiutil",
                ["attach", "-nobrowse", "-owners", "on", "-mountpoint", mount.path, "-plist", image.path]
            )
        case .detachWorkspace(let device):
            ("/usr/bin/hdiutil", ["detach", device])
        case .attachSupport(let image, let mount):
            ("/usr/bin/hdiutil", ["attach", "-readonly", "-nobrowse", "-mountpoint", mount.path, "-plist", image.path])
        }
    }

    /// Cancellation signals the owned group, but never returns before the group is terminal.
    /// The unreaped leader reserves its PID while descendants are being checked/signalled.
    @concurrent
    func run(
        in workingDirectory: URL, timeout: TimeInterval = 600, isCancelled: @Sendable () -> Bool = { false },
        completingCleanup: Bool = false
    )
        async throws -> Data
    {
        if case .listCompatible = self, geteuid() == 0 { throw Failure.launch }
        if !completingCleanup {
            try Task.checkCancellation()
            if isCancelled() { throw CancellationError() }
        }
        if case .detachWorkspace(let device) = self {
            guard device.range(of: "^/dev/disk[0-9]+$", options: .regularExpression) != nil else {
                throw Failure.launch
            }
        }
        let output = workingDirectory.appending(path: "command-\(UUID()).log")
        let errors = output.appendingPathExtension("errors")
        let (executable, arguments) = invocation
        var attributes: posix_spawnattr_t?
        var actions: posix_spawn_file_actions_t?
        guard posix_spawnattr_init(&attributes) == 0 else { throw Failure.launch }
        defer { posix_spawnattr_destroy(&attributes) }
        guard posix_spawn_file_actions_init(&actions) == 0 else { throw Failure.launch }
        defer { posix_spawn_file_actions_destroy(&actions) }
        var emptyMask = sigset_t()
        sigemptyset(&emptyMask)
        var defaults = sigset_t()
        sigemptyset(&defaults)
        for signal in [SIGTERM, SIGINT, SIGHUP, SIGPIPE] { sigaddset(&defaults, signal) }
        guard posix_spawnattr_setsigmask(&attributes, &emptyMask) == 0,
            posix_spawnattr_setsigdefault(&attributes, &defaults) == 0,
            posix_spawnattr_setpgroup(&attributes, 0) == 0,
            posix_spawnattr_setflags(
                &attributes,
                Int16(
                    POSIX_SPAWN_SETPGROUP | POSIX_SPAWN_CLOEXEC_DEFAULT | POSIX_SPAWN_SETSIGMASK | POSIX_SPAWN_SETSIGDEF
                )) == 0,
            posix_spawn_file_actions_addopen(&actions, STDIN_FILENO, "/dev/null", O_RDONLY, 0) == 0,
            posix_spawn_file_actions_addopen(&actions, STDOUT_FILENO, output.path, O_WRONLY | O_CREAT | O_EXCL, 0o600)
                == 0,
            posix_spawn_file_actions_addopen(&actions, STDERR_FILENO, errors.path, O_WRONLY | O_CREAT | O_EXCL, 0o600)
                == 0
        else { throw Failure.launch }
        var environment = ProcessInfo.processInfo.environment
        environment["LC_ALL"] = "C"
        environment["LANG"] = "C"
        environment["TMPDIR"] = workingDirectory.path
        let argv = ([executable] + arguments).map { strdup($0) } + [nil]
        let env = environment.sorted { $0.key < $1.key }.map { strdup("\($0.key)=\($0.value)") } + [nil]
        defer {
            for pointer in argv { free(pointer) }
            for pointer in env { free(pointer) }
        }
        var pid: pid_t = 0
        let spawned = argv.withUnsafeBufferPointer { argv in
            env.withUnsafeBufferPointer { env in
                posix_spawn(&pid, executable, &actions, &attributes, argv.baseAddress!, env.baseAddress!)
            }
        }
        guard spawned == 0 else { throw Failure.launch }
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(timeout))
        var timedOut = false
        var tooMuchOutput = false
        var cancellationRequested = false
        var leaderExited = false
        while true {
            cancellationRequested = cancellationRequested || (!completingCleanup && (Task.isCancelled || isCancelled()))
            timedOut = timedOut || clock.now >= deadline
            let size = (try? output.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            let errorSize = (try? errors.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            tooMuchOutput = tooMuchOutput || size + errorSize > 65_536
            if cancellationRequested || timedOut || tooMuchOutput {
                // The leader has not been reaped: this group ID cannot be reused underneath us.
                _ = kill(-pid, SIGTERM)
            }
            if !leaderExited {
                var info = siginfo_t()
                let result = waitid(P_PID, id_t(pid), &info, WEXITED | WNOHANG | WNOWAIT)
                if result == -1 {
                    if errno == EINTR { continue }
                    // Do not delete working files or signal an identity whose ownership is lost.
                    throw Failure.lostProcess
                }
                leaderExited = info.si_pid == pid
            }
            if leaderExited {
                guard let members = Self.members(of: pid) else { throw Failure.lostProcess }
                if members.allSatisfy({ $0 == pid }) { break }
                // Any surviving member belongs to this invocation; no terminal result yet.
                _ = kill(-pid, SIGTERM)
            }
            // This function is @concurrent; blocking polling does not occupy MainActor and
            // remains paced even after Task cancellation makes Task.sleep throw immediately.
            usleep(50_000)
        }
        var status: Int32 = 0
        guard waitpid(pid, &status, 0) == pid else { throw Failure.lostProcess }
        defer {
            try? FileManager.default.removeItem(at: output)
            try? FileManager.default.removeItem(at: errors)
        }
        if cancellationRequested { throw CancellationError() }
        if timedOut { throw Failure.timedOut }
        if tooMuchOutput { throw Failure.outputLimit }
        guard status & 0x7f == 0, (status >> 8) & 0xff == 0 else { throw Failure.failed(status) }
        let data = try Data(contentsOf: output)
        guard data.count <= 65_536 else { throw Failure.outputLimit }
        return data
    }

    private static func members(of group: pid_t) -> [pid_t]? {
        var pids = [pid_t](repeating: 0, count: 4_096)
        let capacity = pids.count * MemoryLayout<pid_t>.stride
        let bytes = pids.withUnsafeMutableBytes { buffer in
            proc_listpids(UInt32(PROC_PGRP_ONLY), UInt32(group), buffer.baseAddress, Int32(capacity))
        }
        guard bytes >= 0, bytes < capacity else { return nil }
        return Array(pids.prefix(Int(bytes) / MemoryLayout<pid_t>.stride)).filter { $0 > 0 }
    }
}
