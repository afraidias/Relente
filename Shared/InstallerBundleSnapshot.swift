//
//  InstallerBundleSnapshot.swift
//  Relente
//
//  Stable identity of the contents in an installer app, shared by the app and helper.
//  Spec: specs/011-installer-acquisition/spec.md
//

import Foundation

nonisolated enum InstallerBundleSnapshot {
    static func capture(at url: URL) -> (size: Int64, value: String)? {
        guard let rootValues = try? url.resourceValues(forKeys: [.fileResourceIdentifierKey]),
            let resourceIdentifier = rootValues.fileResourceIdentifier,
            let enumerator = FileManager.default.enumerator(
                at: url,
                includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey],
                options: [])
        else { return nil }

        var size: Int64 = 0
        var entries: [String] = []
        for case let item as URL in enumerator {
            guard
                let values = try? item.resourceValues(
                    forKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey, .fileResourceIdentifierKey])
            else { return nil }
            let itemSize = values.isRegularFile == true ? Int64(values.fileSize ?? 0) : 0
            size += itemSize
            let modified = values.contentModificationDate?.timeIntervalSince1970 ?? 0
            let path = item.path(percentEncoded: false).replacingOccurrences(
                of: url.path(percentEncoded: false) + "/", with: "")
            let identifier = values.fileResourceIdentifier.map(String.init(describing:)) ?? ""
            entries.append("\(path)|\(identifier)|\(itemSize)|\(modified)")
        }

        return (size, "\(resourceIdentifier)|\(entries.sorted().joined(separator: "\n"))")
    }
}
