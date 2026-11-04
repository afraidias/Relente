import Darwin
import Foundation

nonisolated enum InstallerPrivateDirectory {
    /// mkdtemp atomically creates a new 0700 directory; it never reuses a pre-existing entry.
    static func create() throws -> URL {
        var template = Array("/private/tmp/Relente-XXXXXX".utf8CString)
        guard let path = mkdtemp(&template) else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        return URL(filePath: String(cString: path), directoryHint: .isDirectory)
    }
    /// Private root-owned preparation folders survive a daemon restart. Their presence is
    /// unresolved work, never permission to detach a device or delete a directory.
    static func hasUnfinishedRootWork() throws -> Bool {
        guard geteuid() == 0 else { return false }
        return try hasUnfinishedWork(in: URL(filePath: "/private/tmp"), ownedBy: 0)
    }

    static func hasUnfinishedWork(in directory: URL, ownedBy owner: uid_t) throws -> Bool {
        for folder in try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
            guard folder.lastPathComponent.range(of: "^Relente-[A-Za-z0-9]{6}$", options: .regularExpression) != nil
            else { continue }
            var info = stat()
            guard lstat(folder.path, &info) == 0 else {
                if errno == ENOENT { continue }
                throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
            }
            if (info.st_mode & S_IFMT) == S_IFDIR && info.st_uid == owner { return true }
        }
        return false
    }

}
