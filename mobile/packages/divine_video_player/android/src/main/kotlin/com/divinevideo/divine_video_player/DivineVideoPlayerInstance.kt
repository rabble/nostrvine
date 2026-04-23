package com.divinevideo.divine_video_player

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.view.Surface
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.SeekParameters
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry

/**
 * Wraps a single ExoPlayer instance and bridges it to Dart via
 * per-player [MethodChannel] and [EventChannel].
 *
 * Clips are set as a playlist of [MediaItem]s with clipping
 * configuration. ExoPlayer handles seamless playback between items
 * and native buffering automatically.
 */
internal class DivineVideoPlayerInstance(
    messenger: BinaryMessenger,
    private val context: Context,
    private val playerId: Int,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private val methodChannel = MethodChannel(
        messenger,
        "divine_video_player/player_$playerId",
    )
    private val eventChannel = EventChannel(
        messenger,
        "divine_video_player/player_$playerId/events",
    )

    private var player: ExoPlayer? = null
    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    // Texture rendering (non-null when useTexture is enabled).
    private var textureEntry: TextureRegistry.SurfaceTextureEntry? = null
    private var textureSurface: Surface? = null

    /** Accumulated clip durations for global timeline calculation. */
    private var clipOffsets = listOf<Long>()
    private var clipCount = 0
    private var isLooping = false
    private var volume = 1.0
    private var speed = 1.0
    private var firstFrameRendered = false
    private var videoWidth = 0
    private var videoHeight = 0

    /**
     * True only during the synchronous stop→clearMediaItems→setMediaItems→prepare
     * sequence inside [handleSetClips]. Suppresses [sendStateUpdate] so the
     * spurious STATE_IDLE / position-0 event from [ExoPlayer.stop] is never
     * forwarded to Dart, preventing the timeline from jumping back to 0.
     */
    private var isResettingPlayer = false

    /**
     * Non-zero while ExoPlayer is buffering toward an initial seek position
     * set via [handleSetClips]. [sendStateUpdate] reports this value instead
     * of the intermediate buffering position so the timeline stays at the
     * target position until STATE_READY confirms the seek is complete.
     * Cleared to 0 on the first STATE_READY after a [handleSetClips] call.
     */
    private var pendingGlobalStartMs: Long = 0L

    private val audioOverlayManager = AudioOverlayManager(context)

    /**
     * Pending result for an async seekTo call.
     * Completed when ExoPlayer transitions to STATE_READY after a seek,
     * so the Dart `await seekTo()` blocks until the frame is decoded.
     */
    private var seekCompletionResult: MethodChannel.Result? = null

    /** Safety timeout so Dart is never left hanging if the callback is lost. */
    private val seekTimeoutRunnable = Runnable {
        seekCompletionResult?.success(null)
        seekCompletionResult = null
    }

    private val positionUpdater = object : Runnable {
        override fun run() {
            syncAudioOverlays()
            sendStateUpdate()
            mainHandler.postDelayed(this, POSITION_UPDATE_INTERVAL_MS)
        }
    }

    init {
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
    }

    /**
     * Enables texture-based rendering for this player.
     *
     * Must be called before any clips are loaded. Returns the texture
     * ID that Dart should pass to the `Texture` widget.
     */
    fun enableTextureOutput(registry: TextureRegistry): Long {
        val entry = registry.createSurfaceTexture()
        textureEntry = entry
        textureSurface = Surface(entry.surfaceTexture())
        return entry.id()
    }

    private fun ensurePlayer(): ExoPlayer {
        return player ?: ExoPlayer.Builder(context)
            .setMediaSourceFactory(
                DefaultMediaSourceFactory(VideoCache.dataSourceFactory(context)),
            )
            .build().also { newPlayer ->
                player = newPlayer
                newPlayer.setSeekParameters(SeekParameters.EXACT)
                newPlayer.addListener(playerListener)
                textureSurface?.let { newPlayer.setVideoSurface(it) }
            }
    }

    // -- MethodCallHandler --

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "setClips" -> handleSetClips(call, result)
            "play" -> handlePlay(result)
            "pause" -> handlePause(result)
            "stop" -> handleStop(result)
            "seekTo" -> handleSeekTo(call, result)
            "setVolume" -> handleSetVolume(call, result)
            "setPlaybackSpeed" -> handleSetPlaybackSpeed(call, result)
            "setLooping" -> handleSetLooping(call, result)
            "jumpToClip" -> handleJumpToClip(call, result)
            "setAudioTracks" -> handleSetAudioTracks(call, result)
            "removeAllAudioTracks" -> handleRemoveAllAudioTracks(result)
            "setAudioTrackVolume" -> handleSetAudioTrackVolume(call, result)
            else -> result.notImplemented()
        }
    }

    // -- StreamHandler --

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        eventSink = events
        mainHandler.post(positionUpdater)
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
        mainHandler.removeCallbacks(positionUpdater)
    }

    // -- method handlers --

    @Suppress("UNCHECKED_CAST")
    private fun handleSetClips(call: MethodCall, result: MethodChannel.Result) {
        val clipsRaw = call.argument<List<Map<String, Any?>>>("clips") ?: run {
            result.error("INVALID_ARGS", "clips list required", null)
            return
        }

        val exoPlayer = ensurePlayer()
        val mediaItems = mutableListOf<MediaItem>()
        val offsets = mutableListOf<Long>()
        var accumulated = 0L

        for (map in clipsRaw) {
            val uri = map["uri"] as? String ?: continue
            val startMs = (map["startMs"] as? Number)?.toLong() ?: 0L
            val endMs = (map["endMs"] as? Number)?.toLong()

            val builder = MediaItem.Builder().setUri(uri)
                .setClippingConfiguration(
                    MediaItem.ClippingConfiguration.Builder()
                        .setStartPositionMs(startMs)
                        .apply {
                            if (endMs != null) setEndPositionMs(endMs)
                        }
                        .build(),
                )

            mediaItems.add(builder.build())
            offsets.add(accumulated)

            // If endMs is unknown, we'll recalculate after prepare.
            if (endMs != null) {
                accumulated += endMs - startMs
            }
        }

        clipOffsets = offsets
        clipCount = mediaItems.size
        firstFrameRendered = false

        // Resolve the optional global start position to (clipIndex, localMs)
        // so ExoPlayer begins buffering at the right point immediately.
        val globalStartMs = (call.argument<Number>("startPositionMs"))?.toLong() ?: 0L
        var startIndex = 0
        var startLocalMs = globalStartMs
        if (globalStartMs > 0 && offsets.isNotEmpty()) {
            for (i in offsets.indices) {
                val nextOffset = if (i + 1 < offsets.size) offsets[i + 1] else Long.MAX_VALUE
                if (globalStartMs < nextOffset) {
                    startIndex = i
                    startLocalMs = globalStartMs - offsets[i]
                    break
                }
            }
        }

        // Suppress sendStateUpdate during the synchronous reset so the
        // transient STATE_IDLE / position-0 event from stop() is never
        // forwarded to Dart (which would jump the timeline back to 0).
        isResettingPlayer = true
        exoPlayer.stop()
        exoPlayer.clearMediaItems()
        exoPlayer.setMediaItems(mediaItems, startIndex, startLocalMs)
        exoPlayer.prepare()
        isResettingPlayer = false
        // While ExoPlayer buffers to the seek position, report the target
        // position so the timeline doesn't show intermediate values.
        pendingGlobalStartMs = globalStartMs

        result.success(null)
    }

    private fun handleSeekTo(call: MethodCall, result: MethodChannel.Result) {
        val globalMs = (call.argument<Number>("positionMs"))?.toLong() ?: 0L
        val exoPlayer = ensurePlayer()

        // Complete any previous pending seek so Dart isn't left hanging.
        mainHandler.removeCallbacks(seekTimeoutRunnable)
        seekCompletionResult?.success(null)
        seekCompletionResult = result

        // Ensure clip offsets are up-to-date from ExoPlayer's timeline
        // before resolving the global position. Without this, offsets
        // may all be zero when clips were set without endMs and the
        // lookup would always land on the last clip.
        refreshClipOffsets(exoPlayer)

        // Find which clip the global position falls into.
        val resolved = resolveGlobalPosition(globalMs)

        exoPlayer.seekTo(resolved.first, resolved.second)
        syncAudioOverlays()

        // Safety timeout — complete after 500ms if the callback never fires.
        mainHandler.postDelayed(seekTimeoutRunnable, 500)
    }

    /**
     * Resolves a global timeline position to a (clipIndex, localMs) pair.
     *
     * If clip offsets are all zero (durations not yet known because
     * `prepare()` hasn't finished), falls back to seeking within clip 0
     * to avoid accidentally landing on the last clip.
     */
    private fun resolveGlobalPosition(globalMs: Long): Pair<Int, Long> {
        // If offsets haven't been populated yet (all zero with >1 clip)
        // try refreshing once more from the current timeline.
        if (clipCount > 1 && clipOffsets.all { it == 0L }) {
            player?.let { refreshClipOffsets(it) }
        }

        // Still all zero — fall back to clip 0.
        if (clipCount > 1 && clipOffsets.all { it == 0L }) {
            return Pair(0, globalMs)
        }

        var targetIndex = 0
        var localMs = globalMs
        for (i in clipOffsets.indices) {
            val nextOffset = if (i + 1 < clipOffsets.size) clipOffsets[i + 1]
            else Long.MAX_VALUE
            if (globalMs < nextOffset) {
                targetIndex = i
                localMs = globalMs - clipOffsets[i]
                break
            }
        }
        return Pair(targetIndex, localMs)
    }

    private fun handleSetVolume(call: MethodCall, result: MethodChannel.Result) {
        volume = (call.argument<Number>("volume"))?.toDouble() ?: 1.0
        player?.volume = volume.toFloat()
        result.success(null)
    }

    private fun handleSetPlaybackSpeed(call: MethodCall, result: MethodChannel.Result) {
        speed = (call.argument<Number>("speed"))?.toDouble() ?: 1.0
        player?.setPlaybackSpeed(speed.toFloat())
        audioOverlayManager.setPlaybackSpeed(speed.toFloat())
        result.success(null)
    }

    private fun handleSetLooping(call: MethodCall, result: MethodChannel.Result) {
        isLooping = call.argument<Boolean>("looping") ?: false
        player?.repeatMode = if (isLooping) Player.REPEAT_MODE_ALL else Player.REPEAT_MODE_OFF
        result.success(null)
    }

    private fun handleJumpToClip(call: MethodCall, result: MethodChannel.Result) {
        val index = (call.argument<Number>("index"))?.toInt() ?: 0
        val exoPlayer = ensurePlayer()
        if (index in 0 until clipCount) {
            exoPlayer.seekTo(index, 0)
            syncAudioOverlays()
        }
        result.success(null)
    }

    // -- play / pause with audio sync --

    private fun handlePlay(result: MethodChannel.Result) {
        ensurePlayer().play()
        audioOverlayManager.resumeActive()
        result.success(null)
    }

    private fun handlePause(result: MethodChannel.Result) {
        ensurePlayer().pause()
        audioOverlayManager.pauseAll()
        result.success(null)
    }

    private fun handleStop(result: MethodChannel.Result) {
        val exoPlayer = player ?: run {
            result.success(null)
            return
        }
        audioOverlayManager.stopAndDeactivateAll()
        // Stop and clear media so the surface goes blank.
        exoPlayer.stop()
        exoPlayer.clearMediaItems()
        clipOffsets = listOf()
        clipCount = 0
        firstFrameRendered = false
        sendStateUpdate()
        result.success(null)
    }

    // -- audio overlay tracks --

    @Suppress("UNCHECKED_CAST")
    private fun handleSetAudioTracks(call: MethodCall, result: MethodChannel.Result) {
        val tracksRaw = call.argument<List<Map<String, Any?>>>("tracks") ?: run {
            result.error("INVALID_ARGS", "tracks list required", null)
            return
        }
        audioOverlayManager.setTracks(tracksRaw, speed.toFloat())
        syncAudioOverlays()
        result.success(null)
    }

    private fun handleRemoveAllAudioTracks(result: MethodChannel.Result) {
        audioOverlayManager.releaseAll()
        result.success(null)
    }

    private fun handleSetAudioTrackVolume(call: MethodCall, result: MethodChannel.Result) {
        val index = (call.argument<Number>("index"))?.toInt() ?: -1
        val vol = (call.argument<Number>("volume"))?.toFloat() ?: 1.0f
        audioOverlayManager.setTrackVolume(index, vol)
        result.success(null)
    }

    /** Syncs audio overlays to the current global video position. */
    private fun syncAudioOverlays() {
        val videoPlayer = player ?: return
        val currentIndex = videoPlayer.currentMediaItemIndex
        val localPositionMs = videoPlayer.currentPosition
        val globalPositionMs = if (currentIndex < clipOffsets.size) {
            clipOffsets[currentIndex] + localPositionMs
        } else {
            localPositionMs
        }
        audioOverlayManager.update(globalPositionMs, videoPlayer.isPlaying)
    }

    /** Completes the pending seekTo result so Dart's await returns. */
    private fun completeSeekIfPending() {
        seekCompletionResult?.let {
            mainHandler.removeCallbacks(seekTimeoutRunnable)
            it.success(null)
            seekCompletionResult = null
        }
    }

    // -- state broadcasting --

    private fun sendStateUpdate() {
        if (isResettingPlayer) return
        val exoPlayer = player ?: return
        val sink = eventSink ?: return

        val currentIndex = exoPlayer.currentMediaItemIndex
        val localPositionMs = exoPlayer.currentPosition
        val globalPositionMs = when {
            // While buffering toward an initial seek, report the target so the
            // timeline doesn't wander through intermediate positions.
            pendingGlobalStartMs > 0 -> pendingGlobalStartMs
            currentIndex < clipOffsets.size -> clipOffsets[currentIndex] + localPositionMs
            else -> localPositionMs
        }

        val totalDurationMs = computeTotalDuration(exoPlayer)

        val statusString = when {
            exoPlayer.playerError != null -> "error"
            exoPlayer.playbackState == Player.STATE_BUFFERING -> "buffering"
            exoPlayer.playbackState == Player.STATE_ENDED -> "completed"
            exoPlayer.playbackState == Player.STATE_IDLE -> "idle"
            exoPlayer.isPlaying -> "playing"
            exoPlayer.playbackState == Player.STATE_READY -> if (exoPlayer.playWhenReady) "playing" else "paused"
            else -> "idle"
        }

        val map = mutableMapOf<String, Any>(
            "status" to statusString,
            "positionMs" to globalPositionMs,
            "durationMs" to totalDurationMs,
            "bufferedPositionMs" to computeBufferedPosition(exoPlayer),
            "currentClipIndex" to currentIndex,
            "clipCount" to clipCount,
            "isLooping" to isLooping,
            "volume" to volume,
            "playbackSpeed" to speed,
            "isFirstFrameRendered" to firstFrameRendered,
            "videoWidth" to videoWidth,
            "videoHeight" to videoHeight,
        )
        exoPlayer.playerError?.let { error ->
            map["errorMessage"] = error.localizedMessage
                ?: error.cause?.localizedMessage
                ?: error.errorCodeName
        }
        sink.success(map)
    }

    private fun computeTotalDuration(exoPlayer: ExoPlayer): Long {
        var total = 0L
        val timeline = exoPlayer.currentTimeline
        for (i in 0 until exoPlayer.mediaItemCount) {
            val windowDuration = if (timeline.isEmpty) {
                0L
            } else {
                val w = androidx.media3.common.Timeline.Window()
                timeline.getWindow(i, w)
                val durationMs = w.durationMs
                // Return 0 for unknown durations to avoid Long overflow when
                // accumulating C.TIME_UNSET across an even number of clips.
                if (durationMs < 0) 0L else durationMs
            }
            total += windowDuration
        }
        // Update offsets with real durations once media is prepared.
        if (total > 0) refreshClipOffsets(exoPlayer)
        return total
    }

    /**
     * Recalculates [clipOffsets] from ExoPlayer's timeline when real
     * durations are available. Called from [computeTotalDuration] and
     * before seek operations to ensure correct clip-index resolution.
     */
    private fun refreshClipOffsets(exoPlayer: ExoPlayer) {
        val timeline = exoPlayer.currentTimeline
        if (timeline.isEmpty || clipOffsets.size != exoPlayer.mediaItemCount) {
            return
        }
        val newOffsets = mutableListOf<Long>()
        var accum = 0L
        var allResolved = true
        for (i in 0 until exoPlayer.mediaItemCount) {
            newOffsets.add(accum)
            val w = androidx.media3.common.Timeline.Window()
            timeline.getWindow(i, w)
            val durationMs = w.durationMs
            if (durationMs < 0) {
                // Duration not yet resolved for this clip — skip it but
                // continue so that earlier clips still get correct offsets.
                allResolved = false
                continue
            }
            accum += durationMs
        }
        // Only update when ALL durations are known so partial data from clips
        // that haven't buffered yet doesn't corrupt earlier clip offsets.
        if (allResolved && accum > 0) clipOffsets = newOffsets
    }

    /** Returns the global buffered position in ms for the current clip. */
    private fun computeBufferedPosition(exoPlayer: ExoPlayer): Long {
        val currentIndex = exoPlayer.currentMediaItemIndex
        val localBuffered = exoPlayer.bufferedPosition
        return if (currentIndex < clipOffsets.size) {
            clipOffsets[currentIndex] + localBuffered
        } else {
            localBuffered
        }
    }

    // -- player listener --

    private val playerListener = object : Player.Listener {
        override fun onPlaybackStateChanged(playbackState: Int) {
            if (playbackState == Player.STATE_ENDED && isLooping) {
                syncAudioOverlays()
            }
            if (playbackState == Player.STATE_READY) {
                // Seek complete — switch from reporting target to actual position.
                pendingGlobalStartMs = 0L
                completeSeekIfPending()
            }
            sendStateUpdate()
        }

        override fun onIsPlayingChanged(isPlaying: Boolean) {
            if (isPlaying) {
                syncAudioOverlays()
            } else {
                audioOverlayManager.pauseAndDeactivateAll()
            }
            sendStateUpdate()
        }

        override fun onMediaItemTransition(mediaItem: MediaItem?, reason: Int) {
            syncAudioOverlays()
            sendStateUpdate()
        }

        override fun onPlayerError(error: PlaybackException) {
            sendStateUpdate()
        }

        override fun onRenderedFirstFrame() {
            firstFrameRendered = true
            sendStateUpdate()
        }

        override fun onVideoSizeChanged(videoSize: androidx.media3.common.VideoSize) {
            videoWidth = videoSize.width
            videoHeight = videoSize.height
            sendStateUpdate()
        }
    }

    // -- lifecycle --

    /** Whether the player was playing before the app went to background. */
    private var wasPlayingBeforePause = false

    /**
     * Called when the app moves to the background.
     * Pauses playback and remembers the previous state.
     */
    fun onAppBackgrounded() {
        wasPlayingBeforePause = player?.isPlaying ?: false
        if (wasPlayingBeforePause) {
            player?.pause()
            audioOverlayManager.pauseAll()
            sendStateUpdate()
        }
    }

    /**
     * Called when the app returns to the foreground.
     * Resumes playback only if it was playing before.
     */
    fun onAppForegrounded() {
        if (wasPlayingBeforePause) {
            player?.play()
            audioOverlayManager.resumeActive()
            wasPlayingBeforePause = false
            sendStateUpdate()
        }
    }

    fun getPlayer(): ExoPlayer? = player

    fun dispose() {
        mainHandler.removeCallbacks(positionUpdater)
        mainHandler.removeCallbacks(seekTimeoutRunnable)
        seekCompletionResult?.success(null)
        seekCompletionResult = null
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        player?.removeListener(playerListener)
        player?.setVideoSurface(null)
        player?.release()
        player = null
        textureSurface?.release()
        textureSurface = null
        textureEntry?.release()
        textureEntry = null
        audioOverlayManager.releaseAll()
        eventSink = null
    }

    companion object {
        private const val POSITION_UPDATE_INTERVAL_MS = 200L
    }
}
