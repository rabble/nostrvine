// ABOUTME: Forwards curated native camera diagnostics to Dart's UnifiedLogger
// ABOUTME: so recording issues (e.g. missing audio) appear in user bug reports

import Foundation

/// Bridges relevant native diagnostics to the Dart side so they are captured
/// by the app's `UnifiedLogger` and included in bug-report log dumps.
///
/// Native recording code calls these methods (instead of bare `print`) for the
/// handful of events worth surfacing to support: audio-session configuration,
/// interruptions and recovery, recording start/stop, and asset-writer
/// failures. Per-frame / verbose logging must stay on `print` so it does not
/// flood the captured buffer.
///
/// `DivineCameraPlugin` installs `sink` at registration to forward each entry
/// over the method channel. Before that is wired (or in unit/host contexts)
/// entries fall back to the console only.
final class DivineCameraLog {
    static let shared = DivineCameraLog()

    private init() {}

    /// Forwards `(level, message, name)` to Dart. `level` is one of
    /// `debug`, `info`, `warning`, `error`. Set by the plugin; `nil` until then.
    var sink: ((String, String, String) -> Void)?

    func debug(_ message: String, name: String = "DivineCamera") {
        emit("debug", message, name)
    }

    func info(_ message: String, name: String = "DivineCamera") {
        emit("info", message, name)
    }

    func warning(_ message: String, name: String = "DivineCamera") {
        emit("warning", message, name)
    }

    func error(_ message: String, name: String = "DivineCamera") {
        emit("error", message, name)
    }

    private func emit(_ level: String, _ message: String, _ name: String) {
        // Keep the console fallback so on-device debugging is unchanged.
        print("[\(name)] \(message)")
        sink?(level, message, name)
    }
}
