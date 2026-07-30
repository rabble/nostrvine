package com.divinevideo.divine_video_player

import android.content.Context
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.audio.AudioSink
import androidx.media3.exoplayer.audio.DefaultAudioSink

/**
 * Builds the audio path with the loop declick fade in it (#6468).
 *
 * The processor has to be injected at construction because
 * `DefaultAudioSink`'s processor chain is fixed once the sink is built, and
 * the sink is wrapped so the processor is told where a loop restarts.
 */
@UnstableApi
internal class LoopDeclickRenderersFactory(
    context: Context,
    private val declickProcessor: LoopDeclickAudioProcessor,
) : DefaultRenderersFactory(context) {

    override fun buildAudioSink(
        context: Context,
        enableFloatOutput: Boolean,
        enableAudioTrackPlaybackParams: Boolean,
    ): AudioSink {
        // Float output routes around the user processor chain entirely, so the
        // fade would silently do nothing. Divine decodes AAC to 16-bit PCM, and
        // float output is off by default; keep it off explicitly rather than
        // let a future default flip disable the fade without a trace.
        val sink = DefaultAudioSink.Builder(context)
            .setEnableFloatOutput(false)
            .setEnableAudioOutputPlaybackParameters(enableAudioTrackPlaybackParams)
            .setAudioProcessors(arrayOf(declickProcessor))
            .build()
        return LoopDeclickAudioSink(sink, declickProcessor)
    }
}
