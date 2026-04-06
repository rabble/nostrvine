package co.openvine.divine_camera

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

/*
 * This demonstrates a simple unit test of the Kotlin portion of this plugin's implementation.
 *
 * Once you have built the plugin's example app, you can run these tests from the command
 * line by running `./gradlew testDebugUnitTest` in the `example/android/` directory, or
 * you can run them directly from IDEs that support JUnit such as Android Studio.
 */

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
