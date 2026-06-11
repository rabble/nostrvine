// ABOUTME: Forwards curated native video-player diagnostics to Dart's
// ABOUTME: UnifiedLogger so playback issues appear in user bug reports

import Foundation

/// Bridges relevant native diagnostics to the Dart side so they are captured
/// by the app's `UnifiedLogger` and included in bug-report log dumps.
///
/// Native playback code calls these methods for the handful of events worth
/// surfacing to support: player lifecycle, clip-composition skips, asset /
/// playback errors, and audio-track setup. Per-frame / verbose logging must
/// stay on `print` so it does not flood the captured buffer.
///
/// `DivineVideoPlayerPlugin` installs `sink` to forward each entry over the
/// global method channel. Before that is wired (or in unit/host contexts)
/// entries fall back to the console only.
final class DivineVideoPlayerLog {
    static let shared = DivineVideoPlayerLog()

    private init() {}

    /// Forwards `(level, message, name)` to Dart. `level` is one of
    /// `debug`, `info`, `warning`, `error`. Set by the plugin; `nil` until then.
    var sink: ((String, String, String) -> Void)?

    func debug(_ message: String, name: String = "DivineVideoPlayer") {
        emit("debug", message, name)
    }

    func info(_ message: String, name: String = "DivineVideoPlayer") {
        emit("info", message, name)
    }

    func warning(_ message: String, name: String = "DivineVideoPlayer") {
        emit("warning", message, name)
    }

    func error(_ message: String, name: String = "DivineVideoPlayer") {
        emit("error", message, name)
    }

    private func emit(_ level: String, _ message: String, _ name: String) {
        // Keep the console fallback so on-device debugging is unchanged.
        print("[\(name)] \(message)")
        sink?(level, message, name)
    }
}
