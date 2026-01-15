// ABOUTME: CameraX-based camera controller for Android
// ABOUTME: Handles camera initialization, preview, recording, and controls

package co.openvine.divine_camera

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.SurfaceTexture
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.Surface
import androidx.camera.core.*
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.video.*
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import io.flutter.view.TextureRegistry
import java.io.File
import java.text.SimpleDateFormat
import java.util.*
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

private const val TAG = "DivineCameraController"

/**
 * Controller for CameraX-based camera operations.
 * Handles camera initialization, preview, video recording, and camera controls.
 */
class CameraController(
    private val context: Context,
    private val activity: Activity,
    private val textureRegistry: TextureRegistry
) {
    private var cameraProvider: ProcessCameraProvider? = null
    private var camera: Camera? = null
    private var preview: Preview? = null
    private var videoCapture: VideoCapture<Recorder>? = null
    private var recording: Recording? = null

    private var textureEntry: TextureRegistry.SurfaceTextureEntry? = null
    private var flutterSurfaceTexture: SurfaceTexture? = null
    private var previewSurface: Surface? = null

    private var cameraExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    private var currentLens: Int = CameraSelector.LENS_FACING_BACK
    private var currentFlashMode: Int = ImageCapture.FLASH_MODE_OFF
    private var isTorchEnabled: Boolean = false
    private var isRecording: Boolean = false
    private var isPaused: Boolean = false

    private var minZoom: Float = 1.0f
    private var maxZoom: Float = 1.0f
    private var currentZoom: Float = 1.0f
    private var aspectRatio: Float = 16f / 9f
    private var videoWidth: Int = 1920
    private var videoHeight: Int = 1080

    private var hasFrontCamera: Boolean = false
    private var hasBackCamera: Boolean = false
    private var hasFlash: Boolean = false
    private var isFocusPointSupported: Boolean = false
    private var isExposurePointSupported: Boolean = false

    private var recordingStartTime: Long = 0
    private var currentRecordingFile: File? = null
    private var videoQuality: Quality = Quality.FHD
    private var maxDurationRunnable: Runnable? = null
    private var autoStopCallback: ((Map<String, Any>?, String?) -> Unit)? = null

    /** Listener for auto-stop events, set by the plugin. */
    var onAutoStopListener: ((Map<String, Any>) -> Unit)? = null

    /**
     * Initializes the camera with the specified lens and video quality.
     */
    fun initialize(
        lens: String,
        quality: String,
        callback: (Map<String, Any>?, String?) -> Unit
    ) {
        Log.d(TAG, "Initializing camera with lens: $lens, quality: $quality")

        currentLens = if (lens == "front") {
            CameraSelector.LENS_FACING_FRONT
        } else {
            CameraSelector.LENS_FACING_BACK
        }

        videoQuality = when (quality) {
            "sd" -> Quality.SD
            "hd" -> Quality.HD
            "fhd" -> Quality.FHD
            "uhd" -> Quality.UHD
            "highest" -> Quality.HIGHEST
            "lowest" -> Quality.LOWEST
            else -> Quality.FHD
        }

        checkCameraAvailability()

        val cameraProviderFuture = ProcessCameraProvider.getInstance(context)
        cameraProviderFuture.addListener({
            try {
                cameraProvider = cameraProviderFuture.get()
                Log.d(TAG, "Camera provider obtained")
                startCamera(callback)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to get camera provider", e)
                mainHandler.post {
                    callback(null, "Failed to get camera provider: ${e.message}")
                }
            }
        }, ContextCompat.getMainExecutor(context))
    }

    /**
     * Checks which cameras are available on the device.
     */
    private fun checkCameraAvailability() {
        try {
            val cameraManager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
            for (cameraId in cameraManager.cameraIdList) {
                val characteristics = cameraManager.getCameraCharacteristics(cameraId)
                val facing = characteristics.get(CameraCharacteristics.LENS_FACING)
                when (facing) {
                    CameraCharacteristics.LENS_FACING_FRONT -> hasFrontCamera = true
                    CameraCharacteristics.LENS_FACING_BACK -> hasBackCamera = true
                }
            }
            Log.d(TAG, "Camera availability: front=$hasFrontCamera, back=$hasBackCamera")
        } catch (e: Exception) {
            Log.e(TAG, "Error checking camera availability", e)
        }
    }

    /**
     * Gets the best aspect ratio for the current camera based on sensor size.
     * Returns RATIO_4_3 or RATIO_16_9 depending on which is closer to the sensor's native ratio.
     */
    private fun getBestAspectRatio(): Int {
        try {
            val cameraManager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
            val targetFacing = if (currentLens == CameraSelector.LENS_FACING_FRONT) {
                CameraCharacteristics.LENS_FACING_FRONT
            } else {
                CameraCharacteristics.LENS_FACING_BACK
            }

            for (cameraId in cameraManager.cameraIdList) {
                val characteristics = cameraManager.getCameraCharacteristics(cameraId)
                val facing = characteristics.get(CameraCharacteristics.LENS_FACING)

                if (facing == targetFacing) {
                    // Get the sensor size
                    val sensorSize =
                        characteristics.get(CameraCharacteristics.SENSOR_INFO_ACTIVE_ARRAY_SIZE)
                    if (sensorSize != null) {
                        val sensorWidth = sensorSize.width().toFloat()
                        val sensorHeight = sensorSize.height().toFloat()
                        val sensorRatio = sensorWidth / sensorHeight

                        Log.d(
                            TAG,
                            "Sensor size: ${sensorSize.width()}x${sensorSize.height()}, ratio: $sensorRatio"
                        )

                        // Compare to 4:3 (1.333) and 16:9 (1.777)
                        val ratio4_3 = 4f / 3f  // 1.333
                        val ratio16_9 = 16f / 9f // 1.777

                        val diff4_3 = kotlin.math.abs(sensorRatio - ratio4_3)
                        val diff16_9 = kotlin.math.abs(sensorRatio - ratio16_9)

                        return if (diff4_3 < diff16_9) {
                            Log.d(
                                TAG,
                                "Using 4:3 aspect ratio (closer to sensor ratio $sensorRatio)"
                            )
                            AspectRatio.RATIO_4_3
                        } else {
                            Log.d(
                                TAG,
                                "Using 16:9 aspect ratio (closer to sensor ratio $sensorRatio)"
                            )
                            AspectRatio.RATIO_16_9
                        }
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error getting sensor aspect ratio", e)
        }

        // Default to 16:9 if we can't determine the sensor ratio
        Log.d(TAG, "Using default 16:9 aspect ratio")
        return AspectRatio.RATIO_16_9
    }

    /**
     * Starts the camera with preview and video capture use cases.
     */
    @OptIn(ExperimentalPersistentRecording::class)
    private fun startCamera(callback: (Map<String, Any>?, String?) -> Unit) {
        val provider = cameraProvider ?: run {
            Log.e(TAG, "Camera provider not available")
            callback(null, "Camera provider not available")
            return
        }

        // Check if activity is a LifecycleOwner
        if (activity !is LifecycleOwner) {
            Log.e(TAG, "Activity is not a LifecycleOwner: ${activity.javaClass.name}")
            callback(null, "Activity must be a LifecycleOwner (use FlutterFragmentActivity)")
            return
        }

        try {
            // Unbind all use cases before rebinding
            provider.unbindAll()
            Log.d(TAG, "Unbound all previous use cases")

            // Release previous resources only if not already handled (e.g., by switchCamera)
            if (textureEntry != null) {
                previewSurface?.release()
                previewSurface = null
                textureEntry?.release()
                textureEntry = null
                flutterSurfaceTexture = null
            }

            // Create texture entry for Flutter
            textureEntry = textureRegistry.createSurfaceTexture()
            flutterSurfaceTexture = textureEntry?.surfaceTexture()

            val textureId = textureEntry?.id() ?: run {
                Log.e(TAG, "Failed to create texture entry")
                callback(null, "Failed to create texture")
                return
            }

            Log.d(TAG, "Created Flutter texture with id: $textureId")

            // Build camera selector
            val cameraSelector = CameraSelector.Builder()
                .requireLensFacing(currentLens)
                .build()

            // Get the best aspect ratio based on the camera sensor
            val targetAspectRatio = getBestAspectRatio()

            // Build preview with same aspect ratio as video
            preview = Preview.Builder()
                .setTargetAspectRatio(targetAspectRatio)
                .build()

            // Variable to track if callback was already called
            var callbackCalled = false

            // Setup surface provider - provide the surface when CameraX requests it
            preview?.setSurfaceProvider(ContextCompat.getMainExecutor(context)) { request ->
                val resolution = request.resolution
                videoWidth = resolution.width
                videoHeight = resolution.height
                Log.d(
                    TAG,
                    "Surface provider called with resolution: ${videoWidth}x${videoHeight}"
                )

                // Update aspect ratio and video dimensions based on actual camera resolution
                aspectRatio = videoWidth.toFloat() / videoHeight.toFloat()
                Log.d(TAG, "Aspect ratio set to: $aspectRatio, video dimensions: ${videoWidth}x${videoHeight}")

                // Set the buffer size to match camera resolution
                flutterSurfaceTexture?.setDefaultBufferSize(videoWidth, videoHeight)

                // Create surface from Flutter's SurfaceTexture
                previewSurface = Surface(flutterSurfaceTexture)

                // Provide the surface
                if (previewSurface != null && previewSurface!!.isValid) {
                    request.provideSurface(
                        previewSurface!!,
                        ContextCompat.getMainExecutor(context)
                    ) { result ->
                        Log.d(TAG, "Surface result code: ${result.resultCode}")
                    }

                    // Call the callback NOW after we have the correct resolution
                    if (!callbackCalled) {
                        callbackCalled = true
                        val state = getCameraState().toMutableMap()
                        state["textureId"] = textureId
                        Log.d(TAG, "Camera initialized successfully: $state")
                        callback(state, null)
                    }
                } else {
                    Log.e(TAG, "Preview surface is null or invalid!")
                    if (!callbackCalled) {
                        callbackCalled = true
                        callback(null, "Failed to create preview surface")
                    }
                }
            }

            // Build video capture with same aspect ratio as preview
            // Mirror front camera video to match preview
            val recorder = Recorder.Builder()
                .setQualitySelector(
                    QualitySelector.from(
                        videoQuality,
                        FallbackStrategy.lowerQualityOrHigherThan(Quality.SD)
                    )
                )
                .setAspectRatio(targetAspectRatio)
                .setExecutor(cameraExecutor)
                .build()

            videoCapture = VideoCapture.Builder(recorder)
                .setMirrorMode(
                    if (currentLens == CameraSelector.LENS_FACING_FRONT)
                        MirrorMode.MIRROR_MODE_ON_FRONT_ONLY
                    else
                        MirrorMode.MIRROR_MODE_OFF
                )
                .build()

            Log.d(TAG, "Binding use cases to lifecycle...")

            // Bind use cases to camera
            camera = provider.bindToLifecycle(
                activity as LifecycleOwner,
                cameraSelector,
                preview,
                videoCapture
            )

            Log.d(TAG, "Camera bound successfully")

            // Get camera info
            camera?.let { cam ->
                val cameraInfo = cam.cameraInfo
                val zoomState = cameraInfo.zoomState.value
                minZoom = zoomState?.minZoomRatio ?: 1.0f
                maxZoom = zoomState?.maxZoomRatio ?: 1.0f
                currentZoom = zoomState?.zoomRatio ?: 1.0f
                hasFlash = cameraInfo.hasFlashUnit()
                isFocusPointSupported = true
                isExposurePointSupported = true
                Log.d(TAG, "Camera info: zoom=$minZoom-$maxZoom, flash=$hasFlash")
            }

        } catch (e: Exception) {
            Log.e(TAG, "Failed to start camera", e)
            mainHandler.post {
                callback(null, "Failed to start camera: ${e.message}")
            }
        }
    }

    /**
     * Switches to a different camera lens.
     * Reuses the same texture to avoid black screen during switch.
     */
    fun switchCamera(
        lens: String,
        callback: (Map<String, Any>?, String?) -> Unit
    ) {
        Log.d(TAG, "Switching camera to: $lens")
        currentLens = if (lens == "front") {
            CameraSelector.LENS_FACING_FRONT
        } else {
            CameraSelector.LENS_FACING_BACK
        }

        val provider = cameraProvider ?: run {
            Log.e(TAG, "Camera provider not available")
            callback(null, "Camera provider not available")
            return
        }

        if (activity !is LifecycleOwner) {
            Log.e(TAG, "Activity is not a LifecycleOwner")
            callback(null, "Activity must be a LifecycleOwner")
            return
        }

        try {
            // Unbind all use cases
            provider.unbindAll()

            // Build new camera selector for the other lens
            val cameraSelector = CameraSelector.Builder()
                .requireLensFacing(currentLens)
                .build()

            // Get aspect ratio for this camera
            val targetAspectRatio = getBestAspectRatio()

            // Create new preview with same aspect ratio
            preview = Preview.Builder()
                .setTargetAspectRatio(targetAspectRatio)
                .build()

            // Reuse the existing flutter texture - just update buffer size when we get new resolution
            preview?.setSurfaceProvider(ContextCompat.getMainExecutor(context)) { request ->
                val resolution = request.resolution
                videoWidth = resolution.width
                videoHeight = resolution.height
                Log.d(
                    TAG,
                    "Switch: Surface provider called with resolution: ${videoWidth}x${videoHeight}"
                )

                aspectRatio = videoWidth.toFloat() / videoHeight.toFloat()

                // Update buffer size for new camera resolution
                flutterSurfaceTexture?.setDefaultBufferSize(videoWidth, videoHeight)

                // Provide the existing surface
                if (previewSurface != null && previewSurface!!.isValid) {
                    request.provideSurface(
                        previewSurface!!,
                        ContextCompat.getMainExecutor(context)
                    ) { result ->
                        Log.d(TAG, "Switch: Surface result code: ${result.resultCode}")
                    }
                } else {
                    // Surface was released, create new one
                    previewSurface = Surface(flutterSurfaceTexture)
                    if (previewSurface != null && previewSurface!!.isValid) {
                        request.provideSurface(
                            previewSurface!!,
                            ContextCompat.getMainExecutor(context)
                        ) { result ->
                            Log.d(TAG, "Switch: New surface result code: ${result.resultCode}")
                        }
                    }
                }
            }

            // Create recorder with same quality and aspect ratio
            val recorder = Recorder.Builder()
                .setQualitySelector(
                    QualitySelector.from(
                        videoQuality,
                        FallbackStrategy.lowerQualityOrHigherThan(Quality.SD)
                    )
                )
                .setAspectRatio(targetAspectRatio)
                .setExecutor(cameraExecutor)
                .build()

            videoCapture = VideoCapture.Builder(recorder)
                .setMirrorMode(
                    if (currentLens == CameraSelector.LENS_FACING_FRONT)
                        MirrorMode.MIRROR_MODE_ON_FRONT_ONLY
                    else
                        MirrorMode.MIRROR_MODE_OFF
                )
                .build()

            // Bind use cases to the new camera
            camera = provider.bindToLifecycle(
                activity as LifecycleOwner,
                cameraSelector,
                preview,
                videoCapture
            )

            // Get camera info from new camera
            camera?.let { cam ->
                val cameraInfo = cam.cameraInfo
                val zoomState = cameraInfo.zoomState.value
                minZoom = zoomState?.minZoomRatio ?: 1.0f
                maxZoom = zoomState?.maxZoomRatio ?: 1.0f
                currentZoom = 1.0f
                hasFlash = cameraInfo.hasFlashUnit()
                isFocusPointSupported = true
                isExposurePointSupported = true
            }

            Log.d(TAG, "Camera switched successfully")

            mainHandler.post {
                callback(getCameraState(), null)
            }

        } catch (e: Exception) {
            Log.e(TAG, "Failed to switch camera", e)
            mainHandler.post {
                callback(null, "Failed to switch camera: ${e.message}")
            }
        }
    }

    /**
     * Sets the flash mode.
     */
    fun setFlashMode(mode: String): Boolean {
        val cam = camera ?: return false

        Log.d(TAG, "Setting flash mode: $mode")

        return try {
            when (mode) {
                "off" -> {
                    cam.cameraControl.enableTorch(false)
                    isTorchEnabled = false
                    currentFlashMode = ImageCapture.FLASH_MODE_OFF
                }

                "auto" -> {
                    cam.cameraControl.enableTorch(false)
                    isTorchEnabled = false
                    currentFlashMode = ImageCapture.FLASH_MODE_AUTO
                }

                "on" -> {
                    cam.cameraControl.enableTorch(false)
                    isTorchEnabled = false
                    currentFlashMode = ImageCapture.FLASH_MODE_ON
                }

                "torch" -> {
                    cam.cameraControl.enableTorch(true)
                    isTorchEnabled = true
                }
            }
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to set flash mode", e)
            false
        }
    }

    /**
     * Sets the focus point in normalized coordinates (0.0-1.0).
     */
    fun setFocusPoint(x: Float, y: Float): Boolean {
        val cam = camera ?: return false

        return try {
            val factory = SurfaceOrientedMeteringPointFactory(1f, 1f)
            val point = factory.createPoint(x, y)
            val action = FocusMeteringAction.Builder(point, FocusMeteringAction.FLAG_AF)
                .setAutoCancelDuration(3, java.util.concurrent.TimeUnit.SECONDS)
                .build()
            cam.cameraControl.startFocusAndMetering(action)
            Log.d(TAG, "Focus point set: ($x, $y)")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to set focus point", e)
            false
        }
    }

    /**
     * Sets the exposure point in normalized coordinates (0.0-1.0).
     */
    fun setExposurePoint(x: Float, y: Float): Boolean {
        val cam = camera ?: return false

        return try {
            val factory = SurfaceOrientedMeteringPointFactory(1f, 1f)
            val point = factory.createPoint(x, y)
            val action = FocusMeteringAction.Builder(point, FocusMeteringAction.FLAG_AE)
                .setAutoCancelDuration(3, java.util.concurrent.TimeUnit.SECONDS)
                .build()
            cam.cameraControl.startFocusAndMetering(action)
            Log.d(TAG, "Exposure point set: ($x, $y)")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to set exposure point", e)
            false
        }
    }

    /**
     * Sets the zoom level.
     */
    fun setZoomLevel(level: Float): Boolean {
        val cam = camera ?: return false

        return try {
            val clampedLevel = level.coerceIn(minZoom, maxZoom)
            cam.cameraControl.setZoomRatio(clampedLevel)
            currentZoom = clampedLevel
            Log.d(TAG, "Zoom level set: $clampedLevel")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to set zoom level", e)
            false
        }
    }

    /**
     * Starts video recording.
     * @param maxDurationMs Optional maximum duration in milliseconds. Recording stops automatically when reached.
     */
    @SuppressLint("MissingPermission")
    fun startRecording(maxDurationMs: Int?, callback: (String?) -> Unit) {
        val videoCap = videoCapture ?: run {
            callback("Video capture not initialized")
            return
        }

        if (isRecording) {
            callback("Already recording")
            return
        }

        // Check audio permission
        if (ActivityCompat.checkSelfPermission(
                context,
                Manifest.permission.RECORD_AUDIO
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            callback("Audio permission not granted")
            return
        }

        try {
            // Create output file
            val outputDir = context.cacheDir
            val timestamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(Date())
            val outputFile = File(outputDir, "VID_$timestamp.mp4")
            currentRecordingFile = outputFile

            Log.d(
                TAG, "Starting recording to: ${outputFile.absolutePath}" +
                        if (maxDurationMs != null) " (max duration: ${maxDurationMs}ms)" else ""
            )

            val outputOptions = FileOutputOptions.Builder(outputFile).build()

            // Flag to ensure callback is only called once (when recording truly starts)
            var callbackCalled = false

            recording = videoCap.output
                .prepareRecording(context, outputOptions)
                .withAudioEnabled()
                .start(ContextCompat.getMainExecutor(context)) { event ->
                    when (event) {
                        is VideoRecordEvent.Start -> {
                            isRecording = true
                            Log.d(
                                TAG,
                                "VideoRecordEvent.Start received - waiting for first frame..."
                            )
                        }

                        is VideoRecordEvent.Status -> {
                            // Status events are sent continuously during recording
                            // When recordedDurationNanos > 0, the encoder is truly recording frames
                            val durationNanos = event.recordingStats.recordedDurationNanos
                            if (!callbackCalled && durationNanos > 0) {
                                callbackCalled = true
                                recordingStartTime = System.currentTimeMillis()
                                Log.d(
                                    TAG,
                                    "Recording truly started - first frame recorded (duration: ${durationNanos / 1_000_000}ms)"
                                )

                                // Schedule auto-stop if maxDuration is set
                                if (maxDurationMs != null && maxDurationMs > 0) {
                                    maxDurationRunnable = Runnable {
                                        Log.d(
                                            TAG,
                                            "Max duration reached (${maxDurationMs}ms) - auto-stopping recording"
                                        )
                                        autoStopRecording()
                                    }
                                    mainHandler.postDelayed(
                                        maxDurationRunnable!!,
                                        maxDurationMs.toLong()
                                    )
                                }

                                callback(null)
                            }
                        }

                        is VideoRecordEvent.Finalize -> {
                            isRecording = false
                            // Cancel any pending auto-stop
                            maxDurationRunnable?.let { mainHandler.removeCallbacks(it) }
                            maxDurationRunnable = null

                            if (event.hasError()) {
                                Log.e(TAG, "Recording error: ${event.error}")
                            } else {
                                Log.d(TAG, "Recording finalized")
                            }

                            // Handle auto-stop callback
                            autoStopCallback?.let { autoCallback ->
                                val file = currentRecordingFile
                                if (file != null && file.exists()) {
                                    val duration = System.currentTimeMillis() - recordingStartTime
                                    val result = mapOf(
                                        "filePath" to file.absolutePath,
                                        "durationMs" to duration.toInt(),
                                        "width" to videoWidth,
                                        "height" to videoHeight
                                    )
                                    Log.d(TAG, "Auto-stop recording result: $result")
                                    autoCallback(result, null)
                                } else {
                                    autoCallback(null, "Recording file not found")
                                }
                                autoStopCallback = null
                                currentRecordingFile = null
                                recording = null
                            }
                        }
                    }
                }
            // Callback is now called in Status event when recording truly starts

        } catch (e: Exception) {
            Log.e(TAG, "Failed to start recording", e)
            callback("Failed to start recording: ${e.message}")
        }
    }

    /**
     * Auto-stops recording when max duration is reached.
     * This is called internally and notifies Flutter via method channel.
     */
    private fun autoStopRecording() {
        val currentRecording = recording

        if (currentRecording == null || !isRecording) {
            return
        }

        Log.d(TAG, "Auto-stopping recording...")

        // Set the callback that will be invoked when Finalize event fires
        autoStopCallback = { result, error ->
            if (result != null) {
                Log.d(TAG, "Auto-stop completed, notifying listener: $result")
                onAutoStopListener?.invoke(result)
            }
        }

        currentRecording.stop()
        // The Finalize event will handle the callback via autoStopCallback
    }

    /**
     * Stops video recording and returns the result.
     */
    fun stopRecording(callback: (Map<String, Any>?, String?) -> Unit) {
        val currentRecording = recording

        if (currentRecording == null || !isRecording) {
            callback(null, "Not recording")
            return
        }

        try {
            Log.d(TAG, "Stopping recording...")
            currentRecording.stop()

            // Wait for file to be finalized
            mainHandler.postDelayed({
                val file = currentRecordingFile
                if (file != null && file.exists()) {
                    val duration = System.currentTimeMillis() - recordingStartTime
                    val result = mapOf(
                        "filePath" to file.absolutePath,
                        "durationMs" to duration.toInt(),
                        "width" to videoWidth,
                        "height" to videoHeight
                    )
                    Log.d(TAG, "Recording stopped: $result")
                    callback(result, null)
                } else {
                    callback(null, "Recording file not found")
                }
                currentRecordingFile = null
                recording = null
            }, 200)

        } catch (e: Exception) {
            Log.e(TAG, "Failed to stop recording", e)
            callback(null, "Failed to stop recording: ${e.message}")
        }
    }

    /**
     * Pauses the camera preview.
     */
    fun pausePreview() {
        Log.d(TAG, "Pausing preview")
        isPaused = true
    }

    /**
     * Resumes the camera preview.
     */
    fun resumePreview(callback: (Map<String, Any>?, String?) -> Unit) {
        Log.d(TAG, "Resuming preview")
        isPaused = false
        if (cameraProvider != null && camera != null) {
            callback(getCameraState(), null)
        } else {
            callback(null, "Camera not initialized")
        }
    }

    /**
     * Gets the current camera state as a map.
     */
    fun getCameraState(): MutableMap<String, Any> {
        val textureId = textureEntry?.id() ?: -1L
        return mutableMapOf(
            "isInitialized" to (camera != null),
            "isRecording" to isRecording,
            "flashMode" to getFlashModeString(),
            "lens" to if (currentLens == CameraSelector.LENS_FACING_FRONT) "front" else "back",
            "zoomLevel" to currentZoom.toDouble(),
            "minZoomLevel" to minZoom.toDouble(),
            "maxZoomLevel" to maxZoom.toDouble(),
            "aspectRatio" to aspectRatio.toDouble(),
            "hasFlash" to hasFlash,
            "hasFrontCamera" to hasFrontCamera,
            "hasBackCamera" to hasBackCamera,
            "isFocusPointSupported" to isFocusPointSupported,
            "isExposurePointSupported" to isExposurePointSupported,
            "textureId" to textureId
        )
    }

    /**
     * Gets the current flash mode as a string.
     */
    private fun getFlashModeString(): String {
        if (isTorchEnabled) return "torch"
        return when (currentFlashMode) {
            ImageCapture.FLASH_MODE_OFF -> "off"
            ImageCapture.FLASH_MODE_AUTO -> "auto"
            ImageCapture.FLASH_MODE_ON -> "on"
            else -> "off"
        }
    }

    /**
     * Releases all camera resources.
     */
    fun release() {
        Log.d(TAG, "Releasing camera resources")
        try {
            recording?.stop()
            recording = null
            isRecording = false

            cameraProvider?.unbindAll()
            cameraProvider = null
            camera = null
            preview = null
            videoCapture = null

            previewSurface?.release()
            previewSurface = null

            textureEntry?.release()
            textureEntry = null
            flutterSurfaceTexture = null

            if (!cameraExecutor.isShutdown) {
                cameraExecutor.shutdown()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error releasing camera", e)
        }
    }
}
