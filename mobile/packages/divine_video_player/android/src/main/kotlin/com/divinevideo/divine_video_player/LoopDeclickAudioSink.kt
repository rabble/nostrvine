package com.divinevideo.divine_video_player

import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.audio.AudioSink
import androidx.media3.exoplayer.audio.ForwardingAudioSink

/**
 * Tells [LoopDeclickAudioProcessor] where a looping video restarts.
 *
 * The only signal a seamless loop sends the audio path is the stream change
 * ExoPlayer reports when it moves from one media period to the next —
 * including the repeat of a single item under `REPEAT_MODE_ALL`.
 * `MediaCodecAudioRenderer` raises it from `onProcessedStreamChange` *after*
 * the last buffer of the finished stream has been handed to the sink and
 * *before* the first buffer of the next one, so the anchor lands exactly on
 * the join.
 *
 * In media3 1.10 the sink then flushes the pipeline itself before that first
 * buffer — `handleDiscontinuity` sets `startMediaTimeUsNeedsSync`, and the
 * resync drains and re-runs `setupAudioProcessors` — which happens to reset
 * the frame counter to the same place. Two jobs are still left that the flush
 * cannot do, and both are load-bearing: it is the only point that can tell a
 * loop restart from a seek, so it is where the seek offset is retired and
 * where the true length of the loop that just played is measured.
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
