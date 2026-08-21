package com.divinevideo.divine_video_player

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import io.flutter.FlutterInjector

/**
 * Loops raw PCM through an [AudioTrack] in static mode.
 *
 * ExoPlayer costs ~70ms of stall per loop as soon as the media item carries an
 * audio track — measured identically with AAC and with PCM, so it is the audio
 * sink being torn down and rebuilt at the media period transition, not the
 * decoder. Taking audio out of the player sidesteps that entirely.
 *
 * A static [AudioTrack] holds the whole clip in its own buffer and repeats it
 * via [AudioTrack.setLoopPoints], which wraps sample-exact in the audio HAL.
 * There is no seam to stall at.
 *
 * The tradeoff is that video and audio now run on two independent clocks. They
 * are started together and have identical nominal periods, but nothing keeps
 * them locked, so long sessions can drift.
 */
class PrototypePcmLoopTrack(
    context: Context,
    assetPath: String,
    private val sampleRate: Int = 44100,
) {
    private val track: AudioTrack?

    init {
        track = runCatching {
            val key = FlutterInjector.instance().flutterLoader().getLookupKeyForAsset(assetPath)
            val pcm = context.assets.open(key).use { it.readBytes() }

            AudioTrack.Builder()
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MOVIE)
                        .build()
                )
                .setAudioFormat(
                    AudioFormat.Builder()
                        .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                        .setSampleRate(sampleRate)
                        .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                        .build()
                )
                .setBufferSizeInBytes(pcm.size)
                .setTransferMode(AudioTrack.MODE_STATIC)
                .build()
                .apply {
                    write(pcm, 0, pcm.size)
                    // -1 loops forever. Frame count, not byte count.
                    setLoopPoints(0, pcm.size / 2, -1)
                }
        }.getOrNull()
    }

    fun play(muted: Boolean) {
        val track = track ?: return
        setMuted(muted)
        track.play()
    }

    fun setMuted(muted: Boolean) {
        track?.setVolume(if (muted) 0f else 1f)
    }

    fun release() {
        track?.run {
            stop()
            release()
        }
    }
}
