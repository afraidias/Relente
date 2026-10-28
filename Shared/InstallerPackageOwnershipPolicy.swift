import Darwin

nonisolated enum InstallerPackageOwnershipPolicy {
    static func isPrivateRootDirectory(owner: uid_t, mode: mode_t) -> Bool {
        owner == 0 && (mode & S_IFMT) == S_IFDIR && (mode & 0o777) == 0o700
    }

    static func isRootOwnedEntry(owner: uid_t, mode: mode_t) -> Bool {
        owner == 0 && (mode & S_IFMT) != S_IFLNK
    }
}
