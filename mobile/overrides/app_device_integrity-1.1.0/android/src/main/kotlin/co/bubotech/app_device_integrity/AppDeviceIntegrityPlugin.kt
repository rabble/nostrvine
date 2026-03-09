package co.bubotech.app_device_integrity

import android.app.Activity
import android.content.Context

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/** AppDeviceIntegrityPlugin */
class AppDeviceIntegrityPlugin: FlutterPlugin, MethodCallHandler, ActivityAware {

  private lateinit var channel: MethodChannel
  private lateinit var context: Context
  private var activity: Activity? = null

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "app_attestation")
    channel.setMethodCallHandler(this)
    context = flutterPluginBinding.applicationContext
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    if (call.method != "getAttestationServiceSupport") {
      result.notImplemented()
      return
    }

    val challenge = call.argument<String>("challengeString")
    if (challenge.isNullOrBlank()) {
      result.error("INVALID_ARGUMENT", "challengeString is required", null)
      return
    }

    val cloudProjectNumber = call.argument<Number>("gcp")?.toLong()
    if (cloudProjectNumber == null) {
      result.error("INVALID_ARGUMENT", "gcp is required on Android", null)
      return
    }

    try {
      val attestation = AppDeviceIntegrity(context, challenge, cloudProjectNumber)
      attestation.integrityTokenResponse
        .addOnSuccessListener { response ->
          result.success(response.token())
        }
        .addOnFailureListener { e ->
          result.error(
            "INTEGRITY_TOKEN_FAILED",
            e.message ?: "Failed to request Play Integrity token",
            null,
          )
        }
    } catch (e: Exception) {
      result.error(
        "INTEGRITY_TOKEN_INIT_FAILED",
        e.message ?: "Failed to initialize Play Integrity request",
        null,
      )
    }
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }

  override fun onDetachedFromActivity() {
    activity = null
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    activity = binding.activity
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activity = binding.activity
  }

  override fun onDetachedFromActivityForConfigChanges() {
    activity = null
  }
}
