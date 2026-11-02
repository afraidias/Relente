//
//  SoftwareUpdateOutputParser.swift
//  Relente
//
//  Parses the documented text emitted by softwareupdate for full installers and progress.
//  Spec: specs/011-installer-acquisition/spec.md
//

import Foundation

nonisolated enum SoftwareUpdateOutputParser {

    struct ParseError: Error, Hashable {}

    /// Reads full installer entries from `softwareupdate --list-full-installers` output.
    static func fullInstallers(from output: String) throws(ParseError) -> [AvailableInstaller] {
        var installers: [AvailableInstaller] = []
        var seen: Set<String> = []

        for rawLine in output.split(whereSeparator: \.isNewline) {
            var line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("* ") {
                line.removeFirst(2)
            }
            guard line.hasPrefix("Title:") else { continue }

            var fields: [String: String] = [:]
            for component in line.split(separator: ",") {
                let pair = component.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
                guard pair.count == 2 else { continue }
                let key = pair[0].trimmingCharacters(in: .whitespaces)
                let value = pair[1].trimmingCharacters(in: .whitespaces)
                fields[key] = value
            }

            guard
                let title = fields["Title"], !title.isEmpty,
                let versionText = fields["Version"], let version = MacOSVersion(versionText)
            else { throw ParseError() }

            let build = fields["Build"].flatMap { $0.isEmpty ? nil : $0 }
            let installer = AvailableInstaller(
                title: title, version: version, build: build, sizeInBytes: fields["Size"].flatMap(Self.sizeInBytes))
            if seen.insert(installer.id).inserted {
                installers.append(installer)
            }
        }

        return AvailableInstaller.sorted(installers)
    }

    private static func sizeInBytes(_ text: String) -> Int64? {
        let endOfNumber = text.firstIndex { !$0.isNumber && $0 != "." } ?? text.endIndex
        guard endOfNumber > text.startIndex,
            let value = Double(text[..<endOfNumber]), value.isFinite, value >= 0
        else { return nil }

        let unit = text[endOfNumber...].trimmingCharacters(in: .whitespaces).uppercased()
        let multiplier: Double
        switch unit {
        case "B": multiplier = 1
        case "K", "KIB": multiplier = 1_024
        case "M", "MIB": multiplier = 1_048_576
        case "G", "GIB": multiplier = 1_073_741_824
        case "KB": multiplier = 1_000
        case "MB": multiplier = 1_000_000
        case "GB": multiplier = 1_000_000_000
        default: return nil
        }

        let bytes = value * multiplier
        guard bytes.isFinite, bytes <= Double(Int64.max) else { return nil }
        return Int64(bytes.rounded())
    }

    /// Returns a normalized 0...1 fraction only when a percentage appears in command output.
    static func reportedProgress(in output: String) -> Double? {
        for rawLine in output.split(whereSeparator: \.isNewline).reversed() {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard line.hasPrefix("Installing:") || line.hasPrefix("Downloading:") else { continue }
            guard
                let colon = line.firstIndex(of: ":"),
                let percent = line.lastIndex(of: "%")
            else { continue }

            let number = line[line.index(after: colon)..<percent].trimmingCharacters(in: .whitespaces)
            guard let value = Double(number), value.isFinite, (0...100).contains(value) else { continue }
            return value / 100
        }
        return nil
    }
}
