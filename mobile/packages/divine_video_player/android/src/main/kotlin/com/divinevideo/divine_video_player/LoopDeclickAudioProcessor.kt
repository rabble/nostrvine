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
 * The two edges are found in opposite ways.
 *
 * The start is a counting problem. ExoPlayer gives an [AudioProcessor] no
 * position of its own — `StreamMetadata`'s `positionOffsetUs` is 0 on every
 * playback-path flush in media3 1.10 — so the first frames of a stream are
 * counted from the flush, with [LoopDeclickAudioSink] retiring the seek offset
 * at the join so a seek does not fade in mid-video.
 *
 * The end cannot be counted towards, because nothing on this side of the
 * pipeline knows where it is until it arrives: `player.duration` is the
 * container's, in whole milliseconds, and the decoded audio track ends up to
 * an AAC frame away from it — wider than the fade itself. So the last
 * [FADE_US] of audio is held back instead, and released faded once media3
 * signals the end of the stream. That signal is exact and arrives at every
 * loop restart: `handleDiscontinuity` sets `startMediaTimeUsNeedsSync`, and
 * the next buffer makes `DefaultAudioSink` run `drainToEndOfStream()`, which
 * queues end-of-stream into the pipeline before any frame of the new lap is.
 * `TrimmingAudioProcessor` holds its own tail back the same way, one slot
 * upstream in this same chain.
 *
 * The cost is that audio runs [FADE_US] behind the position the player
 * reports. Ten milliseconds is an order of magnitude inside the threshold
 * where a viewer notices audio trailing video.
 *
 * Configuration is written from the main thread and read on the playback
 * thread, hence the volatile fields.
 */
@UnstableApi
internal class LoopDeclickAudioProcessor : BaseAudioProcessor() {

    /**
     * Length of the video in microseconds, or [DURATION_UNKNOWN] while it is
     * not known.
     *
     * It only bounds how long the fade may be, never where it sits — a video
     * shorter than two fades gets shorter ones. Being wrong here costs a
     * couple of milliseconds of ramp on a video no longer than that, which is
     * why the container's millisecond figure is good enough for it and was
     * never good enough to place the fade out.
     */
    @Volatile
    var videoDurationUs: Long = DURATION_UNKNOWN

    /**
     * Whether to fade at all. Off for multi-clip timelines, where a stream is
     * one clip of the video rather than the whole of it, so fading every
     * stream would notch the audio at each cut. Off also holds nothing back,
     * so those players keep their audio latency.
     */
    @Volatile
    var enabled: Boolean = false

    /**
     * Media position the next stream starts at, in microseconds. Set before an
     * explicit seek so the fade in stays anchored to the video rather than to
     * the seek target.
     *
     * It has to survive a flush rather than be consumed by one: media3 flushes
     * the pipeline twice per seek before a single frame is queued — once from
     * `DefaultAudioSink.flush()`, which then releases the audio output, and
     * again when the next buffer re-initialises it. A one-shot value would be
     * eaten by the first and the second would re-anchor at zero. It is cleared
     * at the loop join instead, in [onStreamChanged], which is where the seek
     * offset genuinely stops applying.
     */
    @Volatile
    var nextStreamStartUs: Long = 0

    /** Frames read since the last flush. */
    private var readFrames: Long = 0

    /** Value of [readFrames] at the start of the current video. */
    private var anchorFrames: Long = 0

    /**
     * Whether any input arrived since the last anchor. Guards against the
     * decode-only buffers a seek discards, which `MediaCodecAudioRenderer`
     * reports as a discontinuity each without ever reaching [queueInput].
     */
    private var sawInputSinceAnchor: Boolean = false

    /**
     * The most recent frames, interleaved, held back so they are still here to
     * be faded when the stream turns out to have ended. Empty while the fade
     * is off, which is what keeps those players at zero added latency.
     */
    private var tail: ShortArray = ShortArray(0)
    private var tailCapacityFrames: Int = 0
    private var tailFrames: Int = 0

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

    /** Re-arms the fade in at the start of the next stream (a loop restart). */
    fun onStreamChanged() {
        // A seek discards the buffers before its target and reports each one
        // as a discontinuity. Those are not loop restarts, and retiring the
        // seek offset on one would fade in at the seek target.
        if (!sawInputSinceAnchor) {
            return
        }
        anchorFrames = readFrames
        nextStreamStartUs = 0
        sawInputSinceAnchor = false
    }

    override fun onFlush(streamMetadata: AudioProcessor.StreamMetadata) {
        // streamMetadata.positionOffsetUs is always 0 on the playback path in
        // media3 1.10 — DefaultAudioSink flushes the pipeline without one — so
        // the start position comes from [nextStreamStartUs] instead. It stays
        // set: a seek flushes twice before the first frame arrives.
        readFrames = 0
        val sampleRate = inputAudioFormat.sampleRate
        anchorFrames = if (sampleRate > 0) {
            -durationUsToFrames(nextStreamStartUs, sampleRate)
        } else {
            0
        }
        sawInputSinceAnchor = false

        // Whatever is held back belongs to a stream that is not going to end
        // where it was about to.
        tailFrames = 0
        tailCapacityFrames = if (enabled && sampleRate > 0) {
            durationUsToFrames(FADE_US, sampleRate).toInt()
        } else {
            0
        }
        val samples = tailCapacityFrames * inputAudioFormat.channelCount
        if (tail.size != samples) {
            tail = ShortArray(samples)
        }
    }

