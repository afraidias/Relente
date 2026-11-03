import Foundation

nonisolated enum InstallerAcquisitionStage: String, Hashable, Sendable {
    case connecting, downloading, verifying, preparing

    var title: LocalizedStringResource {
        switch self {
        case .connecting: "Connecting to Apple…"
        case .downloading: "Downloading from Apple…"
        case .verifying: "Verifying Apple’s package…"
        case .preparing: "Preparing the installer…"
        }
    }
}
