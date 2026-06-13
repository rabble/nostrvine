package co.openvine.divine_camera

import android.hardware.camera2.CameraMetadata
import androidx.camera.video.Quality
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

/*
 * This demonstrates a simple unit test of the Kotlin portion of this plugin's implementation.
 *
 * Once you have built the plugin's example app, you can run these tests from the command
 * line by running `./gradlew testDebugUnitTest` in the `example/android/` directory, or
 * you can run them directly from IDEs that support JUnit such as Android Studio.
 */

@RunWith(RobolectricTestRunner::class)
internal class DivineCameraPluginTest {
    @Test
    fun onMethodCall_getPlatformVersion_returnsExpectedValue() {
        val plugin = DivineCameraPlugin()

        val call = MethodCall("getPlatformVersion", null)
        val result = RecordingResult()
        plugin.onMethodCall(call, result)

        assertEquals(1, result.successCount)
        assertEquals("Android " + android.os.Build.VERSION.RELEASE, result.lastSuccessValue)
        assertEquals(0, result.errorCount)
        assertEquals(0, result.notImplementedCount)
    }

    @Test
    fun oneShotResult_initializeStyleFlow_answersFlutterOnlyOnce() {
        val result = RecordingResult()
        val oneShot = OneShotMethodResult(result)

        oneShot.success(mapOf("textureId" to 42L))
        oneShot.error("INIT_ERROR", "late failure", null)

        assertEquals(1, result.successCount)
        assertEquals(mapOf("textureId" to 42L), result.lastSuccessValue)
        assertEquals(0, result.errorCount)
        assertEquals(0, result.notImplementedCount)
    }

    @Test
    fun oneShotResult_switchStyleFlow_answersFlutterOnlyOnce() {
        val result = RecordingResult()
        val oneShot = OneShotMethodResult(result)

        oneShot.error("SWITCH_ERROR", "first failure", null)
        oneShot.success(mapOf("camera" to "back"))

        assertEquals(0, result.successCount)
        assertEquals(1, result.errorCount)
        assertEquals("SWITCH_ERROR", result.lastErrorCode)
        assertEquals("first failure", result.lastErrorMessage)
        assertEquals(0, result.notImplementedCount)
    }

    @Test
    fun oneShotResult_recordStyleFlow_answersFlutterOnlyOnce() {
        val result = RecordingResult()
        val oneShot = OneShotMethodResult(result)

        oneShot.success(null)
        oneShot.success(mapOf("filePath" to "/tmp/video.mp4"))

        assertEquals(1, result.successCount)
        assertNull(result.lastSuccessValue)
        assertEquals(0, result.errorCount)
        assertEquals(0, result.notImplementedCount)
    }

    private class RecordingResult : MethodChannel.Result {
        var successCount: Int = 0
            private set
        var errorCount: Int = 0
            private set
        var notImplementedCount: Int = 0
            private set
        var lastSuccessValue: Any? = null
            private set
        var lastErrorCode: String? = null
            private set
        var lastErrorMessage: String? = null
            private set
        var lastErrorDetails: Any? = null
            private set

        override fun success(result: Any?) {
            successCount += 1
            lastSuccessValue = result
        }

        override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
            errorCount += 1
            lastErrorCode = errorCode
            lastErrorMessage = errorMessage
            lastErrorDetails = errorDetails
        }

        override fun notImplemented() {
            notImplementedCount += 1
        }
    }
}

@RunWith(RobolectricTestRunner::class)
internal class QualityFallbackTest {
    @Test
    fun lowerQuality_fromUHD_returnsFHD() {
        assertEquals(Quality.FHD, CameraController.lowerQuality(Quality.UHD))
    }

    @Test
    fun lowerQuality_fromFHD_returnsHD() {
        assertEquals(Quality.HD, CameraController.lowerQuality(Quality.FHD))
    }

