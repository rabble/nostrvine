// ABOUTME: Forwards curated native camera diagnostics to Dart's UnifiedLogger
// ABOUTME: so recording issues (e.g. missing audio) appear in user bug reports

package co.openvine.divine_camera

import android.util.Log

/**
 * Bridges relevant native diagnostics to the Dart side so they are captured by
 * the app's `UnifiedLogger` and included in bug-report log dumps.
 *
 * Native recording code calls these methods (instead of bare [Log]) for the
 * handful of events worth surfacing to support: audio-permission denial,
 * recording finalize errors, encoder-fallback retries, and audio-source state
 * transitions. Per-frame / verbose logging must stay on [Log] so it does not
 * flood the captured buffer.
 *
 * `DivineCameraPlugin` installs [sink] when attached to the engine to forward
 * each entry over the method channel. Before that is wired (or in unit-test
 * contexts) entries fall back to logcat only.
 */
object DivineCameraLog {
    /**
     * Forwards `(level, message, name)` to Dart. `level` is one of `debug`,
     * `info`, `warning`, `error`. Set by the plugin; `null` until then.
     */
    @Volatile
    var sink: ((String, String, String) -> Unit)? = null

    fun debug(message: String, name: String = "DivineCamera") = emit("debug", message, name)

    fun info(message: String, name: String = "DivineCamera") = emit("info", message, name)

    fun warning(message: String, name: String = "DivineCamera") = emit("warning", message, name)

    fun error(message: String, name: String = "DivineCamera") = emit("error", message, name)

    // android.util.Log-shaped overloads so existing `Log.x(TAG, ...)` call
    // sites forward to the bridge with a mechanical rename. The tag becomes
    // the entry name; a throwable is appended to the message.
    fun d(tag: String, message: String, tr: Throwable? = null) =
        debug(tr?.let { "$message: $it" } ?: message, name = tag)

    fun i(tag: String, message: String, tr: Throwable? = null) =
        info(tr?.let { "$message: $it" } ?: message, name = tag)

    fun w(tag: String, message: String, tr: Throwable? = null) =
        warning(tr?.let { "$message: $it" } ?: message, name = tag)

    fun e(tag: String, message: String, tr: Throwable? = null) =
        error(tr?.let { "$message: $it" } ?: message, name = tag)

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
