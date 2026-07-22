// ABOUTME: Android caption generator backed by the platform SpeechRecognizer.
// ABOUTME: Feeds WAV PCM through EXTRA_AUDIO_SOURCE and maps word timings.

package co.openvine.caption_generator

import android.content.Context
import android.os.Build
import android.speech.SpeechRecognizer
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Flutter plugin entry point for on-device speech-to-text on Android.
 *
 * Uses the platform [SpeechRecognizer] with an audio-source file descriptor
 * (Android 13+) and word timing via `RecognitionPart` (Android 14+), so file
 * transcription requires Android 14 and a device with Google's on-device
 * recognition service. Older or de-Googled devices report
 * `recognizer_unavailable`.
 */
class CaptionGeneratorPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private lateinit var channel: MethodChannel
    private lateinit var appContext: Context

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "transcribe") {
            result.notImplemented()
            return
        }
        val audioPath = call.argument<String>("audioPath")
        if (audioPath.isNullOrEmpty()) {
            result.error("invalid_arguments", "audioPath is required", null)
            return
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            result.error(
                "recognizer_unavailable",
                "File transcription requires Android 14 or newer",
                null,
            )
            return
        }
        if (!SpeechRecognizer.isOnDeviceRecognitionAvailable(appContext)) {
            result.error(
                "recognizer_unavailable",
                "No on-device speech recognition service is available",
                null,
            )
            return
        }
        val audioFile = File(audioPath)
        if (!audioFile.exists()) {
            result.error(
                "audio_not_found",
                "Audio file not found: $audioPath",
                null,
            )
            return
        }
        try {
            val wav = WavPcmInput.parse(audioFile)
            TranscriptionSession(
                context = appContext,
                wav = wav,
                localeIdentifier = call.argument<String>("localeIdentifier"),
                result = result,
            ).start()
        } catch (e: TranscriptionException) {
            result.error(e.code, e.message, null)
        }
    }

    companion object {
        private const val CHANNEL_NAME = "caption_generator"
    }
}
