import SwiftUI

/// Selectable output for a long creation run; the assistant owns it in memory only.
struct CreationOutputWindow: View {
    let lines: [CreationOutputLine]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Full Creation Log")
                    .font(.title3.weight(.semibold))
                Text("Technical messages reported by macOS while creating the installer.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Divider()

            ScrollView {
                if lines.isEmpty {
                    Text("Waiting for macOS activity…")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                } else {
                    Text(lines.map(Self.formatted).joined(separator: "\n"))
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(20)
        .frame(minWidth: 680, minHeight: 440)
    }

    private static func formatted(_ line: CreationOutputLine) -> String {
        "\(line.timestamp.formatted(date: .omitted, time: .shortened))  \(line.text)"
    }
}

#Preview {
    CreationOutputWindow(lines: [CreationOutputLine(timestamp: .now, text: "Copying to disk: 42%...")])
}
