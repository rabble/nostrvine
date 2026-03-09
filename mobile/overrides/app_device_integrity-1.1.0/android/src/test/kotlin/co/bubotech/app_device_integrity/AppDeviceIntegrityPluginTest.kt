package co.bubotech.app_device_integrity

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertTrue
import java.util.Base64

class AppDeviceIntegrityPluginTest {

    @Test
    fun createNonce_usesChallengeInsteadOfConstantBytes() {
        val nonceA = AppDeviceIntegrity.createNonce("server-challenge-a")
        val nonceB = AppDeviceIntegrity.createNonce("server-challenge-b")

        assertNotNull(Base64.getUrlDecoder().decode(nonceA))
        assertEquals(32, Base64.getUrlDecoder().decode(nonceA).size)
        assertFalse(nonceA.contains("\n"))
        assertFalse(nonceA.contains("="))
        assertFalse(nonceA == nonceB)
    }

    @Test
    fun onDetachedFromActivity_doesNotThrowBeforeAttach() {
        val plugin = AppDeviceIntegrityPlugin()

        plugin.onDetachedFromActivity()
    }

    @Test
    fun onDetachedFromActivityForConfigChanges_doesNotThrowBeforeAttach() {
        val plugin = AppDeviceIntegrityPlugin()

        plugin.onDetachedFromActivityForConfigChanges()
    }

    @Test
    fun onMethodCall_missingChallenge_returnsError() {
        val plugin = AppDeviceIntegrityPlugin()
        val result = RecordingResult()

        plugin.onMethodCall(
            MethodCall("getAttestationServiceSupport", mapOf("gcp" to 123L)),
            result,
        )

        assertEquals("INVALID_ARGUMENT", result.errorCode)
        assertEquals("challengeString is required", result.errorMessage)
        assertTrue(result.successValue == null)
    }

    @Test
    fun onMethodCall_missingGcp_returnsError() {
        val plugin = AppDeviceIntegrityPlugin()
        val result = RecordingResult()

        plugin.onMethodCall(
            MethodCall("getAttestationServiceSupport", mapOf("challengeString" to "challenge")),
            result,
        )

        assertEquals("INVALID_ARGUMENT", result.errorCode)
        assertEquals("gcp is required on Android", result.errorMessage)
        assertTrue(result.successValue == null)
    }

    private class RecordingResult : Result {
        var successValue: Any? = null
        var errorCode: String? = null
        var errorMessage: String? = null
        var notImplementedCalled = false

        override fun success(result: Any?) {
            successValue = result
        }

        override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
            this.errorCode = errorCode
            this.errorMessage = errorMessage
        }

        override fun notImplemented() {
            notImplementedCalled = true
        }
    }
}