    override fun onReset() {
        readFrames = 0
        anchorFrames = 0
        nextStreamStartUs = 0
        sawInputSinceAnchor = false
        tail = ShortArray(0)
        tailCapacityFrames = 0
        tailFrames = 0
    }

    override fun queueInput(inputBuffer: ByteBuffer) {
        val position = inputBuffer.position()
        val limit = inputBuffer.limit()
        val byteCount = limit - position
        if (byteCount <= 0) {
            return
        }
        sawInputSinceAnchor = true

        val bytesPerFrame = inputAudioFormat.bytesPerFrame
        val frameCount = byteCount / bytesPerFrame
        if (tailCapacityFrames <= 0) {
            val output = replaceOutputBuffer(byteCount)
            output.put(inputBuffer)
            readFrames += frameCount
            output.flip()
            return
        }

        val channelCount = inputAudioFormat.channelCount
        val fadeFrames = fadeFrames(inputAudioFormat.sampleRate)
        // Keep the tail as full as it holds; everything older than that leaves
        // now, oldest first.
        val emitFrames = (tailFrames + frameCount - tailCapacityFrames).coerceAtLeast(0)
        val output = replaceOutputBuffer(emitFrames * bytesPerFrame)

        val fromTail = minOf(emitFrames, tailFrames)
        for (sample in 0 until fromTail * channelCount) {
            output.putShort(tail[sample])
        }
        tail.copyInto(tail, 0, fromTail * channelCount, tailFrames * channelCount)
        tailFrames -= fromTail

        // The fade in is applied as frames arrive, so a frame still in the
        // tail when the stream ends carries both ramps.
        val fromInput = emitFrames - fromTail
        for (frame in 0 until frameCount) {
            val gain = fadeInGainAt(readFrames + frame - anchorFrames, fadeFrames)
            for (channel in 0 until channelCount) {
                val raw = inputBuffer.getShort(position + (frame * channelCount + channel) * 2)
                val faded = if (gain >= 1f) raw else (raw * gain).toInt().toShort()
                if (frame < fromInput) {
                    output.putShort(faded)
                } else {
                    tail[(tailFrames + frame - fromInput) * channelCount + channel] = faded
                }
            }
        }
        tailFrames += frameCount - fromInput

        readFrames += frameCount
        inputBuffer.position(limit)
        output.flip()
    }

    /**
     * Releases the held-back tail, faded out, once media3 reports the stream
     * has ended — which at a loop restart is the join itself.
     */
    override fun getOutput(): ByteBuffer {
        if (super.isEnded() && tailFrames > 0) {
            val channelCount = inputAudioFormat.channelCount
            val ramp = minOf(tailFrames.toLong(), fadeFrames(inputAudioFormat.sampleRate)).toInt()
            val output = replaceOutputBuffer(tailFrames * inputAudioFormat.bytesPerFrame)
            for (frame in 0 until tailFrames) {
                // Distance from the last frame, so the last one reaches zero.
                val remaining = tailFrames - 1 - frame
                val gain = if (ramp <= 0 || remaining >= ramp) 1f else remaining.toFloat() / ramp
                for (channel in 0 until channelCount) {
                    val held = tail[frame * channelCount + channel]
                    output.putShort(if (gain >= 1f) held else (held * gain).toInt().toShort())
                }
            }
            output.flip()
            tailFrames = 0
        }
        return super.getOutput()
    }

    override fun isEnded(): Boolean = super.isEnded() && tailFrames == 0

    /**
     * Gain to apply [frame] frames into the video, in `[0f, 1f]`.
     *
     * Only the way in — the way out is the tail, which needs no position.
     *
     * Visible for testing: the shape of the fade is worth pinning on its own,
     * separately from where the anchor bookkeeping decides to put it.
     */
    internal fun fadeInGainAt(frame: Long, fadeFrames: Long): Float {
        if (fadeFrames <= 0 || frame < 0 || frame >= fadeFrames) {
            return 1f
        }
        return frame.toFloat() / fadeFrames
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
        val durationUs = videoDurationUs
        if (durationUs <= 0) {
            return fade
        }
        return minOf(fade, durationUsToFrames(durationUs, sampleRate) / 2)
    }

    private fun durationUsToFrames(durationUs: Long, sampleRate: Int): Long =
        durationUs * sampleRate / 1_000_000L

    companion object {
        /** Sentinel for "the video's length is not known yet". */
        const val DURATION_UNKNOWN = -1L

        /**
         * Length of each fade, and therefore also how far this processor puts
         * audio behind the reported position. Long enough to remove the step
         * even on low-frequency content, short enough not to read as a level
         * change or to be noticed as audio trailing video.
         *
         * Deliberately shorter than the Apple player's
         * `edgeDeclickFadeSeconds`. A fade here is applied to decoded frames
         * and lands exactly where it is asked to; AVFoundation's volume ramps
         * are stretched to a floor of about 25 ms, so that side has to spend
         * 30 ms to reach silence at all.
         */
        const val FADE_US = 10_000L
    }
}
