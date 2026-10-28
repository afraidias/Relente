import SwiftUI

/// Activity for the current creation. Closing the popover leaves the operation and output intact.
struct CreationOutputDetails: View {
    let lines: [CreationOutputLine]
    var failure: CreationFailure.Reason?

    @State private var isShowingActivity = false
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Activity", systemImage: "list.bullet") {
            isShowingActivity.toggle()
        }
        .popover(isPresented: $isShowingActivity, arrowEdge: .trailing) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Recent Activity")
                            .font(.headline)
                        Text("Creation steps and progress reported by macOS.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Close", systemImage: "xmark") { isShowingActivity = false }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                }

                Divider()

                ScrollView {
                    if recentEvents.isEmpty && failure == nil {
                        Text("Waiting for activity…")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(recentEvents, id: \.offset) { event in
                                if let progress = CreateInstallMediaOutputParser.progress(in: event.element.text) {
                                    HStack(alignment: .top, spacing: 10) {
                                        Image(systemName: "circle.fill")
                                            .font(.caption2)
                                            .foregroundStyle(Theme.Colors.accent)
                                            .accessibilityHidden(true)
                                        VStack(alignment: .leading, spacing: 2) {
                                            HStack {
                                                Text(Self.phase(for: progress).name)
                                                if let fraction = progress.fraction {
                                                    Text(Int(fraction * 100), format: .percent)
                                                        .foregroundStyle(.secondary)
                                                }
                                            }
                                            Text(event.element.timestamp, format: .dateTime.hour().minute())
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            if let failure {
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(Theme.Colors.danger)
                                        .accessibilityHidden(true)
                                    Text(failure.title)
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: 180)

                Divider()

                Button("Open Full Creation Log…", systemImage: "arrow.up.right.square") {
                    isShowingActivity = false
                    openWindow(id: "creation-output")
                }
                .help("Open the complete technical log in a larger window.")
            }
            .padding(16)
            .frame(width: 360)
        }
    }

    private var recentEvents: [(offset: Int, element: CreationOutputLine)] {
        var events: [(offset: Int, element: CreationOutputLine)] = []
        for event in lines.enumerated() {
            guard let progress = CreateInstallMediaOutputParser.progress(in: event.element.text) else { continue }
            if let last = events.last,
                CreateInstallMediaOutputParser.progress(in: last.element.text)?.phase == progress.phase
            {
                events[events.count - 1] = event
            } else {
                events.append(event)
            }
        }
        return Array(events.suffix(20))
    }

    private static func phase(for progress: CreateInstallMediaProgress) -> CreationPhase {
        switch progress.phase {
        case .erase: return .format
        case .copy: return .copy
        case .makeBootable: return .makeBootable
        }
    }

}

#Preview {
    CreationOutputDetails(lines: [CreationOutputLine(timestamp: .now, text: "Copying to disk: 42%...")])
        .padding()
}
