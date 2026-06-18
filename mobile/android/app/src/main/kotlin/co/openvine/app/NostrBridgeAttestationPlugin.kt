// ABOUTME: Android counterpart of the iOS NostrBridgeAttestationPlugin (#3979).
// ABOUTME: Swaps the divineSandboxBridge JS-interface for a WebMessageListener that reports isMainFrame.

package co.openvine.app

import android.net.Uri
import android.util.Log
import android.webkit.WebView
import androidx.annotation.VisibleForTesting
import androidx.webkit.JavaScriptReplyProxy
import androidx.webkit.WebMessageCompat
import androidx.webkit.WebViewCompat
import androidx.webkit.WebViewFeature
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.webviewflutter.WebViewFlutterAndroidExternalApi

/**
 * Thin native plugin that gives the Nostr sandbox bridge a platform-attested
 * `isMainFrame` signal on Android, mirroring the iOS plugin from #3979.
 *
 * The `webview_flutter_android` `addJavaScriptChannel` path routes through
 * `WebView.addJavascriptInterface`, whose `@JavascriptInterface` callbacks
 * receive only a `String` — no frame metadata. `WebViewCompat`'s
 * `addWebMessageListener` instead delivers `(message, sourceOrigin, isMainFrame,
 * replyProxy)` to the listener. This plugin obtains the live `WebView` via the
 * package's public external API and swaps the `divineSandboxBridge` interface
 * for such a listener, then streams `{message, isMainFrame}` back to Dart over
 * an EventChannel — the same contract the Dart layer already consumes on iOS.
 *
 * Lifecycle is single-instance (see [NostrBridgeAttestationPolicy]): a second
 * sandbox WebView is refused with ALREADY_ATTACHED so the Dart layer logs the
 * degraded posture and falls back to nonce-only enforcement instead of silently
 * stealing the sink from the first.
 *
 * Dart drives two calls:
 *   attach(webViewId, allowedOriginRules) — swaps the channel for the listener
 *   detach(webViewId)                     — removes the listener
 *
 * The EventChannel delivers maps: { "message": String, "isMainFrame": Boolean }.
 */
