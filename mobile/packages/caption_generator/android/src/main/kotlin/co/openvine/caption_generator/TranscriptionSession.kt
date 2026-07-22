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
import android.speech.RecognitionSupport
import android.speech.RecognitionSupportCallback
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import java.io.FileInputStream
import java.io.IOException

/**
 * The recognizer operations [TranscriptionSession] needs, behind an interface
 * so tests can drive the support-check callbacks without the platform
 * [SpeechRecognizer].
 */
internal interface FileRecognizer {
    fun setRecognitionListener(listener: RecognitionListener)

    /**
     * Checks whether the installed recognizer supports [intent] (a complete
     * file-audio-source recognition request), invoking [onSupported] or
     * [onUnsupported] on the main thread.
     */
    fun checkRecognitionSupport(
        intent: Intent,
        onSupported: () -> Unit,
        onUnsupported: () -> Unit,
    )

    fun startListening(intent: Intent)

    fun destroy()
}

/** [FileRecognizer] backed by the platform on-device [SpeechRecognizer]. */
@TargetApi(Build.VERSION_CODES.UPSIDE_DOWN_CAKE)
internal class PlatformFileRecognizer(context: Context) : FileRecognizer {
    private val recognizer =
        SpeechRecognizer.createOnDeviceSpeechRecognizer(context)
    private val mainExecutor = context.mainExecutor

    override fun setRecognitionListener(listener: RecognitionListener) =
        recognizer.setRecognitionListener(listener)

    override fun checkRecognitionSupport(
        intent: Intent,
        onSupported: () -> Unit,
        onUnsupported: () -> Unit,
    ) {
        recognizer.checkRecognitionSupport(
            intent,
            mainExecutor,
            object : RecognitionSupportCallback {
                override fun onSupportResult(recognitionSupport: RecognitionSupport) {
                    onSupported()
                }

                override fun onError(error: Int) {
                    onUnsupported()
                }
            },
        )
    }

    override fun startListening(intent: Intent) =
        recognizer.startListening(intent)

    override fun destroy() = recognizer.destroy()
}

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
 * Before starting, the recognizer is asked whether it supports the complete
 * file-audio-source intent. Only on success is the audio writer started and
 * [SpeechRecognizer.startListening] called; otherwise the session fails with
 * `recognizer_unavailable` rather than risk a recognizer that ignores
 * [RecognizerIntent.EXTRA_AUDIO_SOURCE] falling back to the microphone and
 * capturing ambient speech.
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
    private val recognizerFactory: (Context) -> FileRecognizer =
        ::PlatformFileRecognizer,
    private val pipeFactory: () -> Array<ParcelFileDescriptor> = {
        ParcelFileDescriptor.createPipe()
    },
) : RecognitionListener {

    private var recognizer: FileRecognizer? = null
    private var sourceFd: ParcelFileDescriptor? = null
    private var sinkFd: ParcelFileDescriptor? = null

    /** Collected (text, startMs) pairs; end times are derived in [finish]. */
    private val words = mutableListOf<Pair<String, Long>>()
    private var completed = false

    /** Total audio duration, used as the end time of the last word. */
    private val audioDurationMs: Long =
        wav.dataLength * 1000 / (2L * wav.sampleRate)

    fun start() {
        try {
            val recognizer = recognizerFactory(context)
            this.recognizer = recognizer
            val pipe = pipeFactory()
            sourceFd = pipe[0]
            sinkFd = pipe[1]
            val intent = buildIntent(pipe[0])
            recognizer.setRecognitionListener(this)
            // Gate on support: an unsupported EXTRA_AUDIO_SOURCE intent can
            // make some recognizers open the microphone instead of the file.
            recognizer.checkRecognitionSupport(
                intent,
                onSupported = { onRecognitionSupported(intent) },
                onUnsupported = ::onRecognitionUnsupported,
            )
        } catch (e: Exception) {
            // A throw after the pipe is created would otherwise leak it and the
            // recognizer: cleanup() only runs via listener callbacks that never
            // fire here. fail() closes both pipe ends, destroys the recognizer,
            // and delivers a single error result.
            fail(
                "transcription_failed",
                "Failed to start transcription: ${e.message}",
            )
        }
    }

    private fun onRecognitionSupported(intent: Intent) {
        val sink = sinkFd ?: return
        // The audio writer takes ownership of the write end from here; clear
        // our handle so cleanup() does not double-close it.
        sinkFd = null
        try {
            startAudioWriter(sink)
            recognizer?.startListening(intent)
        } catch (e: Exception) {
            // This support callback runs after start() returns, so a throw
            // here escapes start()'s try. Deliver a single error result and
            // release the recognizer and the read end of the pipe.
            fail(
                "transcription_failed",
                "Failed to start transcription: ${e.message}",
            )
        }
    }

    private fun onRecognitionUnsupported() {
        fail(
            "recognizer_unavailable",
            "On-device recognizer does not support file audio input",
        )
    }

    private fun buildIntent(source: ParcelFileDescriptor): Intent =
        Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(
                RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM,
            )
            localeIdentifier?.let {
                putExtra(RecognizerIntent.EXTRA_LANGUAGE, it)
            }
            putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE, source)
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
            // Punctuation + casing via RecognitionPart.formattedText, so the
            // Dart cue grouper can split at sentence boundaries.
            putExtra(
                RecognizerIntent.EXTRA_ENABLE_FORMATTING,
                RecognizerIntent.FORMATTING_OPTIMIZE_QUALITY,
            )
            putExtra(
                RecognizerIntent.EXTRA_SEGMENTED_SESSION,
                RecognizerIntent.EXTRA_AUDIO_SOURCE,
            )
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
        closeQuietly(sourceFd)
        sourceFd = null
        closeQuietly(sinkFd)
        sinkFd = null
    }

    private fun closeQuietly(fd: ParcelFileDescriptor?) {
        try {
            fd?.close()
        } catch (_: IOException) {
            // Already closed by the recognizer or writer; nothing to release.
        }
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
