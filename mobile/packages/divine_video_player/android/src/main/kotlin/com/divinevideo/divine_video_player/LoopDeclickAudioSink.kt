package com.divinevideo.divine_video_player

import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.audio.AudioSink
import androidx.media3.exoplayer.audio.ForwardingAudioSink

/**
 * Tells [LoopDeclickAudioProcessor] where a looping video restarts.
 *
 * A seamless loop does not flush the audio pipeline, so the processor's frame
 * counter would run straight through the join and never fade again. The one
 * signal that does reach the audio path is the stream change ExoPlayer reports
 * when it moves from one media period to the next — including the repeat of a
 * single item under `REPEAT_MODE_ALL`.
 *
 * `MediaCodecRenderer` raises it from `onProcessedOutputBuffer` *after* the
 * last buffer of the finished stream has been handed to the sink and *before*
 * the first buffer of the next one, so the anchor lands exactly on the join.
 */
@UnstableApi
internal class LoopDeclickAudioSink(
    sink: AudioSink,
    private val processor: LoopDeclickAudioProcessor,
) : ForwardingAudioSink(sink) {

    override fun handleDiscontinuity() {
        processor.onStreamChanged()
        super.handleDiscontinuity()
    }
}