    @Test
    fun lowerQuality_fromHIGHEST_returnsFHD() {
        assertEquals(Quality.FHD, CameraController.lowerQuality(Quality.HIGHEST))
    }

    @Test
    fun lowerQuality_fromHD_returnsSD() {
        assertEquals(Quality.SD, CameraController.lowerQuality(Quality.HD))
    }

    @Test
    fun lowerQuality_fromSD_returnsNull() {
        assertNull(CameraController.lowerQuality(Quality.SD))
    }

    @Test
    fun lowerQuality_fromLOWEST_returnsNull() {
        assertNull(CameraController.lowerQuality(Quality.LOWEST))
    }

    @Test
    fun fullFallbackChain_coversThreeSteps() {
        var quality: Quality? = Quality.UHD
        val chain = mutableListOf<Quality>()
        while (quality != null) {
            chain.add(quality)
            quality = CameraController.lowerQuality(quality)
        }
        assertEquals(
            listOf(Quality.UHD, Quality.FHD, Quality.HD, Quality.SD),
            chain
        )
    }
}

@RunWith(RobolectricTestRunner::class)
internal class VideoStabilizationTest {
    private val off = CameraMetadata.CONTROL_VIDEO_STABILIZATION_MODE_OFF
    private val on = CameraMetadata.CONTROL_VIDEO_STABILIZATION_MODE_ON
    private val preview =
        CameraMetadata.CONTROL_VIDEO_STABILIZATION_MODE_PREVIEW_STABILIZATION

    @Test
    fun isCanonicalStabilizationMode_recognisesKnownModes() {
        assertTrue(CameraController.isCanonicalStabilizationMode("off"))
        assertTrue(CameraController.isCanonicalStabilizationMode("standard"))
        assertTrue(CameraController.isCanonicalStabilizationMode("cinematic"))
        assertTrue(
            CameraController.isCanonicalStabilizationMode("cinematicExtended")
        )
        assertTrue(CameraController.isCanonicalStabilizationMode("auto"))
        assertFalse(CameraController.isCanonicalStabilizationMode("bogus"))
    }

    @Test
    fun buildList_noSupport_onlyOff() {
        assertEquals(
            listOf("off"),
            CameraController.buildStabilizationModeList(
                onSupported = false,
                previewStabilizationSupported = false,
            ),
        )
    }

    @Test
    fun buildList_onlyBasicEis_addsStandard() {
        assertEquals(
            listOf("off", "standard"),
            CameraController.buildStabilizationModeList(
                onSupported = true,
                previewStabilizationSupported = false,
            ),
        )
    }

    @Test
    fun buildList_previewSupported_addsStandardAndCinematic() {
        // cinematicExtended/auto are omitted on Android: they map to the same
        // PREVIEW_STABILIZATION as "cinematic".
        assertEquals(
            listOf("off", "standard", "cinematic"),
            CameraController.buildStabilizationModeList(
                onSupported = true,
                previewStabilizationSupported = true,
            ),
        )
    }

    @Test
    fun buildList_previewOnly_addsCinematic() {
        assertEquals(
            listOf("off", "cinematic"),
            CameraController.buildStabilizationModeList(
                onSupported = false,
                previewStabilizationSupported = true,
            ),
        )
    }

    @Test
    fun availableModes_nullCapabilities_onlyOff() {
        assertEquals(
            listOf("off"),
            CameraController.availableVideoStabilizationModes(null),
        )
    }

    @Test
    fun availableModes_onSupported_addsStandard() {
        assertEquals(
            listOf("off", "standard"),
            CameraController.availableVideoStabilizationModes(
                intArrayOf(off, on),
            ),
        )
    }

    @Test
    fun availableModes_previewSupported_addsCinematic() {
        assertEquals(
            listOf("off", "standard", "cinematic"),
            CameraController.availableVideoStabilizationModes(
                intArrayOf(off, on, preview),
            ),
        )
    }
}
