// ABOUTME: One SpeechRecognizer file-transcription run on Android 14+.
// ABOUTME: Pipes WAV PCM into EXTRA_AUDIO_SOURCE and collects word timings.

package co.openvine.caption_generator

import android.annotation.TargetApi
import android.content.Context
import android.content.Intent
import android.media.AudioFormat
import android.os.Build
import android.os.Bundle
import android.os.ParcelFileDescriptor
import android.speech.RecognitionListener
import android.speech.RecognitionPart
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import java.io.FileInputStream
import java.io.IOException

/**
 * Runs a single file transcription through the platform [SpeechRecognizer].
 *
 * The WAV's PCM payload is streamed through a pipe handed to the recognizer
 * via [RecognizerIntent.EXTRA_AUDIO_SOURCE]; per the platform contract the
 * session ends when the write side of the pipe is closed. Word timing is
 * requested with [RecognizerIntent.EXTRA_REQUEST_WORD_TIMING] and read from
 * [RecognitionPart.getTimestampMillis]. Parts only carry start offsets, so a
 * word's end time is approximated by the next word's start (the audio's end
 * for the last word).
 *
 * Must be constructed and started on the main thread; recognizer callbacks
 * then also arrive on the main thread.
 */
@TargetApi(Build.VERSION_CODES.UPSIDE_DOWN_CAKE)
internal class TranscriptionSession(
    private val context: Context,
    private val wav: WavPcmInput,
    private val localeIdentifier: String?,
    private val result: io.flutter.plugin.common.MethodChannel.Result,
) : RecognitionListener {

    private var recognizer: SpeechRecognizer? = null
    private var sourceFd: ParcelFileDescriptor? = null

    /** Collected (text, startMs) pairs; end times are derived in [finish]. */
    private val words = mutableListOf<Pair<String, Long>>()
    private var completed = false

    /** Total audio duration, used as the end time of the last word. */
    private val audioDurationMs: Long =
        wav.dataLength * 1000 / (2L * wav.sampleRate)

    fun start() {
        val pipe = ParcelFileDescriptor.createPipe()
        sourceFd = pipe[0]
        startAudioWriter(pipe[1])
        val recognizer = SpeechRecognizer.createOnDeviceSpeechRecognizer(context)
        this.recognizer = recognizer
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(
                RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM,
            )
            localeIdentifier?.let { putExtra(RecognizerIntent.EXTRA_LANGUAGE, it) }
            putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE, pipe[0])
            putExtra(
                RecognizerIntent.EXTRA_AUDIO_SOURCE_ENCODING,
                AudioFormat.ENCODING_PCM_16BIT,
            )
            putExtra(
                RecognizerIntent.EXTRA_AUDIO_SOURCE_SAMPLING_RATE,
                wav.sampleRate,
            )
            putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_CHANNEL_COUNT, 1)
            putExtra(RecognizerIntent.EXTRA_REQUEST_WORD_TIMING, true)
            putExtra(
                RecognizerIntent.EXTRA_SEGMENTED_SESSION,
                RecognizerIntent.EXTRA_AUDIO_SOURCE,
            )
        }
        recognizer.setRecognitionListener(this)
        recognizer.startListening(intent)
    }

    /**
     * Streams the WAV's data chunk into the recognizer's pipe off the main
     * thread, then closes it, which is what ends the recognition session.
     */
    private fun startAudioWriter(writeFd: ParcelFileDescriptor) {
        Thread(
            {
                try {
                    ParcelFileDescriptor.AutoCloseOutputStream(writeFd).use { out ->
                        FileInputStream(wav.file).use { input ->
                            var toSkip = wav.dataOffset
                            while (toSkip > 0) {
                                val skipped = input.skip(toSkip)
                                if (skipped <= 0) break
                                toSkip -= skipped
                            }
                            val buffer = ByteArray(CHUNK_SIZE)
                            var remaining = wav.dataLength
                            while (remaining > 0) {
                                val toRead =
                                    minOf(remaining, buffer.size.toLong()).toInt()
                                val read = input.read(buffer, 0, toRead)
                                if (read <= 0) break
                                out.write(buffer, 0, read)
                                remaining -= read
                            }
                        }
                    }
                } catch (_: IOException) {
                    // The recognizer closed its end early; the session outcome
                    // still arrives through the listener callbacks.
                }
            },
            "caption-generator-audio",
        ).start()
    }

    // Intentional no-ops: these listener callbacks describe live-microphone
    // UX (speech onset, volume) that has no meaning for file transcription.
    override fun onReadyForSpeech(params: Bundle?) = Unit

    override fun onBeginningOfSpeech() = Unit

    override fun onRmsChanged(rmsdB: Float) = Unit

    override fun onBufferReceived(buffer: ByteArray?) = Unit

    override fun onEndOfSpeech() = Unit

    override fun onPartialResults(partialResults: Bundle?) = Unit

    override fun onEvent(eventType: Int, params: Bundle?) = Unit

    override fun onResults(results: Bundle?) {
        results?.let(::collect)
        finish()
    }

    override fun onSegmentResults(segmentResults: Bundle) {
        collect(segmentResults)
    }

    override fun onEndOfSegmentedSession() {
        finish()
    }

    override fun onError(error: Int) {
        when (error) {
            // Silence is a valid empty transcription, not a failure.
            SpeechRecognizer.ERROR_NO_MATCH,
            SpeechRecognizer.ERROR_SPEECH_TIMEOUT,
            -> finish()
            SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> fail(
                "not_authorized",
                "Speech recognition permission was denied",
            )
            SpeechRecognizer.ERROR_LANGUAGE_NOT_SUPPORTED,
            SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE,
            -> fail(
                "recognizer_unavailable",
                "The requested language is not available on this device",
            )
            else -> fail(
                "transcription_failed",
                "SpeechRecognizer failed with error code $error",
            )
        }
    }

    private fun collect(bundle: Bundle) {
        val parts = bundle.getParcelableArrayList(
            SpeechRecognizer.RECOGNITION_PARTS,
            RecognitionPart::class.java,
        )
        if (!parts.isNullOrEmpty()) {
            for (part in parts) {
                val text = part.formattedText ?: part.rawText
                if (text.isNotBlank()) {
                    words.add(text to part.timestampMillis.toLong())
                }
            }
            return
        }
        // Recognizer provided no word parts — fall back to one segment
        // spanning the whole audio so callers still get usable text.
        val text = bundle
            .getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
            ?.firstOrNull()
            ?.trim()
            .orEmpty()
        if (text.isNotEmpty()) {
            words.add(text to 0L)
        }
    }

    private fun finish() {
        if (completed) return
        completed = true
        cleanup()
        result.success(buildSegments())
    }

    private fun fail(code: String, message: String) {
        if (completed) return
        completed = true
        cleanup()
        result.error(code, message, null)
    }

    private fun cleanup() {
        recognizer?.destroy()
        recognizer = null
        try {
            sourceFd?.close()
        } catch (_: IOException) {
            // Already closed by the recognizer; nothing left to release.
        }
        sourceFd = null
    }

    private fun buildSegments(): List<Map<String, Any>> =
        words.mapIndexed { index, (text, startMs) ->
            val endMs = words.getOrNull(index + 1)?.second ?: audioDurationMs
            mapOf(
                "text" to text,
                "startMs" to startMs,
                "endMs" to maxOf(endMs, startMs),
            )
        }

    private companion object {
        const val CHUNK_SIZE = 8192
    }
}
