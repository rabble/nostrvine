package com.divinevideo.divine_video_player

import android.content.Context
import androidx.media3.common.MediaItem
import androidx.media3.exoplayer.ExoPlayer

/**
 * Manages audio overlay tracks that play alongside the main video.
 *
 * Each overlay is an independent [ExoPlayer] instance positioned and
 * synced to the main video timeline. Drift correction keeps audio
 * aligned within [DRIFT_THRESHOLD_MS].
 */
internal class AudioOverlayManager(private val context: Context) {

    private val overlays = mutableListOf<AudioOverlayEntry>()

    /** Replaces all audio overlays with the given track definitions. */
    fun setTracks(
        tracksRaw: List<Map<String, Any?>>,
        currentPlaybackSpeed: Float,
    ) {
        releaseAll()

        for (map in tracksRaw) {
            val uri = map["uri"] as? String ?: continue
            val vol = (map["volume"] as? Number)?.toFloat() ?: 1.0f
            val videoStartMs = (map["videoStartMs"] as? Number)?.toLong() ?: 0L
            val videoEndMs = (map["videoEndMs"] as? Number)?.toLong()
            val trackStartMs = (map["trackStartMs"] as? Number)?.toLong() ?: 0L
            val trackEndMs = (map["trackEndMs"] as? Number)?.toLong()

            val overlay = ExoPlayer.Builder(context).build()
            overlay.setMediaItem(MediaItem.fromUri(uri))
            overlay.prepare()
            overlay.volume = vol
            overlay.setPlaybackSpeed(currentPlaybackSpeed)

            overlays.add(
                AudioOverlayEntry(
                    player = overlay,
                    videoStartMs = videoStartMs,
                    videoEndMs = videoEndMs,
                    trackStartMs = trackStartMs,
                    trackEndMs = trackEndMs,
                ),
            )
        }
    }

    /** Sets volume for the overlay at [index]. */
    fun setTrackVolume(index: Int, volume: Float) {
        if (index in overlays.indices) {
            overlays[index].player.volume = volume
        }
    }

    /** Updates playback speed on all overlay players. */
    fun setPlaybackSpeed(speed: Float) {
        for (entry in overlays) {
            entry.player.setPlaybackSpeed(speed)
        }
    }

    /** Resumes playback of currently active overlays. */
    fun resumeActive() {
        for (entry in overlays) {
            if (entry.isActive) entry.player.play()
        }
    }

    /** Pauses all overlay players without changing active state. */
    fun pauseAll() {
        for (entry in overlays) {
            entry.player.pause()
        }
    }

    /** Pauses all overlay players and marks them inactive. */
    fun pauseAndDeactivateAll() {
        for (entry in overlays) {
            entry.player.pause()
            entry.isActive = false
        }
    }

    /** Stops all overlay players and marks them inactive. */
    fun stopAndDeactivateAll() {
        for (entry in overlays) {
            entry.player.stop()
            entry.isActive = false
        }
    }

    /**
     * Syncs every overlay track to the current global video position.
     *
     * Starts, pauses, or drift-corrects each overlay based on whether
     * the video position falls within that track's active range.
     */
    fun update(globalPositionMs: Long, isPlaying: Boolean) {
        for (entry in overlays) {
            val inRange = globalPositionMs >= entry.videoStartMs &&
                (entry.videoEndMs == null || globalPositionMs < entry.videoEndMs)

            if (inRange && isPlaying) {
                val expectedAudioMs = entry.trackStartMs +
                    (globalPositionMs - entry.videoStartMs)

                // Clamp to trackEnd if set.
                if (entry.trackEndMs != null && expectedAudioMs >= entry.trackEndMs) {
                    if (entry.isActive) {
                        entry.player.pause()
                        entry.isActive = false
                    }
                    continue
                }

                if (!entry.isActive) {
                    entry.player.seekTo(expectedAudioMs)
                    entry.player.play()
                    entry.isActive = true
                } else {
                    // Correct drift.
                    val actualMs = entry.player.currentPosition
                    val drift = kotlin.math.abs(expectedAudioMs - actualMs)
                    if (drift > DRIFT_THRESHOLD_MS) {
                        entry.player.seekTo(expectedAudioMs)
                    }
                }
            } else {
                if (entry.isActive) {
                    entry.player.pause()
                    entry.isActive = false
                }
            }
        }
    }

    /** Releases all overlay players and clears the list. */
    fun releaseAll() {
        for (entry in overlays) {
            entry.player.stop()
            entry.player.release()
        }
        overlays.clear()
    }

    companion object {
        private const val DRIFT_THRESHOLD_MS = 250L
    }
}

/** Holds one audio overlay player and its scheduling metadata. */
internal class AudioOverlayEntry(
    val player: ExoPlayer,
    val videoStartMs: Long,
    val videoEndMs: Long?,
    val trackStartMs: Long,
    val trackEndMs: Long?,
    var isActive: Boolean = false,
)
