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
import java.util.concurrent.ConcurrentHashMap

class BackgroundUploaderPlugin : FlutterPlugin, MethodCallHandler {
  private lateinit var channel: MethodChannel
  private lateinit var context: Context

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    context = binding.applicationContext
    channel = MethodChannel(binding.binaryMessenger, "background_uploader")
    channel.setMethodCallHandler(this)
    instances.add(this)
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
    instances.remove(this)
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
      "beginForegroundSession" -> {
        val intent = Intent(context, BackgroundUploadService::class.java).apply {
          action = BackgroundUploadService.ACTION_BEGIN_SESSION
          putExtra(
            BackgroundUploadService.EXTRA_SESSION_ID,
            call.argument<String>("sessionId"),
          )
        }
        startUploadService(intent)
        result.success(null)
      }
      "endForegroundSession" -> {
        val intent = Intent(context, BackgroundUploadService::class.java).apply {
          action = BackgroundUploadService.ACTION_END_SESSION
          putExtra(
            BackgroundUploadService.EXTRA_SESSION_ID,
            call.argument<String>("sessionId"),
          )
        }
        startUploadService(intent)
        result.success(null)
      }
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

    /// Every attached plugin instance — one per Flutter engine in the process.
    /// A process can host more than one engine (e.g. the Firebase-messaging or
    /// flutter_local_notifications background engine), and each one registers
    /// this plugin. Events fan out to all of them; only the engine whose Dart
    /// isolate set an `onUploadEvent` handler acts on it, the rest ignore it.
    /// A single last-write-wins reference would point at whichever engine
    /// attached last and silently drop events destined for the UI isolate.
    private val instances =
      ConcurrentHashMap.newKeySet<BackgroundUploaderPlugin>()

    /// Called from the upload service (on a worker thread) to deliver an event.
    fun postEvent(event: Map<String, Any?>) {
      mainHandler.post {
        for (plugin in instances) {
          try {
            plugin.channel.invokeMethod("onUploadEvent", event)
          } catch (ignored: Exception) {
            // Best-effort fan-out: an engine detaching concurrently can reject
            // the call; the engine that owns the upload still receives it.
          }
        }
      }
    }

    fun supportsTypedForegroundService(): Boolean =
      Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q
  }
}
