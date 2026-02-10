// ABOUTME: CameraX-based camera controller for Android
// ABOUTME: Handles camera initialization, preview, recording, and controls

package co.openvine.divine_camera

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.SurfaceTexture
import android.hardware.camera2.CameraCaptureSession
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.hardware.camera2.CaptureRequest
import android.hardware.camera2.CaptureResult
import android.hardware.camera2.TotalCaptureResult
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.Surface
import android.view.WindowManager
import androidx.camera.camera2.interop.Camera2CameraInfo
import androidx.camera.camera2.interop.Camera2Interop
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
    private var recordingTrulyStarted: Boolean = false
    
    // Callback for startRecording - called when recording truly starts or is aborted
    private var startRecordingCallback: ((String?) -> Unit)? = null
    private var isPaused: Boolean = false

    // Screen brightness for front camera "torch" mode
    private var isScreenFlashEnabled: Boolean = false
    private var screenFlashFeatureEnabled: Boolean = true

    // Auto flash mode - checks brightness once when recording starts
    private var isAutoFlashMode: Boolean = false
    private var autoFlashTorchEnabled: Boolean = false
    
    // Camera2 Interop for exposure measurement (no ImageAnalysis needed)
    // These values are continuously updated from CaptureResult
    private var currentIso: Int = 100
    private var currentExposureTime: Long = 0L  // nanoseconds
    // Thresholds for "dark" detection:
    // Front camera: Lower thresholds - screen flash helps even in moderate darkness
    // Back camera: Higher thresholds - real flash is more aggressive, only for true darkness
    private val frontCameraIsoThreshold: Int = 650
    private val frontCameraExposureThreshold: Long = 20_000_000L  // 20ms
    private val backCameraIsoThreshold: Int = 800
    private val backCameraExposureThreshold: Long = 40_000_000L  // 40ms
    
    // Camera2 CaptureCallback to monitor exposure values continuously
    private val exposureCaptureCallback = object : CameraCaptureSession.CaptureCallback() {
        override fun onCaptureCompleted(
            session: CameraCaptureSession,
            request: CaptureRequest,
            result: TotalCaptureResult
        ) {
            // Extract exposure values from capture result
            result.get(CaptureResult.SENSOR_SENSITIVITY)?.let { iso ->
                currentIso = iso
            }
            result.get(CaptureResult.SENSOR_EXPOSURE_TIME)?.let { exposureTime ->
                currentExposureTime = exposureTime
            }
        }
    }

    private var minZoom: Float = 1.0f
    private var maxZoom: Float = 1.0f
    private var currentZoom: Float = 1.0f
    // Portrait-Modus: 9:16, 1080x1920
    private var aspectRatio: Float = 9f / 16f
    private var videoWidth: Int = 1080
    private var videoHeight: Int = 1920

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
        enableScreenFlash: Boolean = true,
        callback: (Map<String, Any>?, String?) -> Unit
    ) {
        Log.d(TAG, "Initializing camera with lens: $lens, quality: $quality, enableScreenFlash: $enableScreenFlash (portrait mode 1080x1920)")

        screenFlashFeatureEnabled = enableScreenFlash

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

        // Fallback to available camera if requested camera is not available
        if (currentLens == CameraSelector.LENS_FACING_FRONT && !hasFrontCamera && hasBackCamera) {
            Log.w(TAG, "Front camera requested but not available, falling back to back camera")
            currentLens = CameraSelector.LENS_FACING_BACK
        } else if (currentLens == CameraSelector.LENS_FACING_BACK && !hasBackCamera && hasFrontCamera) {
            Log.w(TAG, "Back camera requested but not available, falling back to front camera")
            currentLens = CameraSelector.LENS_FACING_FRONT
        }

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
     * Creates a Preview with Camera2Interop for exposure monitoring.
     * Uses CaptureCallback to track ISO and exposure time for auto-flash.
     */
    private fun buildPreviewWithExposureMonitoring(aspectRatio: Int): Preview {
        val previewBuilder = Preview.Builder()
            .setTargetAspectRatio(aspectRatio)
        
        // Add Camera2 capture callback to monitor exposure values
        val camera2Extender = Camera2Interop.Extender(previewBuilder)
        camera2Extender.setSessionCaptureCallback(exposureCaptureCallback)
        
        return previewBuilder.build()
    }

    /**
     * Starts the camera with preview and video capture use cases.
     */
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

            // Fixed 16:9 aspect ratio for portrait mode (9:16)
            val targetAspectRatio = AspectRatio.RATIO_16_9

            // Build preview with Camera2Interop for exposure monitoring
            preview = buildPreviewWithExposureMonitoring(targetAspectRatio)

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

                // Update aspect ratio for portrait mode (height/width gives 9:16 ratio)
                aspectRatio = videoHeight.toFloat() / videoWidth.toFloat()
                Log.d(TAG, "Aspect ratio set to: $aspectRatio (portrait), video dimensions: ${videoWidth}x${videoHeight}")

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
                // Front camera has "flash" via screen brightness when feature is enabled
                hasFlash = cameraInfo.hasFlashUnit() || 
                    (screenFlashFeatureEnabled && currentLens == CameraSelector.LENS_FACING_FRONT)
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
        
        // Disable screen flash when switching cameras
        disableScreenFlash()
        
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

            // Fixed 16:9 aspect ratio for portrait mode (9:16)
            val targetAspectRatio = AspectRatio.RATIO_16_9

            // Build preview with Camera2Interop for exposure monitoring
            preview = buildPreviewWithExposureMonitoring(targetAspectRatio)

            // Reuse the existing flutter texture - just update buffer size when we get new resolution
            preview?.setSurfaceProvider(ContextCompat.getMainExecutor(context)) { request ->
                val resolution = request.resolution
                videoWidth = resolution.width
                videoHeight = resolution.height
                Log.d(
                    TAG,
                    "Switch: Surface provider called with resolution: ${videoWidth}x${videoHeight}"
                )

                // Update aspect ratio for portrait mode (height/width gives 9:16 ratio)
                aspectRatio = videoHeight.toFloat() / videoWidth.toFloat()

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
                // Front camera has "flash" via screen brightness when feature is enabled
                hasFlash = cameraInfo.hasFlashUnit() || 
                    (screenFlashFeatureEnabled && currentLens == CameraSelector.LENS_FACING_FRONT)
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
     * For front camera with torch mode, maximizes screen brightness instead.
     * For "auto" mode, brightness will be checked once when recording starts.
     */
    fun setFlashMode(mode: String): Boolean {
        val cam = camera ?: return false

        Log.d(TAG, "Setting flash mode: $mode (currentLens: ${if (currentLens == CameraSelector.LENS_FACING_FRONT) "front" else "back"})")

        return try {
            // Handle screen brightness for front camera "torch" mode
            if (currentLens == CameraSelector.LENS_FACING_FRONT) {
                if (mode == "torch") {
                    enableScreenFlash()
                    isTorchEnabled = true
                    isAutoFlashMode = false
                    return true
                } else if (mode == "auto") {
                    // Auto mode for front camera - will check brightness when recording starts
                    disableScreenFlash()
                    isTorchEnabled = false
                    isAutoFlashMode = true
                    currentFlashMode = ImageCapture.FLASH_MODE_AUTO
                    Log.d(TAG, "Auto flash mode enabled for front camera")
                    return true
                } else {
                    disableScreenFlash()
                    isAutoFlashMode = false
                }
            }

            when (mode) {
                "off" -> {
                    cam.cameraControl.enableTorch(false)
                    isTorchEnabled = false
                    isAutoFlashMode = false
                    autoFlashTorchEnabled = false
                    currentFlashMode = ImageCapture.FLASH_MODE_OFF
                }

                "auto" -> {
                    // Auto mode - will check brightness when recording starts
                    cam.cameraControl.enableTorch(false)
                    isTorchEnabled = false
                    isAutoFlashMode = true
                    autoFlashTorchEnabled = false
                    currentFlashMode = ImageCapture.FLASH_MODE_AUTO
                    Log.d(TAG, "Auto flash mode enabled - will check brightness when recording starts")
                }

                "on" -> {
                    cam.cameraControl.enableTorch(false)
                    isTorchEnabled = false
                    isAutoFlashMode = false
                    currentFlashMode = ImageCapture.FLASH_MODE_ON
                }

                "torch" -> {
                    cam.cameraControl.enableTorch(true)
                    isTorchEnabled = true
                    isAutoFlashMode = false
                }
            }
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to set flash mode", e)
            false
        }
    }

    /**
     * Enables screen flash by setting brightness to maximum (for front camera).
     */
    private fun enableScreenFlash() {
        if (!screenFlashFeatureEnabled) return
        
        mainHandler.post {
            try {
                val window = activity.window
                val layoutParams = window.attributes
                
                // Set brightness to maximum (1.0 = 100%)
                layoutParams.screenBrightness = 1.0f
                window.attributes = layoutParams
                isScreenFlashEnabled = true
                
                Log.d(TAG, "Screen flash enabled (brightness set to 100%)")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to enable screen flash", e)
            }
        }
    }

    /**
     * Disables screen flash by restoring system brightness control.
     */
    private fun disableScreenFlash() {
        if (!isScreenFlashEnabled) return
        forceDisableScreenFlash()
    }
    
    /**
     * Forces screen brightness to be restored to system control.
     * Used when pausing/releasing to ensure brightness is always restored.
     */
    private fun forceDisableScreenFlash() {
        mainHandler.post {
            try {
                val window = activity.window
                val layoutParams = window.attributes
                
                layoutParams.screenBrightness = WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
                window.attributes = layoutParams
                
                isScreenFlashEnabled = false
                
                Log.d(TAG, "Screen flash disabled (brightness restored to system control)")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to disable screen flash", e)
            }
        }
    }

    /**
     * Checks if the current environment is dark based on Camera2 exposure values.
     * Uses ISO and exposure time as indicators.
     * Front camera has lower thresholds since screen flash is less intrusive.
     */
    private fun isEnvironmentDark(): Boolean {
        val isoThreshold = if (currentLens == CameraSelector.LENS_FACING_FRONT) 
            frontCameraIsoThreshold else backCameraIsoThreshold
        val exposureThreshold = if (currentLens == CameraSelector.LENS_FACING_FRONT) 
            frontCameraExposureThreshold else backCameraExposureThreshold
        
        // If ISO is high or exposure time is long, it's dark
        val isDark = currentIso >= isoThreshold || currentExposureTime >= exposureThreshold
        Log.d(TAG, "Auto flash: ISO=$currentIso (threshold=$isoThreshold), " +
                   "ExposureTime=${currentExposureTime/1_000_000}ms (threshold=${exposureThreshold/1_000_000}ms) -> isDark=$isDark")
        return isDark
    }
    
    /**
     * Checks the current exposure values and enables auto-flash if needed.
     * Uses Camera2 exposure data - no ImageAnalysis required.
     */
    private fun checkAndEnableAutoFlash() {
        if (!isAutoFlashMode) return
        
        if (isEnvironmentDark()) {
            Log.d(TAG, "Auto flash: Dark environment detected - enabling flash")
            enableAutoFlashTorch()
        } else {
            Log.d(TAG, "Auto flash: Bright environment - flash not needed")
        }
    }

    /**
     * Enables torch/screen flash for auto flash mode.
     */
    private fun enableAutoFlashTorch() {
        autoFlashTorchEnabled = true
        
        try {
            if (currentLens == CameraSelector.LENS_FACING_FRONT) {
                enableScreenFlash()
                Log.d(TAG, "Auto flash: Screen flash enabled for front camera")
            } else {
                camera?.cameraControl?.enableTorch(true)
                Log.d(TAG, "Auto flash: Torch enabled for back camera")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Auto flash: Failed to enable torch", e)
        }
    }
    
    /**
     * Disables torch/screen flash if it was enabled by auto flash mode.
     * Called when recording stops.
     */
    private fun disableAutoFlashTorch() {
        if (!autoFlashTorchEnabled) return
        
        autoFlashTorchEnabled = false
        
        try {
            if (currentLens == CameraSelector.LENS_FACING_FRONT) {
                disableScreenFlash()
                Log.d(TAG, "Auto flash: Screen flash disabled for front camera")
            } else {
                camera?.cameraControl?.enableTorch(false)
                Log.d(TAG, "Auto flash: Torch disabled for back camera")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Auto flash: Failed to disable torch", e)
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
     * @param useCache If true, saves video to cache directory (temporary). If false, saves to external files directory (permanent).
     * @param outputDirectory If provided, saves video to this directory (overrides useCache when false). Should be Flutter's getApplicationDocumentsDirectory() path.
     */
    @SuppressLint("MissingPermission")
    fun startRecording(maxDurationMs: Int?, useCache: Boolean = true, outputDirectory: String? = null, callback: (String?) -> Unit) {
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

        // Check brightness and enable auto-flash if needed (instant, uses Camera2 exposure values)
        checkAndEnableAutoFlash()

        try {
            // Create output file - use cache, provided directory, or default to filesDir
            val outputDir = when {
                outputDirectory != null -> File(outputDirectory)
                useCache -> context.cacheDir
                else -> context.filesDir
            }
            val timestamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(Date())
            val outputFile = File(outputDir, "VID_$timestamp.mp4")
            currentRecordingFile = outputFile

            Log.d(
                TAG, "Starting recording to: ${outputFile.absolutePath}" +
                        " (useCache: $useCache)" +
                        if (maxDurationMs != null) " (max duration: ${maxDurationMs}ms)" else ""
            )

            val outputOptions = FileOutputOptions.Builder(outputFile).build()

            // Store callback so it can be called from Finalize if recording is stopped early
            startRecordingCallback = callback

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
                            if (startRecordingCallback != null && durationNanos > 0) {
                                recordingTrulyStarted = true
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

                                // Notify Flutter that recording truly started
                                startRecordingCallback?.invoke(null)
                                startRecordingCallback = null
                            }
                        }

                        is VideoRecordEvent.Finalize -> {
                            isRecording = false
                            recordingTrulyStarted = false
                            // Cancel any pending auto-stop
                            maxDurationRunnable?.let { mainHandler.removeCallbacks(it) }
                            maxDurationRunnable = null

                            if (event.hasError()) {
                                Log.e(TAG, "Recording error: ${event.error}")
                            } else {
                                Log.d(TAG, "Recording finalized")
                            }

                            // If startRecordingCallback is still set, recording was stopped before first keyframe
                            // We need to notify Flutter that recording failed to start properly
                            startRecordingCallback?.let { startCallback ->
                                Log.w(TAG, "Recording stopped before first keyframe - notifying Flutter")
                                startCallback("Recording stopped before first keyframe")
                                startRecordingCallback = null
                            }

                            // Build the result map once
                            val file = currentRecordingFile
                            val result = if (file != null && file.exists() && file.length() > 0) {
                                val duration = System.currentTimeMillis() - recordingStartTime
                                mapOf(
                                    "filePath" to file.absolutePath,
                                    "durationMs" to duration.toInt(),
                                    "width" to videoWidth,
                                    "height" to videoHeight
                                )
                            } else null

                            // Handle manual stop callback (from stopRecording)
                            manualStopCallback?.let { manualCallback ->
                                if (result != null) {
                                    Log.d(TAG, "Manual stop recording result: $result")
                                    manualCallback(result, null)
                                } else {
                                    Log.w(TAG, "Manual stop: Recording file not found or empty")
                                    manualCallback(null, "Recording file not found or empty")
                                }
                                manualStopCallback = null
                            }

                            // Handle auto-stop callback (from max duration)
                            autoStopCallback?.let { autoCallback ->
                                if (result != null) {
                                    Log.d(TAG, "Auto-stop recording result: $result")
                                    autoCallback(result, null)
                                } else {
                                    autoCallback(null, "Recording file not found")
                                }
                                autoStopCallback = null
                            }

                            currentRecordingFile = null
                            recording = null
                        }
                    }
                }
            // Callback is now called in Status event when recording truly starts

        } catch (e: Exception) {
            Log.e(TAG, "Failed to start recording", e)
            startRecordingCallback = null
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
        
        // Disable auto-flash torch if it was enabled
        disableAutoFlashTorch()

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

    // Callback for manual stop recording - will be invoked when Finalize event fires
    private var manualStopCallback: ((Map<String, Any>?, String?) -> Unit)? = null

    /**
     * Stops video recording and returns the result.
     * Waits for the Finalize event to ensure the file is fully written.
     */
    fun stopRecording(callback: (Map<String, Any>?, String?) -> Unit) {
        val currentRecording = recording

        if (currentRecording == null || !isRecording) {
            callback(null, "Not recording")
            return
        }

        // If recording hasn't truly started yet (no keyframe), we need to handle this
        if (!recordingTrulyStarted) {
            Log.w(TAG, "Stopping recording before first keyframe - will return empty result")
            // The startRecordingCallback will be notified via Finalize event
            // We still need to call manualStopCallback, but it will get null result
        }

        try {
            Log.d(TAG, "Stopping recording...")
            
            // Disable auto-flash torch if it was enabled
            disableAutoFlashTorch()
            // Store callback to be invoked when Finalize event fires
            manualStopCallback = callback
            
            currentRecording.stop()
            // The Finalize event handler will call the callback when file is ready

        } catch (e: Exception) {
            Log.e(TAG, "Failed to stop recording", e)
            manualStopCallback = null
            callback(null, "Failed to stop recording: ${e.message}")
        }
    }

    /**
     * Pauses the camera preview.
     */
    fun pausePreview() {
        Log.d(TAG, "Pausing preview")
        forceDisableScreenFlash()
        isPaused = true
    }

    /**
     * Resumes the camera preview.
     */
    fun resumePreview(callback: (Map<String, Any>?, String?) -> Unit) {
        Log.d(TAG, "Resuming preview")
        isPaused = false
        
        // Re-enable screen flash if front camera torch mode was active
        if (currentLens == CameraSelector.LENS_FACING_FRONT && isTorchEnabled) {
            enableScreenFlash()
        }
        
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
        
        // Always restore screen brightness
        forceDisableScreenFlash()
        
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

            // Shutdown executor after a delay to let CameraX finish pending tasks
            // This prevents RejectedExecutionException during cleanup
            if (!cameraExecutor.isShutdown) {
                mainHandler.postDelayed({
                    try {
                        if (!cameraExecutor.isShutdown) {
                            cameraExecutor.shutdown()
                        }
                    } catch (e: Exception) {
                        Log.w(TAG, "Error shutting down executor: ${e.message}")
                    }
                }, 500)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error releasing camera", e)
        }
    }
}
