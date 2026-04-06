package co.openvine.app

import io.flutter.plugin.common.MethodChannel
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test

/**
 * Tests that MethodChannel result callbacks are guarded against
 * activity destruction, preventing FlutterJNI detach crashes.
 *
 * The crash (java.lang.RuntimeException: Cannot execute operation because
 * FlutterJNI is not attached to native) occurs when async callbacks
 * (ProofMode background thread, Zendesk network callback) try to send
 * results through a platform channel after the Flutter engine is destroyed.
 *
 * These tests verify that the lifecycle guard pattern works:
 * callbacks must check isActivityDestroyed/isFinishing before calling
 * result.success() or result.error().
 */
class FlutterJNILifecycleGuardTest {

    /**
     * Simulates the lifecycle guard pattern used in MainActivity.
     * Extracted here so we can test the logic without needing a real Activity.
     */
    class LifecycleGuardedCallback(
        private val isActivityDestroyed: () -> Boolean,
        private val isFinishing: () -> Boolean,
    ) {
        fun postResult(result: MethodChannel.Result, value: Any?) {
            if (isActivityDestroyed() || isFinishing()) {
                return
            }
            result.success(value)
        }

        fun postError(
            result: MethodChannel.Result,
            code: String,
            message: String?,
            details: Any?,
        ) {
            if (isActivityDestroyed() || isFinishing()) {
                return
            }
            result.error(code, message, details)
        }
    }

    private lateinit var result: MethodChannel.Result

    @Before
    fun setUp() {
        result = mockk(relaxed = true)
    }

    @Test
    fun `result success is delivered when activity is alive`() {
        val guard = LifecycleGuardedCallback(
            isActivityDestroyed = { false },
            isFinishing = { false },
        )

        guard.postResult(result, "proof_hash_123")

        verify(exactly = 1) { result.success("proof_hash_123") }
    }

    @Test
    fun `result success is dropped when activity is destroyed`() {
        val guard = LifecycleGuardedCallback(
            isActivityDestroyed = { true },
            isFinishing = { false },
        )

        guard.postResult(result, "proof_hash_123")

        verify(exactly = 0) { result.success(any()) }
    }

    @Test
    fun `result success is dropped when activity is finishing`() {
        val guard = LifecycleGuardedCallback(
            isActivityDestroyed = { false },
            isFinishing = { true },
        )

        guard.postResult(result, "proof_hash_123")

        verify(exactly = 0) { result.success(any()) }
    }

    @Test
    fun `result error is delivered when activity is alive`() {
        val guard = LifecycleGuardedCallback(
            isActivityDestroyed = { false },
            isFinishing = { false },
        )

        guard.postError(result, "PROOF_GENERATION_FAILED", "timeout", null)

        verify(exactly = 1) {
            result.error("PROOF_GENERATION_FAILED", "timeout", null)
        }
    }

    @Test
    fun `result error is dropped when activity is destroyed`() {
        val guard = LifecycleGuardedCallback(
            isActivityDestroyed = { true },
            isFinishing = { false },
        )

        guard.postError(result, "PROOF_GENERATION_FAILED", "timeout", null)

        verify(exactly = 0) { result.error(any(), any(), any()) }
    }

    @Test
    fun `result error is dropped when activity is finishing`() {
        val guard = LifecycleGuardedCallback(
            isActivityDestroyed = { false },
            isFinishing = { true },
        )

        guard.postError(result, "PROOF_GENERATION_FAILED", "timeout", null)

        verify(exactly = 0) { result.error(any(), any(), any()) }
    }

    @Test
    fun `result is dropped when both destroyed and finishing`() {
        val guard = LifecycleGuardedCallback(
            isActivityDestroyed = { true },
            isFinishing = { true },
        )

        guard.postResult(result, "proof_hash_123")
        guard.postError(result, "ERROR", "msg", null)

        verify(exactly = 0) { result.success(any()) }
        verify(exactly = 0) { result.error(any(), any(), any()) }
    }

    @Test
    fun `guard transitions from alive to destroyed mid-sequence`() {
        var destroyed = false
        val guard = LifecycleGuardedCallback(
            isActivityDestroyed = { destroyed },
            isFinishing = { false },
        )

        // First call succeeds (activity alive)
        guard.postResult(result, "first")
        verify(exactly = 1) { result.success("first") }

        // Activity destroyed between calls
        destroyed = true

        // Second call is dropped
        guard.postResult(result, "second")
        verify(exactly = 0) { result.success("second") }
    }

    @Test
    fun `back navigation invokes flutter method channel when activity stays alive`() {
        val channel = mockk<MethodChannel>()
        every { channel.invokeMethod("onBackPressed", null, any()) } answers {
            @Suppress("UNCHECKED_CAST")
            (args[2] as MethodChannel.Result).success(true)
        }

        var fallbackCount = 0

        dispatchBackPressToFlutter(
            channelProvider = { channel },
            isActivityDestroyed = { false },
            isFinishing = { false },
            onFallback = { fallbackCount++ },
        )

        verify(exactly = 1) { channel.invokeMethod("onBackPressed", null, any()) }
        assertEquals(0, fallbackCount)
    }

    @Test
    fun `back navigation skips invoke when lifecycle changes before invokeMethod`() {
        val channel = mockk<MethodChannel>(relaxed = true)
        var destroyedChecks = 0
        var fallbackCount = 0

        dispatchBackPressToFlutter(
            channelProvider = { channel },
            isActivityDestroyed = { destroyedChecks++ > 0 },
            isFinishing = { false },
            onFallback = { fallbackCount++ },
        )

        verify(exactly = 0) { channel.invokeMethod(any(), any(), any()) }
        assertEquals(1, fallbackCount)
    }

    @Test
    fun `back navigation falls back when invokeMethod throws after detach`() {
        val channel = mockk<MethodChannel>()
        every { channel.invokeMethod(any(), any(), any()) } throws RuntimeException(
            "Cannot execute operation because FlutterJNI is not attached to native",
        )

        var fallbackCount = 0

        dispatchBackPressToFlutter(
            channelProvider = { channel },
            isActivityDestroyed = { false },
            isFinishing = { false },
            onFallback = { fallbackCount++ },
        )

        verify(exactly = 1) { channel.invokeMethod("onBackPressed", null, any()) }
        assertEquals(1, fallbackCount)
    }
}
