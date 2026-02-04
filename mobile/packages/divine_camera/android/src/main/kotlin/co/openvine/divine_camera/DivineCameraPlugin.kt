// ABOUTME: Main Flutter plugin entry point for Android camera operations
// ABOUTME: Handles method channel communication and delegates to CameraController

package co.openvine.divine_camera

import android.app.Activity
import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.view.TextureRegistry

/** DivineCameraPlugin */
class DivineCameraPlugin :
    FlutterPlugin,
    MethodCallHandler,
    ActivityAware {

    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private lateinit var textureRegistry: TextureRegistry
    private var activity: Activity? = null
    private var cameraController: CameraController? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "divine_camera")
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
        textureRegistry = flutterPluginBinding.textureRegistry
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getPlatformVersion" -> {
                result.success("Android ${android.os.Build.VERSION.RELEASE}")
            }

            "initializeCamera" -> {
                val lens = call.argument<String>("lens") ?: "back"
                val videoQuality = call.argument<String>("videoQuality") ?: "fhd"
                val enableScreenFlash = call.argument<Boolean>("enableScreenFlash") ?: true
                initializeCamera(lens, videoQuality, enableScreenFlash, result)
            }

            "disposeCamera" -> {
                disposeCamera(result)
            }

            "setFlashMode" -> {
                val mode = call.argument<String>("mode") ?: "off"
                setFlashMode(mode, result)
            }

            "setFocusPoint" -> {
                val x = call.argument<Double>("x") ?: 0.5
                val y = call.argument<Double>("y") ?: 0.5
                setFocusPoint(x.toFloat(), y.toFloat(), result)
            }

            "setExposurePoint" -> {
                val x = call.argument<Double>("x") ?: 0.5
                val y = call.argument<Double>("y") ?: 0.5
                setExposurePoint(x.toFloat(), y.toFloat(), result)
            }

            "setZoomLevel" -> {
                val level = call.argument<Double>("level") ?: 1.0
                setZoomLevel(level.toFloat(), result)
            }

            "switchCamera" -> {
                val lens = call.argument<String>("lens") ?: "back"
                switchCamera(lens, result)
            }

            "startRecording" -> {
                val maxDurationMs = call.argument<Int>("maxDurationMs")
                val useCache = call.argument<Boolean>("useCache") ?: true
                val outputDirectory = call.argument<String>("outputDirectory")
                startRecording(maxDurationMs, useCache, outputDirectory, result)
            }

            "stopRecording" -> {
                stopRecording(result)
            }

            "pausePreview" -> {
                pausePreview(result)
            }

            "resumePreview" -> {
                resumePreview(result)
            }

            "getCameraState" -> {
                getCameraState(result)
            }

            else -> {
                result.notImplemented()
            }
        }
    }

    private fun initializeCamera(lens: String, videoQuality: String, enableScreenFlash: Boolean, result: Result) {
        val currentActivity = activity
        if (currentActivity == null) {
            result.error("NO_ACTIVITY", "Activity not available", null)
            return
        }

        try {
            cameraController?.release()
            cameraController = CameraController(
                context = context,
                activity = currentActivity,
                textureRegistry = textureRegistry
            )

            // Set up auto-stop listener to notify Flutter
            cameraController?.onAutoStopListener = { recordingResult ->
                channel.invokeMethod("onRecordingAutoStopped", recordingResult)
            }

            cameraController?.initialize(lens, videoQuality, enableScreenFlash) { state, error ->
                if (error != null) {
                    result.error("INIT_ERROR", error, null)
                } else {
                    result.success(state)
                }
            }
        } catch (e: Exception) {
            result.error("INIT_EXCEPTION", e.message, e.stackTraceToString())
        }
    }

    private fun disposeCamera(result: Result) {
        try {
            cameraController?.release()
            cameraController = null
            result.success(null)
        } catch (e: Exception) {
            result.error("DISPOSE_ERROR", e.message, null)
        }
    }

    private fun setFlashMode(mode: String, result: Result) {
        val controller = cameraController
        if (controller == null) {
            result.error("NOT_INITIALIZED", "Camera not initialized", null)
            return
        }
        try {
            val success = controller.setFlashMode(mode)
            result.success(success)
        } catch (e: Exception) {
            result.error("FLASH_ERROR", e.message, null)
        }
    }

    private fun setFocusPoint(x: Float, y: Float, result: Result) {
        val controller = cameraController
        if (controller == null) {
            result.error("NOT_INITIALIZED", "Camera not initialized", null)
            return
        }
        try {
            val success = controller.setFocusPoint(x, y)
            result.success(success)
        } catch (e: Exception) {
            result.error("FOCUS_ERROR", e.message, null)
        }
    }

    private fun setExposurePoint(x: Float, y: Float, result: Result) {
        val controller = cameraController
        if (controller == null) {
            result.error("NOT_INITIALIZED", "Camera not initialized", null)
            return
        }
        try {
            val success = controller.setExposurePoint(x, y)
            result.success(success)
        } catch (e: Exception) {
            result.error("EXPOSURE_ERROR", e.message, null)
        }
    }

    private fun setZoomLevel(level: Float, result: Result) {
        val controller = cameraController
        if (controller == null) {
            result.error("NOT_INITIALIZED", "Camera not initialized", null)
            return
        }
        try {
            val success = controller.setZoomLevel(level)
            result.success(success)
        } catch (e: Exception) {
            result.error("ZOOM_ERROR", e.message, null)
        }
    }

    private fun switchCamera(lens: String, result: Result) {
        val controller = cameraController
        if (controller == null) {
            result.error("NOT_INITIALIZED", "Camera not initialized", null)
            return
        }
        try {
            controller.switchCamera(lens) { state, error ->
                if (error != null) {
                    result.error("SWITCH_ERROR", error, null)
                } else {
                    result.success(state)
                }
            }
        } catch (e: Exception) {
            result.error("SWITCH_EXCEPTION", e.message, null)
        }
    }

    private fun startRecording(maxDurationMs: Int?, useCache: Boolean, outputDirectory: String?, result: Result) {
        val controller = cameraController
        if (controller == null) {
            result.error("NOT_INITIALIZED", "Camera not initialized", null)
            return
        }
        try {
            controller.startRecording(maxDurationMs, useCache, outputDirectory) { error ->
                if (error != null) {
                    result.error("RECORD_START_ERROR", error, null)
                } else {
                    result.success(null)
                }
            }
        } catch (e: Exception) {
            result.error("RECORD_START_EXCEPTION", e.message, null)
        }
    }

    private fun stopRecording(result: Result) {
        val controller = cameraController
        if (controller == null) {
            result.error("NOT_INITIALIZED", "Camera not initialized", null)
            return
        }
        try {
            controller.stopRecording { recordingResult, error ->
                if (error != null) {
                    result.error("RECORD_STOP_ERROR", error, null)
                } else {
                    result.success(recordingResult)
                }
            }
        } catch (e: Exception) {
            result.error("RECORD_STOP_EXCEPTION", e.message, null)
        }
    }

    private fun pausePreview(result: Result) {
        try {
            cameraController?.pausePreview()
            result.success(null)
        } catch (e: Exception) {
            result.error("PAUSE_ERROR", e.message, null)
        }
    }

    private fun resumePreview(result: Result) {
        try {
            cameraController?.resumePreview { state, error ->
                if (error != null) {
                    result.error("RESUME_ERROR", error, null)
                } else {
                    result.success(state)
                }
            }
        } catch (e: Exception) {
            result.error("RESUME_EXCEPTION", e.message, null)
        }
    }

    private fun getCameraState(result: Result) {
        val controller = cameraController
        if (controller == null) {
            result.error("NOT_INITIALIZED", "Camera not initialized", null)
            return
        }
        try {
            result.success(controller.getCameraState())
        } catch (e: Exception) {
            result.error("STATE_ERROR", e.message, null)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        cameraController?.release()
        cameraController = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }
}
