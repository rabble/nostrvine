// ABOUTME: Robolectric coverage for TranscriptionSession's support gate.
// ABOUTME: Proves an unsupported recognizer never starts listening (no mic).

package co.openvine.caption_generator

import android.content.Intent
import android.os.Build
import android.os.ParcelFileDescriptor
import android.speech.RecognitionListener
import io.flutter.plugin.common.MethodChannel
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [Build.VERSION_CODES.UPSIDE_DOWN_CAKE])
internal class TranscriptionSessionTest {
    @Test
    fun start_whenSupported_startsListeningWithoutError() {
        val recognizer = FakeFileRecognizer(supported = true)
        val result = RecordingResult()
        val session = newSession(recognizer, result, locale = "en-US")

        session.start()

        // Support confirmed: the recognizer was wired up and told to listen.
        assertNotNull(recognizer.listener)
        assertEquals(1, recognizer.startListeningCount)
        assertFalse(recognizer.destroyed)
        // The session is now in flight; no result is delivered yet.
        assertEquals(0, result.errorCount)
        assertEquals(0, result.successCount)
    }

    @Test
    fun start_whenUnsupported_failsRecognizerUnavailableAndNeverListens() {
        val recognizer = FakeFileRecognizer(supported = false)
        val result = RecordingResult()
        val session = newSession(recognizer, result, locale = null)

        session.start()

        // Unsupported EXTRA_AUDIO_SOURCE intent: refuse instead of risking a
        // microphone fallback. Crucially, listening must never have started.
        assertEquals(0, recognizer.startListeningCount)
        assertTrue(recognizer.destroyed)
        assertEquals(1, result.errorCount)
        assertEquals("recognizer_unavailable", result.lastErrorCode)
        assertEquals(0, result.successCount)
    }

    private fun newSession(
        recognizer: FakeFileRecognizer,
        result: MethodChannel.Result,
        locale: String?,
    ): TranscriptionSession =
        TranscriptionSession(
            context = RuntimeEnvironment.getApplication(),
            wav = WavPcmInput.parse(writeMonoWav(samples = 16)),
            localeIdentifier = locale,
            result = result,
            recognizerFactory = { recognizer },
            pipeFactory = ::fileBackedPipe,
        )
}

/** A [FileRecognizer] whose support check answers a fixed [supported] verdict. */
private class FakeFileRecognizer(private val supported: Boolean) :
    FileRecognizer {
    var listener: RecognitionListener? = null
    var startListeningCount = 0
    var destroyed = false

    override fun setRecognitionListener(listener: RecognitionListener) {
        this.listener = listener
    }

    override fun checkRecognitionSupport(
        intent: Intent,
        onSupported: () -> Unit,
        onUnsupported: () -> Unit,
    ) {
        if (supported) onSupported() else onUnsupported()
    }

    override fun startListening(intent: Intent) {
        startListeningCount++
    }

    override fun destroy() {
        destroyed = true
    }
}

/** Records the single answer TranscriptionSession delivers to Flutter. */
private class RecordingResult : MethodChannel.Result {
    var successCount = 0
        private set
    var errorCount = 0
        private set
    var lastErrorCode: String? = null
        private set

    override fun success(result: Any?) {
        successCount += 1
    }

    override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
        errorCount += 1
        lastErrorCode = errorCode
    }

    override fun notImplemented() = Unit
}

/**
 * File-backed stand-in for [ParcelFileDescriptor.createPipe], so the session's
 * pipe plumbing is exercised without depending on real OS pipe support under
 * Robolectric.
 */
private fun fileBackedPipe(): Array<ParcelFileDescriptor> {
    fun open(): ParcelFileDescriptor {
        val file = File.createTempFile("cc_pipe", ".bin").apply { deleteOnExit() }
        return ParcelFileDescriptor.open(
            file,
            ParcelFileDescriptor.MODE_READ_WRITE,
        )
    }
    return arrayOf(open(), open())
}

private fun writeMonoWav(samples: Int): File {
    val dataSize = samples * 2
    val buffer = ByteBuffer.allocate(44 + dataSize).order(ByteOrder.LITTLE_ENDIAN)
    buffer.put("RIFF".toByteArray(Charsets.US_ASCII))
    buffer.putInt(36 + dataSize)
    buffer.put("WAVE".toByteArray(Charsets.US_ASCII))
    buffer.put("fmt ".toByteArray(Charsets.US_ASCII))
    buffer.putInt(16)
    buffer.putShort(1.toShort()) // PCM
    buffer.putShort(1.toShort()) // mono
    buffer.putInt(16000) // sample rate
    buffer.putInt(16000 * 2) // byte rate
    buffer.putShort(2.toShort()) // block align
    buffer.putShort(16.toShort()) // bits per sample
    buffer.put("data".toByteArray(Charsets.US_ASCII))
    buffer.putInt(dataSize)
    repeat(samples) { buffer.putShort(0.toShort()) }
    return File.createTempFile("cc_wav", ".wav").apply {
        deleteOnExit()
        writeBytes(buffer.array())
    }
}
