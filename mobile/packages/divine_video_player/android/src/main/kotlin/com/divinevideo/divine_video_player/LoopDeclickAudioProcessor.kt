package com.divinevideo.divine_video_player

import androidx.media3.common.C
import androidx.media3.common.audio.AudioProcessor
import androidx.media3.common.audio.BaseAudioProcessor
import androidx.media3.common.util.UnstableApi
import java.nio.ByteBuffer

/**
 * Fades the first and last few milliseconds of a looping video's audio so the
 * loop restart is not audible as a click (#6468).
 *
 * `REPEAT_MODE_ALL` cuts from the video's last sample straight back to its
 * first. That cut has never been tied to a zero crossing — it comes from a
 * trim or a recording length — so unless both edges happen to sit near silence
 * the step is a click. Fading both edges to zero makes the join
 * silence-to-silence.
 *
 * ExoPlayer gives an [AudioProcessor] no position of its own: the playback
 * pipeline is flushed on seek and reconfiguration but never at a seamless loop
 * restart, and `StreamMetadata.positionOffsetUs` is always 0 on this path in
 * media3 1.10. The frame counter is therefore anchored from outside by
 * [LoopDeclickAudioSink], which runs on the same playback thread and sees the
 * stream change a loop restart produces.
 *
 * Configuration is written from the main thread and read on the playback
 * thread, hence the volatile fields.
 */
@UnstableApi
internal class LoopDeclickAudioProcessor : BaseAudioProcessor() {

    /**
     * Length of the video in microseconds, or [DURATION_UNKNOWN] while it is
     * not known. Only a video whose end is known can be faded out.
     */
    @Volatile
    var videoDurationUs: Long = DURATION_UNKNOWN

    /**
     * Whether to fade at all. Off for multi-clip timelines, where a stream is
     * one clip of the video rather than the whole of it, so fading every
     * stream would notch the audio at each cut.
     */
    @Volatile
    var enabled: Boolean = false

    /**
     * Media position the next stream starts at, in microseconds. Set before an
     * explicit seek so the fade stays anchored to the video rather than to the
     * seek target; consumed by the flush that seek triggers.
     */
    @Volatile
    var nextStreamStartUs: Long = 0

    /** Frames read since the last flush. */
    private var readFrames: Long = 0

    /** Value of [readFrames] at the start of the current video. */
    private var anchorFrames: Long = 0

    /**
     * Whether any input arrived since the last anchor. Guards against the
     * decode-only buffers a seek discards, which report a discontinuity
     * without ever reaching [queueInput].
     */
    private var sawInputSinceAnchor: Boolean = false

    override fun onConfigure(
        inputAudioFormat: AudioProcessor.AudioFormat,
    ): AudioProcessor.AudioFormat {
        // Everything upstream is converted to 16-bit PCM before reaching here.
        // If some path ever delivers anything else, drop out of the chain
        // rather than failing playback for the sake of a fade.
        if (inputAudioFormat.encoding != C.ENCODING_PCM_16BIT) {
            return AudioProcessor.AudioFormat.NOT_SET
        }
        return inputAudioFormat
    }

    /** Anchors the next stream at the start of the video (a loop restart). */
    fun onStreamChanged() {
        // A seek discards the buffers before its target and reports each one
        // as a discontinuity. Those are not loop restarts.
        if (!sawInputSinceAnchor) {
            return
        }
        anchorFrames = readFrames
        sawInputSinceAnchor = false
    }

    override fun onFlush(streamMetadata: AudioProcessor.StreamMetadata) {
        // streamMetadata.positionOffsetUs is always 0 on the playback path in
        // media3 1.10 — DefaultAudioSink flushes the pipeline without one — so
        // the start position comes from [nextStreamStartUs] instead.
        readFrames = 0
        val sampleRate = inputAudioFormat.sampleRate
        anchorFrames = if (sampleRate > 0) {
            -durationUsToFrames(nextStreamStartUs, sampleRate)
        } else {
            0
        }
        nextStreamStartUs = 0
        sawInputSinceAnchor = false
    }

    override fun onReset() {
        readFrames = 0
        anchorFrames = 0
        nextStreamStartUs = 0
        sawInputSinceAnchor = false
    }

    override fun queueInput(inputBuffer: ByteBuffer) {
        val position = inputBuffer.position()
        val limit = inputBuffer.limit()
        val byteCount = limit - position
        if (byteCount <= 0) {
            return
        }
        sawInputSinceAnchor = true

        val sampleRate = inputAudioFormat.sampleRate
        val fadeFrames = fadeFrames(sampleRate)
        val output = replaceOutputBuffer(byteCount)
        if (fadeFrames <= 0) {
            output.put(inputBuffer)
            readFrames += byteCount / inputAudioFormat.bytesPerFrame
            output.flip()
            return
        }

        val channelCount = inputAudioFormat.channelCount
        val frameCount = byteCount / inputAudioFormat.bytesPerFrame
        val durationFrames = durationFrames(sampleRate)
        for (frame in 0 until frameCount) {
            val gain = gainAt(readFrames + frame - anchorFrames, fadeFrames, durationFrames)
            for (channel in 0 until channelCount) {
                val sample = inputBuffer.getShort(position + (frame * channelCount + channel) * 2)
                output.putShort(if (gain >= 1f) sample else (sample * gain).toInt().toShort())
            }
        }

        readFrames += frameCount
        inputBuffer.position(limit)
        output.flip()
    }

    /**
     * Gain to apply [frame] frames into the video, in `[0f, 1f]`.
     *
     * Visible for testing: this is the whole of the fade's behaviour, and the
     * buffer plumbing around it is not worth driving to reach it.
     */
    internal fun gainAt(frame: Long, fadeFrames: Long, durationFrames: Long): Float {
        if (fadeFrames <= 0 || frame < 0) {
            return 1f
        }
        // Wrap rather than run off the end. A stream change that never arrives
        // would otherwise leave the position past the end of the video for
        // good, and clamping there would silence the rest of playback. Wrapping
        // degrades to a fade that drifts instead of one that mutes.
        val position = if (durationFrames > 0) frame % durationFrames else frame
        if (position < fadeFrames) {
            return position.toFloat() / fadeFrames
        }
        if (durationFrames <= 0) {
            // The end is unknown, so only the start can be faded.
            return 1f
        }
        val framesLeft = durationFrames - position
        if (framesLeft < fadeFrames) {
            return framesLeft.toFloat() / fadeFrames
        }
        return 1f
    }

    /**
     * Fade length in frames, capped at half the video so the two fades of a
     * very short video cannot overlap.
     */
    internal fun fadeFrames(sampleRate: Int): Long {
        if (!enabled || sampleRate <= 0) {
            return 0
        }
        val fade = durationUsToFrames(FADE_US, sampleRate)
        val durationFrames = durationFrames(sampleRate)
        if (durationFrames <= 0) {
            return fade
        }
        return minOf(fade, durationFrames / 2)
    }

    private fun durationFrames(sampleRate: Int): Long {
        val durationUs = videoDurationUs
        if (durationUs <= 0) {
            return 0
        }
        return durationUsToFrames(durationUs, sampleRate)
    }

    private fun durationUsToFrames(durationUs: Long, sampleRate: Int): Long =
        durationUs * sampleRate / 1_000_000L

    companion object {
        /** Sentinel for "the video's length is not known yet". */
        const val DURATION_UNKNOWN = -1L

        /**
         * Length of each fade. Long enough to remove the step even on
         * low-frequency content, short enough not to read as a level change.
         * Matches the Apple player's `edgeDeclickFadeSeconds`.
         */
        const val FADE_US = 10_000L
    }
}
