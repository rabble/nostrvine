// ABOUTME: Android background uploader plugin. Forwards enqueue/cancel to a
// ABOUTME: foreground service and fans its events back onto the method channel.

package co.openvine.background_uploader

import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class BackgroundUploaderPlugin : FlutterPlugin, MethodCallHandler {
  private lateinit var channel: MethodChannel
  private lateinit var context: Context

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    context = binding.applicationContext
    channel = MethodChannel(binding.binaryMessenger, "background_uploader")
    channel.setMethodCallHandler(this)
    active = this
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
    if (active === this) active = null
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "isSupported" -> result.success(true)
      "enqueue" -> {
        val intent = Intent(context, BackgroundUploadService::class.java).apply {
          action = BackgroundUploadService.ACTION_ENQUEUE
          putExtra(BackgroundUploadService.EXTRA_TASK_ID, call.argument<String>("taskId"))
          putExtra(BackgroundUploadService.EXTRA_URL, call.argument<String>("url"))
          putExtra(BackgroundUploadService.EXTRA_FILE_PATH, call.argument<String>("filePath"))
          putExtra(BackgroundUploadService.EXTRA_METHOD, call.argument<String>("method") ?: "PUT")
          val headers = call.argument<Map<String, String>>("headers") ?: emptyMap()
          putExtra(BackgroundUploadService.EXTRA_HEADERS, HashMap(headers))
        }
        startUploadService(intent)
        result.success(null)
      }
      "cancel" -> {
        val intent = Intent(context, BackgroundUploadService::class.java).apply {
          action = BackgroundUploadService.ACTION_CANCEL
          putExtra(BackgroundUploadService.EXTRA_TASK_ID, call.argument<String>("taskId"))
        }
        startUploadService(intent)
        result.success(null)
      }
      "activeTaskIds" -> result.success(BackgroundUploadService.activeTaskIds())
      else -> result.notImplemented()
    }
  }

  private fun startUploadService(intent: Intent) {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      context.startForegroundService(intent)
    } else {
      context.startService(intent)
    }
  }

  companion object {
    private val mainHandler = Handler(Looper.getMainLooper())

    /// The currently-attached plugin instance, used by the service to deliver
    /// events. Null while no Flutter engine is attached; events emitted then
    /// are dropped and reconciled on the next launch via `activeTaskIds`.
    @Volatile
    private var active: BackgroundUploaderPlugin? = null

    /// Called from the upload service (on a worker thread) to deliver an event.
    fun postEvent(event: Map<String, Any?>) {
      mainHandler.post {
        active?.channel?.invokeMethod("onUploadEvent", event)
      }
    }

    fun supportsTypedForegroundService(): Boolean =
      Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q
  }
}