class NostrBridgeAttestationPlugin(
    private val flutterEngine: FlutterEngine,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    companion object {
        const val METHOD_CHANNEL_NAME = "co.openvine/nostr_bridge_attestation"
        const val EVENT_CHANNEL_NAME = "co.openvine/nostr_bridge_attestation/events"
        const val BRIDGE_CHANNEL_NAME = "divineSandboxBridge"
        private const val TAG = "NostrBridgeAttestation"
        private const val LOG_PREFIX = "[NostrBridgeAttestation]"
    }

    private val policy = NostrBridgeAttestationPolicy()
    private var eventSink: EventChannel.EventSink? = null
    private var listener: FrameAttestingWebMessageListener? = null

    private val methodChannel =
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL_NAME)
    private val eventChannel =
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL_NAME)

    init {
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val webViewId = (call.argument<Number>("webViewId"))?.toLong()
        if (webViewId == null) {
            Log.w(TAG, "$LOG_PREFIX attach/detach called without Int64 webViewId")
            result.error("INVALID_ARGUMENT", "webViewId (Int64) required", null)
            return
        }

        when (call.method) {
            "attach" -> {
                val rules = call.argument<List<String>>("allowedOriginRules")
                if (rules == null) {
                    result.error(
                        "INVALID_ARGUMENT",
                        "allowedOriginRules (List<String>) required",
                        null,
                    )
                    return
                }
                attachListener(webViewId, rules, result)
            }
            "detach" -> {
                detachListener(webViewId)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    private fun attachListener(
        webViewId: Long,
        allowedOriginRules: List<String>,
        result: MethodChannel.Result,
    ) {
        when (val attach = policy.attach(webViewId)) {
            NostrBridgeAttestationPolicy.AttachResult.NoOp -> {
                result.success(null)
                return
            }
            is NostrBridgeAttestationPolicy.AttachResult.AlreadyAttached -> {
                Log.w(
                    TAG,
                    "$LOG_PREFIX attach refused: already attached to ${attach.existing}; " +
                        "requested $webViewId. Dart will fall back to nonce-only enforcement.",
                )
                result.error(
                    "ALREADY_ATTACHED",
                    "Sandbox attestation already attached to webView ${attach.existing}",
                    null,
                )
                return
            }
            NostrBridgeAttestationPolicy.AttachResult.Ok -> Unit
        }

        if (!WebViewFeature.isFeatureSupported(WebViewFeature.WEB_MESSAGE_LISTENER)) {
            policy.detach(webViewId)
            Log.w(
                TAG,
                "$LOG_PREFIX attach failed: WEB_MESSAGE_LISTENER unsupported on this WebView. " +
                    "Dart will fall back to nonce-only enforcement.",
            )
            result.error(
                "FEATURE_UNSUPPORTED",
                "WebViewFeature.WEB_MESSAGE_LISTENER is not supported",
                null,
            )
            return
        }

        val webView = WebViewFlutterAndroidExternalApi.getWebView(flutterEngine, webViewId)
        if (webView == null) {
            policy.detach(webViewId)
            Log.w(
                TAG,
                "$LOG_PREFIX attach failed: no WebView found for identifier $webViewId. " +
                    "Dart will fall back to nonce-only enforcement.",
            )
            result.error(
                "WEBVIEW_NOT_FOUND",
                "No WebView found for identifier $webViewId",
                null,
            )
            return
        }

        // Replace the pigeon-managed JavaScript interface for divineSandboxBridge
        // with a WebMessageListener that reports isMainFrame. The listener injects
        // a JS object exposing the same `.postMessage(string)` API the bridge
        // bootstrap already calls, so the bootstrap is unchanged.
        //
        // Install the listener BEFORE removing the pigeon interface: if
        // addWebMessageListener throws on malformed origin rules, the original
        // divineSandboxBridge channel is still in place, so Dart's nonce-only
        // fallback keeps a working channel instead of facing a dead bridge.
        // Both register the same name, but neither takes effect until the next
        // document load and the interface is removed synchronously here, so the
        // page never sees both.
        try {
            val attestingListener = FrameAttestingWebMessageListener { payload ->
                eventSink?.success(payload)
            }
            WebViewCompat.addWebMessageListener(
                webView,
                BRIDGE_CHANNEL_NAME,
                allowedOriginRules.toSet(),
                attestingListener,
            )
            webView.removeJavascriptInterface(BRIDGE_CHANNEL_NAME)
            listener = attestingListener
            result.success(null)
        } catch (e: IllegalArgumentException) {
            // Malformed origin rules — roll back so Dart degrades to nonce-only.
            // The pigeon interface was not removed, so the channel still exists.
            policy.detach(webViewId)
            Log.w(
                TAG,
                "$LOG_PREFIX attach failed: invalid allowedOriginRules. " +
                    "Dart will fall back to nonce-only enforcement.",
            )
            result.error("INVALID_ORIGIN_RULES", e.message, null)
        }
    }

    private fun detachListener(webViewId: Long) {
        if (!policy.detach(webViewId)) return

        // The WebView may already be gone by the time Dart tears down; a missing
        // lookup or an already-removed listener is expected and not an error.
        val webView = WebViewFlutterAndroidExternalApi.getWebView(flutterEngine, webViewId)
        if (webView != null &&
            WebViewFeature.isFeatureSupported(WebViewFeature.WEB_MESSAGE_LISTENER)
        ) {
            try {
                WebViewCompat.removeWebMessageListener(webView, BRIDGE_CHANNEL_NAME)
            } catch (_: IllegalArgumentException) {
                // Listener was never registered on this WebView; nothing to remove.
            }
        }
        listener = null
    }
}

/**
 * Pure single-instance attestation lifecycle, extracted so the attach/detach
 * decisions can be unit tested without a real WebView or FlutterEngine. Mirrors
 * the iOS `NostrBridgeAttestationPolicy`.
 */
class NostrBridgeAttestationPolicy {
    sealed interface AttachResult {
        /** Newly attached the given webViewId. */
        object Ok : AttachResult

        /** Idempotent re-attach to the same webViewId; nothing to do. */
        object NoOp : AttachResult

        /** A different webViewId is already attached; the request must be refused. */
        data class AlreadyAttached(val existing: Long) : AttachResult
    }

    var attachedWebViewId: Long? = null
        private set

    fun attach(webViewId: Long): AttachResult {
        val existing = attachedWebViewId
        if (existing != null) {
            return if (existing == webViewId) {
                AttachResult.NoOp
            } else {
                AttachResult.AlreadyAttached(existing)
            }
        }
        attachedWebViewId = webViewId
        return AttachResult.Ok
    }

    /**
     * Returns true when the call cleared a matching attachment, false when the
     * id was not attached (so the caller can skip teardown work).
     */
    fun detach(webViewId: Long): Boolean {
        if (attachedWebViewId != webViewId) return false
        attachedWebViewId = null
        return true
    }
}

/**
 * The replacement WebMessageListener. Reads the platform-attested [isMainFrame]
 * and delivers `{message, isMainFrame}` to Dart. `sourceOrigin` is intentionally
 * dropped so the EventChannel payload matches the iOS contract exactly — Dart
 * only consumes `message` + `isMainFrame`.
 */
class FrameAttestingWebMessageListener(
    private val deliver: (Map<String, Any>) -> Unit,
) : WebViewCompat.WebMessageListener {
    override fun onPostMessage(
        view: WebView,
        message: WebMessageCompat,
        sourceOrigin: Uri,
        isMainFrame: Boolean,
        replyProxy: JavaScriptReplyProxy,
    ) {
        deliver(attestationEventPayload(message.data ?: "", isMainFrame))
    }
}

/**
 * Pure translation from the security-relevant fields to the Dart event payload,
 * extracted (and free of any android/flutter type) so the dictionary shape is
 * testable on the plain JVM without a real WebMessageCompat.
 */
@VisibleForTesting
internal fun attestationEventPayload(messageBody: String, isMainFrame: Boolean): Map<String, Any> =
    mapOf("message" to messageBody, "isMainFrame" to isMainFrame)
