import Foundation

nonisolated enum CreateInstallMediaPhase: Int, Hashable, Sendable {
    case erase = 0
    case copy = 1
    case makeBootable = 2
}

nonisolated struct CreateInstallMediaProgress: Hashable, Sendable {
    let phase: CreateInstallMediaPhase
    let fraction: Double?
}

nonisolated enum CreateInstallMediaOutputParser {
    static func availableVolume(in line: String) -> URL? {
        guard
            let range = line.range(of: "Install media now available at", options: .caseInsensitive)
        else { return nil }
        let path = line[range.upperBound...]
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"“”"))
        guard path.hasPrefix("/"), !path.contains("\0") else { return nil }
        return URL(filePath: path, directoryHint: .isDirectory)
    }

    static func progress(in line: String) -> CreateInstallMediaProgress? {
        let phase: CreateInstallMediaPhase
        if line.localizedCaseInsensitiveContains("Erasing disk:") {
            phase = .erase
        } else if line.localizedCaseInsensitiveContains("Copying to disk:")
            || line.localizedCaseInsensitiveContains("Copying essential files")
        {
            phase = .copy
        } else if line.localizedCaseInsensitiveContains("Making disk bootable") {
            return CreateInstallMediaProgress(phase: .makeBootable, fraction: nil)
        } else {
            return nil
        }

        guard let percentage = percentages(in: line).last, (0...100).contains(percentage) else {
            return CreateInstallMediaProgress(phase: phase, fraction: nil)
        }
        return CreateInstallMediaProgress(phase: phase, fraction: Double(percentage) / 100)
    }

    private static func percentages(in line: String) -> [Int] {
        let pattern = #"([0-9]{1,3})%"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(line.startIndex..., in: line)
        return expression.matches(in: line, range: range).compactMap { match in
            guard let range = Range(match.range(at: 1), in: line) else { return nil }
            return Int(line[range])
        }
    }
}
