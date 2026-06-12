// ABOUTME: Forwards curated native video-player diagnostics to Dart's
// ABOUTME: UnifiedLogger so playback issues appear in user bug reports

package com.divinevideo.divine_video_player

import android.util.Log

/**
 * Bridges relevant native diagnostics to the Dart side so they are captured by
 * the app's `UnifiedLogger` and included in bug-report log dumps.
 *
 * Native playback code calls these methods for the handful of events worth
 * surfacing to support: player lifecycle, clip-composition skips, asset /
 * playback errors, and audio-track setup. Per-frame / verbose logging must stay
 * on [Log] so it does not flood the captured buffer.
 *
 * `DivineVideoPlayerPlugin` installs [sink] (only for the main FlutterEngine)
 * to forward each entry over the global method channel. Before that is wired
 * (or in unit-test contexts) entries fall back to logcat only.
 */
object DivineVideoPlayerLog {
    /**
     * Forwards `(level, message, name)` to Dart. `level` is one of `debug`,
     * `info`, `warning`, `error`. Set by the plugin; `null` until then.
     */
    @Volatile
    var sink: ((String, String, String) -> Unit)? = null

    fun debug(message: String, name: String = "DivineVideoPlayer") = emit("debug", message, name)

    fun info(message: String, name: String = "DivineVideoPlayer") = emit("info", message, name)

    fun warning(message: String, name: String = "DivineVideoPlayer") = emit("warning", message, name)

    fun error(message: String, name: String = "DivineVideoPlayer") = emit("error", message, name)

    private fun emit(level: String, message: String, name: String) {
        // Keep the logcat fallback so on-device debugging is unchanged.
        when (level) {
            "error" -> Log.e(name, message)
            "warning" -> Log.w(name, message)
            else -> Log.d(name, message)
        }
        sink?.invoke(level, message, name)
    }
}
