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
import androidx.camera.camera2.interop.Camera2CameraControl
import androidx.camera.camera2.interop.Camera2Interop
import androidx.camera.camera2.interop.CaptureRequestOptions
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
private const val LENS_SWITCH_HYSTERESIS = 0.03f

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

    // Whether to mirror front camera video output
    private var mirrorFrontCameraOutput: Boolean = true

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

    // Auto lens switching: unified virtual zoom across back lenses
    private var autoLensSwitchRequested: Boolean = true
    private var autoLensSwitchEnabled: Boolean = false
    private var isAutoSwitching: Boolean = false

    // Focal lengths from Camera2 (mm)
    private var mainCameraFocalLength: Float = 0f
    private var ultraWideCameraFocalLength: Float = 0f
    private var telephotoCameraFocalLength: Float = 0f

    // Zoom ratios relative to main (main = 1.0)
    private var ultraWideZoomRatio: Float = 0.5f
    private var telephotoZoomRatio: Float = 2.0f

    // Virtual zoom (1.0 = main at native 1x)
    private var virtualMinZoom: Float = 1.0f
    private var virtualMaxZoom: Float = 1.0f
    private var virtualCurrentZoom: Float = 1.0f

    // Native max zoom estimates (Camera2 SCALER_AVAILABLE_MAX_DIGITAL_ZOOM)
    private var ultraWideNativeMaxZoom: Float = 8.0f
    private var mainNativeMaxZoom: Float = 10.0f
    private var telephotoNativeMaxZoom: Float = 10.0f

    // Portrait-Modus: 9:16, 1080x1920
    private var aspectRatio: Float = 9f / 16f
    private var videoWidth: Int = 1080
    private var videoHeight: Int = 1920

    private var hasFrontCamera: Boolean = false
    private var hasBackCamera: Boolean = false
    private var hasFlash: Boolean = false
    private var isFocusPointSupported: Boolean = false
    private var isExposurePointSupported: Boolean = false
    
    // Multi-lens support: camera IDs for each lens type
    private var frontCameraId: String? = null
    private var frontUltraWideCameraId: String? = null
    private var backCameraId: String? = null
    private var ultraWideCameraId: String? = null
    private var telephotoCameraId: String? = null
    private var macroCameraId: String? = null
    
    // Track current lens type (more granular than just front/back)
    private var currentLensType: String = "back"

    private var recordingStartTime: Long = 0
    private var currentRecordingFile: File? = null
    private var videoQuality: Quality = Quality.FHD
    private var maxDurationRunnable: Runnable? = null
    private var autoStopCallback: ((Map<String, Any?>?, String?) -> Unit)? = null

    // Quality fallback: when the hardware encoder rejects the requested quality
    // (e.g. device falsely reports FHD support), retry with lower quality.
    private var encoderRetryCount: Int = 0
    private var pendingRecordingParams: RecordingParams? = null

    private data class RecordingParams(
        val maxDurationMs: Int?,
        val useCache: Boolean,
        val outputDirectory: String?,
        val callback: (String?) -> Unit
    )

    companion object {
        private const val MAX_ENCODER_RETRIES = 2

        /** Returns the next lower quality, or null if already at minimum. */
        fun lowerQuality(current: Quality): Quality? = when (current) {
            Quality.UHD -> Quality.FHD
            Quality.FHD -> Quality.HD
            Quality.HIGHEST -> Quality.FHD
            Quality.HD -> Quality.SD
            else -> null
        }
    }

    /** Listener for auto-stop events, set by the plugin. */
    var onAutoStopListener: ((Map<String, Any?>) -> Unit)? = null

    /**
     * Initializes the camera with the specified lens and video quality.
     */
    fun initialize(
        lens: String,
        quality: String,
        enableScreenFlash: Boolean = true,
        mirrorFrontCameraOutput: Boolean = true,
        enableAutoLensSwitch: Boolean = true,
        callback: (Map<String, Any?>?, String?) -> Unit
    ) {
        Log.d(TAG, "Initializing camera with lens: $lens, quality: $quality, enableScreenFlash: $enableScreenFlash, mirrorFrontCameraOutput: $mirrorFrontCameraOutput, autoLensSwitch: $enableAutoLensSwitch (portrait mode 1080x1920)")

        screenFlashFeatureEnabled = enableScreenFlash
        this.mirrorFrontCameraOutput = mirrorFrontCameraOutput
        this.autoLensSwitchRequested = enableAutoLensSwitch

        // Map lens string to lens type and facing
        currentLensType = lens
        currentLens = getLensFacingForType(lens)

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
        val requestedCameraId = getCameraIdForLens(currentLensType)
        if (requestedCameraId == null) {
            // Fallback: try back camera first, then front
            if (hasBackCamera) {
                Log.w(TAG, "Requested lens $lens not available, falling back to back camera")
                currentLensType = "back"
                currentLens = CameraSelector.LENS_FACING_BACK
            } else if (hasFrontCamera) {
                Log.w(TAG, "Requested lens $lens not available, falling back to front camera")
                currentLensType = "front"
                currentLens = CameraSelector.LENS_FACING_FRONT
            }
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
     * Detects front, back, ultra-wide, telephoto, and macro cameras.
     */
    private fun checkCameraAvailability() {
        try {
            val cameraManager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
            
            // Track focal lengths for cameras to determine lens types
            val backCameraFocalLengths = mutableMapOf<String, Float>()
            val frontCameraFocalLengths = mutableMapOf<String, Float>()
            
            for (cameraId in cameraManager.cameraIdList) {
                val characteristics = cameraManager.getCameraCharacteristics(cameraId)
                val facing = characteristics.get(CameraCharacteristics.LENS_FACING)
                val focalLengths = characteristics.get(CameraCharacteristics.LENS_INFO_AVAILABLE_FOCAL_LENGTHS)
                val capabilities = characteristics.get(CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES)
                
                // Check if this is a logical camera (multi-camera on newer devices)
                val isLogicalCamera = capabilities?.contains(
                    CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES_LOGICAL_MULTI_CAMERA
                ) == true
                
                when (facing) {
                    CameraCharacteristics.LENS_FACING_FRONT -> {
                        val primaryFocalLength = focalLengths?.firstOrNull() ?: 0f
                        frontCameraFocalLengths[cameraId] = primaryFocalLength
                        Log.d(TAG, "Front camera $cameraId: focalLength=$primaryFocalLength, logical=$isLogicalCamera")
                    }
                    CameraCharacteristics.LENS_FACING_BACK -> {
                        // Get the primary focal length for this camera
                        val primaryFocalLength = focalLengths?.firstOrNull() ?: 0f
                        backCameraFocalLengths[cameraId] = primaryFocalLength
                        Log.d(TAG, "Back camera $cameraId: focalLength=$primaryFocalLength, logical=$isLogicalCamera")
                    }
                }
            }
            
            // Analyze front cameras by focal length
            if (frontCameraFocalLengths.isNotEmpty()) {
                val sorted = frontCameraFocalLengths.entries.sortedByDescending { it.value }
                
                // The camera with the longer focal length is the "normal" front camera
                // The camera with the shorter focal length is the ultra-wide front camera
                hasFrontCamera = true
                frontCameraId = sorted.first().key
                
                if (sorted.size > 1) {
                    // Second camera (shorter focal length) is front ultra-wide
                    val ultraWideCandidate = sorted.last()
                    if (ultraWideCandidate.value < sorted.first().value - 0.3f) {
                        frontUltraWideCameraId = ultraWideCandidate.key
                        Log.d(TAG, "Front ultra-wide camera detected: ${ultraWideCandidate.key}")
                    }
                }
            }
            
            // Analyze back cameras by focal length to determine type
            if (backCameraFocalLengths.isNotEmpty()) {
                // Sort by focal length
                val sorted = backCameraFocalLengths.entries.sortedBy { it.value }
                
                // Find the "normal" lens (typically around 4-6mm on smartphones)
                // This is usually the primary back camera
                val normalRange = 3.0f..8.0f
                val normalCamera = sorted.find { it.value in normalRange }
                
                if (normalCamera != null) {
                    hasBackCamera = true
                    backCameraId = normalCamera.key
                    mainCameraFocalLength = normalCamera.value

                    // Read main camera's max digital zoom
                    try {
                        val mainChars = cameraManager
                            .getCameraCharacteristics(normalCamera.key)
                        mainNativeMaxZoom = mainChars.get(
                            CameraCharacteristics
                                .SCALER_AVAILABLE_MAX_DIGITAL_ZOOM
                        ) ?: 10.0f
                    } catch (e: Exception) {
                        Log.w(TAG, "Could not read main camera max zoom", e)
                    }
                    
                    // Cameras with shorter focal length are ultra-wide
                    sorted.filter { it.value < normalCamera.value - 0.5f && it.key != normalCamera.key }
                        .maxByOrNull { it.value }?.let {
                            ultraWideCameraId = it.key
                            ultraWideCameraFocalLength = it.value
                            Log.d(TAG, "Ultra-wide camera detected: ${it.key} (focal=${it.value}mm)")
                            try {
                                val uwChars = cameraManager
                                    .getCameraCharacteristics(it.key)
                                ultraWideNativeMaxZoom = uwChars.get(
                                    CameraCharacteristics
                                        .SCALER_AVAILABLE_MAX_DIGITAL_ZOOM
                                ) ?: 8.0f
                            } catch (e: Exception) {
                                Log.w(TAG, "Could not read ultra-wide max zoom", e)
                            }
                        }
                    
                    // Cameras with longer focal length are telephoto
                    sorted.filter { it.value > normalCamera.value + 1.0f && it.key != normalCamera.key }
                        .minByOrNull { it.value }?.let {
                            telephotoCameraId = it.key
                            telephotoCameraFocalLength = it.value
                            Log.d(TAG, "Telephoto camera detected: ${it.key} (focal=${it.value}mm)")
                            try {
                                val teleChars = cameraManager
                                    .getCameraCharacteristics(it.key)
                                telephotoNativeMaxZoom = teleChars.get(
                                    CameraCharacteristics
                                        .SCALER_AVAILABLE_MAX_DIGITAL_ZOOM
                                ) ?: 10.0f
                            } catch (e: Exception) {
                                Log.w(TAG, "Could not read telephoto max zoom", e)
                            }
                        }
                } else if (sorted.isNotEmpty()) {
                    // Fallback: use the first back camera as main
                    hasBackCamera = true
                    backCameraId = sorted.first().key
                    mainCameraFocalLength = sorted.first().value
                }
                
                // Check for macro capability (often detected by very short minimum focus distance)
                for ((cameraId, _) in sorted) {
                    val chars = cameraManager.getCameraCharacteristics(cameraId)
                    val minFocusDistance = chars.get(CameraCharacteristics.LENS_INFO_MINIMUM_FOCUS_DISTANCE)
                    // Macro cameras typically have minimum focus distance > 10 diopters (< 10cm focus)
                    if (minFocusDistance != null && minFocusDistance > 10.0f && cameraId != backCameraId) {
                        macroCameraId = cameraId
                        Log.d(TAG, "Macro camera detected: $cameraId (minFocusDist=$minFocusDistance)")
                        break
                    }
                }
            }
            
            Log.d(TAG, "Camera availability: front=$hasFrontCamera, " +
                "frontUltraWide=${frontUltraWideCameraId != null}, back=$hasBackCamera, " +
                "ultraWide=${ultraWideCameraId != null}, telephoto=${telephotoCameraId != null}, " +
                "macro=${macroCameraId != null}")
        } catch (e: Exception) {
            Log.e(TAG, "Error checking camera availability", e)
        }
    }
    
    /**
     * Returns a list of available lens types on this device.
     */
    private fun getAvailableLenses(): List<String> {
        val lenses = mutableListOf<String>()
        if (hasFrontCamera) lenses.add("front")
        if (frontUltraWideCameraId != null) lenses.add("frontUltraWide")
        if (hasBackCamera) lenses.add("back")
        if (ultraWideCameraId != null) lenses.add("ultraWide")
        if (telephotoCameraId != null) lenses.add("telephoto")
        if (macroCameraId != null) lenses.add("macro")
        return lenses
    }
    
    /**
     * Gets metadata for the currently active camera lens.
     */
    private fun getCurrentLensMetadata(): Map<String, Any?>? {
        val cameraId = getCameraIdForLens(currentLensType) ?: return null
        return try {
            val cameraManager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
            val chars = cameraManager.getCameraCharacteristics(cameraId)
            extractCameraMetadata(chars, currentLensType, cameraId)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get metadata for current lens $currentLensType", e)
            null
        }
    }

    /**
     * Extracts metadata from CameraCharacteristics for a specific camera.
     */
    private fun extractCameraMetadata(
        chars: CameraCharacteristics,
        lensType: String,
        cameraId: String
    ): Map<String, Any?> {
        // Focal lengths (mm)
        val focalLengths = chars.get(CameraCharacteristics.LENS_INFO_AVAILABLE_FOCAL_LENGTHS)
        val focalLength = focalLengths?.firstOrNull()?.toDouble()
        
        // Apertures (f-number)
        val apertures = chars.get(CameraCharacteristics.LENS_INFO_AVAILABLE_APERTURES)
        val aperture = apertures?.firstOrNull()?.toDouble()
        
        // Sensor physical size (mm)
        val sensorSize = chars.get(CameraCharacteristics.SENSOR_INFO_PHYSICAL_SIZE)
        val sensorWidth = sensorSize?.width?.toDouble()
        val sensorHeight = sensorSize?.height?.toDouble()
        
        // Sensor pixel dimensions
        val pixelArraySize = chars.get(CameraCharacteristics.SENSOR_INFO_PIXEL_ARRAY_SIZE)
        val pixelArrayWidth = pixelArraySize?.width
        val pixelArrayHeight = pixelArraySize?.height
        
        // Minimum focus distance (diopters: 1/distance in meters)
        val minFocusDistance = chars.get(CameraCharacteristics.LENS_INFO_MINIMUM_FOCUS_DISTANCE)?.toDouble()
        
        // Calculate 35mm equivalent focal length
        // 35mm full frame diagonal = 43.27mm
        // Smartphone sensor diagonal = sqrt(width^2 + height^2)
        val focalLengthEquivalent35mm = if (focalLength != null && sensorWidth != null && sensorHeight != null) {
            val sensorDiagonal = kotlin.math.sqrt(sensorWidth * sensorWidth + sensorHeight * sensorHeight)
            val cropFactor = 43.27 / sensorDiagonal
            focalLength * cropFactor
        } else null
        
        // Calculate horizontal field of view (degrees)
        // FOV = 2 * arctan(sensor_width / (2 * focal_length))
        val fieldOfView = if (focalLength != null && sensorWidth != null && focalLength > 0) {
            val fovRadians = 2 * kotlin.math.atan(sensorWidth / (2 * focalLength))
            Math.toDegrees(fovRadians)
        } else null
        
        // Optical stabilization
        val oisModes = chars.get(CameraCharacteristics.LENS_INFO_AVAILABLE_OPTICAL_STABILIZATION)
        val hasOpticalStabilization = oisModes?.contains(
            CameraCharacteristics.LENS_OPTICAL_STABILIZATION_MODE_ON
        ) == true
        
        // Logical camera (multi-camera system)
        val capabilities = chars.get(CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES)
        val isLogicalCamera = capabilities?.contains(
            CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES_LOGICAL_MULTI_CAMERA
        ) == true
        
        // Physical camera IDs for logical cameras (Android 9+)
        val physicalCameraIds = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.P && isLogicalCamera) {
            chars.physicalCameraIds.toList()
        } else {
            emptyList()
        }
        
        // Exposure time range (nanoseconds) - static capability, not live value
        val exposureTimeRange = chars.get(CameraCharacteristics.SENSOR_INFO_EXPOSURE_TIME_RANGE)
        val exposureTimeMin = exposureTimeRange?.lower?.toDouble()?.div(1_000_000_000.0)  // Convert ns to seconds
        val exposureTimeMax = exposureTimeRange?.upper?.toDouble()?.div(1_000_000_000.0)  // Convert ns to seconds
        
        // ISO sensitivity range - static capability, not live value
        val isoRange = chars.get(CameraCharacteristics.SENSOR_INFO_SENSITIVITY_RANGE)
        val isoMin = isoRange?.lower
        val isoMax = isoRange?.upper
        
        return mapOf(
            "lensType" to lensType,
            "cameraId" to cameraId,
            "focalLength" to focalLength,
            "focalLengthEquivalent35mm" to focalLengthEquivalent35mm,
            "aperture" to aperture,
            "sensorWidth" to sensorWidth,
            "sensorHeight" to sensorHeight,
            "pixelArrayWidth" to pixelArrayWidth,
            "pixelArrayHeight" to pixelArrayHeight,
            "minFocusDistance" to minFocusDistance,
            "fieldOfView" to fieldOfView,
            "hasOpticalStabilization" to hasOpticalStabilization,
            "isLogicalCamera" to isLogicalCamera,
            "physicalCameraIds" to physicalCameraIds,
            "exposureTimeMin" to exposureTimeMin,
            "exposureTimeMax" to exposureTimeMax,
            "isoMin" to isoMin,
            "isoMax" to isoMax
        )
    }

    /**
     * Gets the camera ID for a given lens type.
     */
    private fun getCameraIdForLens(lensType: String): String? {
        return when (lensType) {
            "front" -> frontCameraId
            "frontUltraWide" -> frontUltraWideCameraId
            "back" -> backCameraId
            "ultraWide" -> ultraWideCameraId
            "telephoto" -> telephotoCameraId
            "macro" -> macroCameraId
            else -> backCameraId
        }
    }
    
    /**
     * Gets the lens facing value for CameraSelector based on lens type.
     */
    private fun getLensFacingForType(lensType: String): Int {
        return when (lensType) {
            "front", "frontUltraWide" -> CameraSelector.LENS_FACING_FRONT
            else -> CameraSelector.LENS_FACING_BACK
        }
    }
    
    /**
     * Builds a CameraSelector for the specified lens type.
     * For specialized lenses (ultraWide, telephoto, macro, frontUltraWide), uses Camera2Interop
     * to select a specific camera by ID.
     */
    @SuppressLint("UnsafeOptInUsageError")
    private fun buildCameraSelectorForLens(
        lensType: String,
        provider: ProcessCameraProvider
    ): CameraSelector {
        val cameraId = getCameraIdForLens(lensType)
        
        // For standard front/back cameras or if no specific ID found, use simple lens facing
        if (cameraId == null || (lensType == "front" && frontUltraWideCameraId == null) || lensType == "back") {
            return CameraSelector.Builder()
                .requireLensFacing(getLensFacingForType(lensType))
                .build()
        }
        
        // For specialized lenses (and front when multiple front cameras exist), filter by camera ID using Camera2Interop
        return CameraSelector.Builder()
            .addCameraFilter { cameras ->
                cameras.filter { cameraInfo ->
                    try {
                        val camera2Info = Camera2CameraInfo.from(cameraInfo)
                        camera2Info.cameraId == cameraId
                    } catch (e: Exception) {
                        Log.w(TAG, "Failed to get Camera2CameraInfo: ${e.message}")
                        false
                    }
                }
            }
            .build()
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
    private fun startCamera(callback: (Map<String, Any?>?, String?) -> Unit) {
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

            // Build camera selector for the current lens type
            val cameraSelector = buildCameraSelectorForLens(currentLensType, provider)

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

            // Mirror front camera video output based on mirrorFrontCameraOutput setting
            videoCapture = VideoCapture.Builder(recorder)
                .setMirrorMode(
                    if (mirrorFrontCameraOutput && currentLens == CameraSelector.LENS_FACING_FRONT)
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

            // Compute virtual zoom ranges for auto lens switching
            computeVirtualZoomRanges()

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
        callback: (Map<String, Any?>?, String?) -> Unit
    ) {
        Log.d(TAG, "Switching camera to: $lens")
        
        // Disable screen flash when switching cameras
        disableScreenFlash()
        
        // Map lens string to lens type and facing
        currentLensType = lens
        currentLens = getLensFacingForType(lens)
        
        // Check if the requested lens is available
        val requestedCameraId = getCameraIdForLens(currentLensType)
        if (requestedCameraId == null) {
            Log.e(TAG, "Requested lens $lens is not available")
            callback(null, "Lens $lens is not available on this device")
            return
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

            // Build camera selector for the requested lens
            // For specialized lenses (ultraWide, telephoto, macro), we need to use Camera2 interop
            val cameraSelector = buildCameraSelectorForLens(currentLensType, provider)

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

            // Mirror front camera video output based on mirrorFrontCameraOutput setting
            videoCapture = VideoCapture.Builder(recorder)
                .setMirrorMode(
                    if (mirrorFrontCameraOutput && currentLens == CameraSelector.LENS_FACING_FRONT)
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

            // Compute virtual zoom ranges for auto lens switching
            computeVirtualZoomRanges()

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
     * Uses CameraX FocusMeteringAction with explicit AF+AE flags and spot metering.
     * Focus is locked for 3 seconds, then returns to continuous auto-focus.
     */
    fun setFocusPoint(x: Float, y: Float): Boolean {
        val cam = camera ?: return false

        return try {
            // SurfaceOrientedMeteringPointFactory with (1f, 1f) accepts normalized 0-1 coordinates
            val factory = SurfaceOrientedMeteringPointFactory(1f, 1f)
            
            // Create a SMALL metering point (10% of frame) for spot-metering like native camera
            // The third parameter is the size of the metering region (0.0 to 1.0)
            // Smaller = more precise exposure adjustment at tap point
            val point = factory.createPoint(x, y, 0.1f)
            
            // Use all three flags for complete metering adjustment:
            // FLAG_AF = Autofocus (focus on tap point)
            // FLAG_AE = Auto Exposure (adjust brightness/contrast based on tap point)
            // FLAG_AWB = Auto White Balance (adjust color temperature)
            val action = FocusMeteringAction.Builder(
                point, 
                FocusMeteringAction.FLAG_AF or FocusMeteringAction.FLAG_AE or FocusMeteringAction.FLAG_AWB
            )
                .setAutoCancelDuration(3, java.util.concurrent.TimeUnit.SECONDS)
                .build()
            
            val future = cam.cameraControl.startFocusAndMetering(action)
            future.addListener({
                try {
                    val result = future.get()
                    Log.d(TAG, "Focus+AE ${if (result.isFocusSuccessful) "successful" else "adjusting"} at: ($x, $y)")
                } catch (e: Exception) {
                    Log.d(TAG, "Focus check: ${e.message}")
                }
            }, ContextCompat.getMainExecutor(context))
            
            Log.d(TAG, "Focus point set: ($x, $y) with FLAG_AF|FLAG_AE, 10% spot metering")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to set focus point", e)
            false
        }
    }

    /**
     * Sets the exposure point in normalized coordinates (0.0-1.0).
     * For exposure-only adjustment without changing focus.
     */
    fun setExposurePoint(x: Float, y: Float): Boolean {
        val cam = camera ?: return false

        return try {
            // SurfaceOrientedMeteringPointFactory with (1f, 1f) accepts normalized 0-1 coordinates
            val factory = SurfaceOrientedMeteringPointFactory(1f, 1f)
            val point = factory.createPoint(x, y)
            
            val action = FocusMeteringAction.Builder(point, FocusMeteringAction.FLAG_AE)
                // Keep exposure locked for 5 seconds before returning to auto
                .setAutoCancelDuration(5, java.util.concurrent.TimeUnit.SECONDS)
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
     * Cancels any active focus/metering lock and returns to continuous auto-focus.
     * Call this when you want to reset focus behavior after a tap-to-focus.
     */
    fun cancelFocusAndMetering(): Boolean {
        val cam = camera ?: return false
        
        return try {
            cam.cameraControl.cancelFocusAndMetering()
            Log.d(TAG, "Focus and metering cancelled - returning to continuous auto-focus")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to cancel focus and metering", e)
            false
        }
    }

    /**
     * Computes the virtual zoom range across all available back-facing lenses.
     * Virtual zoom 1.0 = main camera at native 1x.
     * Below 1.0 = ultra-wide territory.
     * Above telephotoRatio = telephoto territory.
     *
     * Call after camera binds to ensure accurate zoom ranges.
     */
    private fun computeVirtualZoomRanges() {
        // Only for back-facing cameras with multiple lenses
        if (currentLens == CameraSelector.LENS_FACING_FRONT
            || mainCameraFocalLength <= 0f
        ) {
            autoLensSwitchEnabled = false
            virtualMinZoom = minZoom
            virtualMaxZoom = maxZoom
            virtualCurrentZoom = currentZoom
            return
        }

        // If the bound camera already supports zooming below 1.0x,
        // it is a logical multi-camera whose HAL handles smooth
        // cross-fade transitions between physical sensors internally.
        // Skip manual auto-switching for a much smoother experience.
        if (minZoom < 1.0f) {
            autoLensSwitchEnabled = false
            virtualMinZoom = minZoom
            virtualMaxZoom = maxZoom
            virtualCurrentZoom = currentZoom
            Log.d(
                TAG,
                "Logical multi-camera detected " +
                    "(native minZoom=$minZoom, maxZoom=$maxZoom), " +
                    "using native zoom for smooth transitions"
            )
            return
        }

        // Refine max zoom estimates with actual CameraX values
        when (currentLensType) {
            "back" -> mainNativeMaxZoom = maxZoom
            "ultraWide" -> ultraWideNativeMaxZoom = maxZoom
            "telephoto" -> telephotoNativeMaxZoom = maxZoom
        }

        // Focal length ratios relative to main camera
        if (ultraWideCameraFocalLength > 0f
            && ultraWideCameraId != null
        ) {
            ultraWideZoomRatio =
                ultraWideCameraFocalLength / mainCameraFocalLength
        }
        if (telephotoCameraFocalLength > 0f
            && telephotoCameraId != null
        ) {
            telephotoZoomRatio =
                telephotoCameraFocalLength / mainCameraFocalLength
        }

        // Virtual min: ultra-wide at native 1x, or main camera's min
        virtualMinZoom = if (
            ultraWideCameraId != null && ultraWideZoomRatio > 0f
        ) {
            ultraWideZoomRatio
        } else {
            minZoom
        }

        // Virtual max: telephoto at max zoom, or main camera's max
        virtualMaxZoom = if (
            telephotoCameraId != null && telephotoZoomRatio > 0f
        ) {
            telephotoZoomRatio * telephotoNativeMaxZoom
        } else {
            mainNativeMaxZoom
        }

        // Current virtual zoom derived from active lens
        virtualCurrentZoom = when (currentLensType) {
            "ultraWide" -> currentZoom * ultraWideZoomRatio
            "telephoto" -> currentZoom * telephotoZoomRatio
            else -> currentZoom
        }

        autoLensSwitchEnabled = autoLensSwitchRequested &&
            (ultraWideCameraId != null || telephotoCameraId != null)

        Log.d(
            TAG,
            "Virtual zoom: min=$virtualMinZoom, max=$virtualMaxZoom, " +
                "current=$virtualCurrentZoom, uwRatio=$ultraWideZoomRatio, " +
                "teleRatio=$telephotoZoomRatio, enabled=$autoLensSwitchEnabled"
        )
    }

    /**
     * Converts a virtual zoom level to the target lens type and native zoom.
     * Uses hysteresis to prevent oscillation at transition points.
     */
    private fun virtualToNativeZoom(
        virtualZoom: Float
    ): Pair<String, Float> {
        // Ultra-wide range: below 1.0x (with hysteresis)
        if (ultraWideCameraId != null) {
            val useUltraWide = if (currentLensType == "ultraWide") {
                // Stay on ultra-wide until clearly above 1.0
                virtualZoom < 1.0f + LENS_SWITCH_HYSTERESIS
            } else {
                virtualZoom < 1.0f
            }
            if (useUltraWide) {
                return Pair(
                    "ultraWide",
                    virtualZoom / ultraWideZoomRatio
                )
            }
        }

        // Telephoto range (with hysteresis)
        if (telephotoCameraId != null && telephotoZoomRatio > 1.0f) {
            val useTelephoto = if (currentLensType == "telephoto") {
                // Stay on telephoto until clearly below ratio
                virtualZoom >= telephotoZoomRatio - LENS_SWITCH_HYSTERESIS
            } else {
                virtualZoom >= telephotoZoomRatio
            }
            if (useTelephoto) {
                return Pair(
                    "telephoto",
                    virtualZoom / telephotoZoomRatio
                )
            }
        }

        return Pair("back", virtualZoom)
    }

    /**
     * Internally switches the camera lens for zoom-based auto-switching.
     * Reuses the existing Flutter texture for minimal visual disruption.
     * Does NOT switch during recording to avoid interruption.
     */
    private fun autoSwitchToLens(
        targetLensType: String,
        targetNativeZoom: Float
    ) {
        if (isAutoSwitching || isRecording) return

        val provider = cameraProvider ?: return
        if (activity !is LifecycleOwner) return

        isAutoSwitching = true
        Log.d(
            TAG,
            "Auto-switching $currentLensType -> $targetLensType " +
                "(nativeZoom=$targetNativeZoom)"
        )

        try {
            currentLensType = targetLensType
            currentLens = getLensFacingForType(targetLensType)

            provider.unbindAll()

            val cameraSelector =
                buildCameraSelectorForLens(targetLensType, provider)
            val targetAspectRatio = AspectRatio.RATIO_16_9

            preview = buildPreviewWithExposureMonitoring(targetAspectRatio)
            // Delay surface provision so the zoom is fully applied
            // before the first frame renders. The Flutter texture keeps
            // the last frame from the previous camera (natural freeze)
            // during the brief delay, preventing a visible zoom jump.
            preview?.setSurfaceProvider(
                ContextCompat.getMainExecutor(context)
            ) { request ->
                val resolution = request.resolution
                videoWidth = resolution.width
                videoHeight = resolution.height
                aspectRatio =
                    videoHeight.toFloat() / videoWidth.toFloat()
                flutterSurfaceTexture?.setDefaultBufferSize(
                    videoWidth,
                    videoHeight
                )

                // Post surface provision to let setZoomRatio settle
                // in the camera pipeline before any frames flow.
                mainHandler.postDelayed({
                    val surface = if (
                        previewSurface != null &&
                        previewSurface!!.isValid
                    ) {
                        previewSurface!!
                    } else {
                        previewSurface =
                            Surface(flutterSurfaceTexture)
                        previewSurface!!
                    }

                    if (surface.isValid) {
                        request.provideSurface(
                            surface,
                            ContextCompat.getMainExecutor(
                                context
                            )
                        ) { result ->
                            Log.d(
                                TAG,
                                "AutoSwitch surface: " +
                                    "${result.resultCode}"
                            )
                        }
                    }
                    isAutoSwitching = false
                    Log.d(
                        TAG,
                        "AutoSwitch surface provided " +
                            "(delayed)"
                    )
                }, 100)
            }

            val recorder = Recorder.Builder()
                .setQualitySelector(
                    QualitySelector.from(
                        videoQuality,
                        FallbackStrategy.lowerQualityOrHigherThan(
                            Quality.SD
                        )
                    )
                )
                .setAspectRatio(targetAspectRatio)
                .setExecutor(cameraExecutor)
                .build()

            videoCapture = VideoCapture.Builder(recorder)
                .setMirrorMode(
                    if (mirrorFrontCameraOutput &&
                        currentLens ==
                        CameraSelector.LENS_FACING_FRONT
                    ) {
                        MirrorMode.MIRROR_MODE_ON_FRONT_ONLY
                    } else {
                        MirrorMode.MIRROR_MODE_OFF
                    }
                )
                .build()

            camera = provider.bindToLifecycle(
                activity as LifecycleOwner,
                cameraSelector,
                preview,
                videoCapture
            )

            camera?.let { cam ->
                val zoomState =
                    cam.cameraInfo.zoomState.value
                minZoom = zoomState?.minZoomRatio ?: 1.0f
                maxZoom = zoomState?.maxZoomRatio ?: 1.0f
                hasFlash = cam.cameraInfo.hasFlashUnit() ||
                    (screenFlashFeatureEnabled &&
                        currentLens ==
                        CameraSelector.LENS_FACING_FRONT)

                val clampedZoom =
                    targetNativeZoom.coerceIn(minZoom, maxZoom)
                cam.cameraControl.setZoomRatio(clampedZoom)
                currentZoom = clampedZoom
            }

            computeVirtualZoomRanges()

            Log.d(
                TAG,
                "Auto-switch done: $targetLensType " +
                    "native=$currentZoom virtual=$virtualCurrentZoom"
            )
        } catch (e: Exception) {
            Log.e(
                TAG,
                "Failed to auto-switch to $targetLensType",
                e
            )
            isAutoSwitching = false
        }
    }

    /**
     * Sets the zoom level. When auto lens switching is enabled,
     * accepts a virtual zoom level spanning all available back lenses.
     * 1.0 = main at native 1x. Below 1.0 = ultra-wide. Above
     * telephoto ratio = telephoto.
     */
    fun setZoomLevel(level: Float): Boolean {
        // Without auto lens switching, use direct camera zoom
        if (!autoLensSwitchEnabled) {
            val cam = camera ?: return false
            return try {
                // When auto lens switch is disabled, clamp to 1.0 minimum
                // to prevent native HAL from switching to ultra-wide on
                // logical multi-cameras.
                val effectiveMin = if (!autoLensSwitchRequested && minZoom < 1.0f) 1.0f else minZoom
                val clampedLevel =
                    level.coerceIn(effectiveMin, maxZoom)
                cam.cameraControl.setZoomRatio(clampedLevel)
                currentZoom = clampedLevel
                Log.d(TAG, "Zoom level set: $clampedLevel")
                true
            } catch (e: Exception) {
                Log.e(TAG, "Failed to set zoom level", e)
                false
            }
        }

        // Virtual zoom: map across all back lenses
        val clampedVirtual =
            level.coerceIn(virtualMinZoom, virtualMaxZoom)
        virtualCurrentZoom = clampedVirtual

        val (targetLens, nativeZoom) =
            virtualToNativeZoom(clampedVirtual)

        // Switch lens if needed (skip during recording)
        if (targetLens != currentLensType && !isRecording) {
            autoSwitchToLens(targetLens, nativeZoom)
            return true
        }

        // Same lens: adjust native zoom directly
        val cam = camera ?: return false
        return try {
            val clampedNative =
                nativeZoom.coerceIn(minZoom, maxZoom)
            cam.cameraControl.setZoomRatio(clampedNative)
            currentZoom = clampedNative
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

        // Reset retry counter for a fresh recording attempt initiated by the user
        encoderRetryCount = 0
        pendingRecordingParams = RecordingParams(maxDurationMs, useCache, outputDirectory, callback)

        // Check audio permission
        if (ActivityCompat.checkSelfPermission(
                context,
                Manifest.permission.RECORD_AUDIO
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            callback("Audio permission not granted")
            return
        }

        startRecordingInternal(maxDurationMs, useCache, outputDirectory, callback)
    }

    /**
     * Internal recording start — also used for encoder-fallback retries.
     */
    @SuppressLint("MissingPermission")
    private fun startRecordingInternal(
        maxDurationMs: Int?,
        useCache: Boolean,
        outputDirectory: String?,
        callback: (String?) -> Unit
    ) {
        val videoCap = videoCapture ?: run {
            callback("Video capture not initialized")
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
                                // Encoder succeeded — clear retry state
                                encoderRetryCount = 0
                                pendingRecordingParams = null
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

                            // If startRecordingCallback is still set, recording was stopped before first keyframe.
                            // This typically means the hardware encoder rejected the resolution.
                            // Try to reinitialize with a lower quality before giving up.
                            if (startRecordingCallback != null && event.hasError()) {
                                val lower = lowerQuality(videoQuality)
                                if (lower != null && encoderRetryCount < MAX_ENCODER_RETRIES) {
                                    encoderRetryCount++
                                    Log.w(TAG, "Encoder failed at $videoQuality, retrying with $lower (attempt $encoderRetryCount/$MAX_ENCODER_RETRIES)")
                                    videoQuality = lower

                                    // Clean up failed recording file
                                    currentRecordingFile?.let { f ->
                                        if (f.exists()) f.delete()
                                    }
                                    currentRecordingFile = null
                                    recording = null

                                    // Consume the startRecordingCallback so it is not called yet
                                    val savedCallback = startRecordingCallback!!
                                    startRecordingCallback = null

                                    // Re-initialize camera with lower quality, then retry recording
                                    val params = pendingRecordingParams
                                    startCamera { _, error ->
                                        if (error != null) {
                                            Log.e(TAG, "Failed to reinitialize camera at $lower: $error")
                                            savedCallback("Recording failed: encoder not supported")
                                        } else {
                                            Log.d(TAG, "Camera reinitialized at $lower, retrying recording")
                                            startRecordingInternal(
                                                params?.maxDurationMs,
                                                params?.useCache ?: true,
                                                params?.outputDirectory,
                                                savedCallback
                                            )
                                        }
                                    }
                                    return@start
                                }

                                // No more fallback options — report failure
                                startRecordingCallback?.let { startCallback ->
                                    Log.w(TAG, "Recording stopped before first keyframe - no more quality fallbacks")
                                    startCallback("Recording stopped before first keyframe")
                                    startRecordingCallback = null
                                }
                            } else {
                                // Normal finalize — either successful or user-stopped
                                startRecordingCallback?.let { startCallback ->
                                    Log.w(TAG, "Recording stopped before first keyframe - notifying Flutter")
                                    startCallback("Recording stopped before first keyframe")
                                    startRecordingCallback = null
                                }
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
    private var manualStopCallback: ((Map<String, Any?>?, String?) -> Unit)? = null

    /**
     * Stops video recording and returns the result.
     * Waits for the Finalize event to ensure the file is fully written.
     */
    fun stopRecording(callback: (Map<String, Any?>?, String?) -> Unit) {
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
    fun resumePreview(callback: (Map<String, Any?>?, String?) -> Unit) {
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
    fun getCameraState(): MutableMap<String, Any?> {
        val textureId = textureEntry?.id() ?: -1L
        return mutableMapOf(
            "isInitialized" to (camera != null),
            "isRecording" to isRecording,
            "flashMode" to getFlashModeString(),
            "lens" to currentLensType,
            "zoomLevel" to (if (autoLensSwitchEnabled) virtualCurrentZoom else currentZoom).toDouble(),
            "minZoomLevel" to (if (autoLensSwitchEnabled) virtualMinZoom
                else if (!autoLensSwitchRequested && minZoom < 1.0f) 1.0f
                else minZoom).toDouble(),
            "maxZoomLevel" to (if (autoLensSwitchEnabled) virtualMaxZoom else maxZoom).toDouble(),
            "aspectRatio" to aspectRatio.toDouble(),
            "hasFlash" to hasFlash,
            "hasFrontCamera" to hasFrontCamera,
            "hasBackCamera" to hasBackCamera,
            "isFocusPointSupported" to isFocusPointSupported,
            "isExposurePointSupported" to isExposurePointSupported,
            "textureId" to textureId,
            "availableLenses" to getAvailableLenses(),
            "currentLensMetadata" to getCurrentLensMetadata()
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
