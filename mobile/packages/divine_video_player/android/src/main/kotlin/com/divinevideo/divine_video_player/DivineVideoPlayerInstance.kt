package com.divinevideo.divine_video_player

import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.view.Surface
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.PlaybackParameters
import androidx.media3.common.Player
import androidx.media3.common.util.UnstableApi
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
@UnstableApi
internal class DivineVideoPlayerInstance(
    messenger: BinaryMessenger,
    private val context: Context,
    private val playerId: Int,
    private val playerFactory: ((Context) -> ExoPlayer)? = null,
    private val bufferProfile: BufferProfile = BufferProfile.FULL,
    private val mainHandler: Handler = Handler(Looper.getMainLooper()),
    private val audioOverlayManagerFactory: (Context) -> AudioOverlayManager = { ctx ->
        AudioOverlayManager(ctx)
    },
) : MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler,
    TextureRegistry.SurfaceProducer.Callback {

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
    private var httpHeadersByUri = emptyMap<String, Map<String, String>>()

    // Viewer auth headers keyed by blob hash. HLS sub-playlist / segment
    // requests use URIs that differ from the clip URI but share the same
    // /<hash>/… prefix; BUD-01 (kind 24242) tokens are hash-bound, so one header
    // set authenticates every variant of a hash. Used when the exact-URI lookup
    // misses (e.g. HLS segments derived from an authenticated manifest).
    private var httpHeadersByHash = emptyMap<String, Map<String, String>>()

    // Texture rendering (non-null when useTexture is enabled).
    //
    // Two backends are supported and selected per player at
    // [enableTextureOutput] time:
    //  * [TextureRegistry.SurfaceProducer] (default): Android 14+ ImageReader
    //    backend. Forwards Surface destroy/recreate events via the
    //    [TextureRegistry.SurfaceProducer.Callback] callback so playback can
    //    survive OEM compositor events (Vivo/Android 16, permission dialogs).
    //    Has a small (3–4) hardcoded buffer pool which can leak a stale
    //    frame across decoder format reprobes — visible as a 1-frame ghost
    //    when many players coexist (the feed). See #3416 / feed flicker.
    //  * [TextureRegistry.SurfaceTextureEntry] (legacy): single-buffer
    //    SurfaceTexture. No surface-recreate callback, but no shared pool
    //    either, so it is immune to the cross-decoder ghost-frame issue.
    //    Used by callers that render many players at once (the feed).
    //
    // Exactly one of these is non-null after [enableTextureOutput].
    private var surfaceProducer: TextureRegistry.SurfaceProducer? = null
    private var legacyEntry: TextureRegistry.SurfaceTextureEntry? = null
    private var legacySurface: Surface? = null

    /**
     * True when ExoPlayer needs a surface re-attached.
     * Set to true on init and after [onSurfaceCleanup]; cleared in [onSurfaceAvailable].
     * Only meaningful for the [surfaceProducer] backend — the legacy
     * SurfaceTexture surface is always available for the lifetime of the
     * player.
     */
    private var needsSurface = true

    /** The currently active output Surface across both backends. */
    private val activeSurface: Surface?
        get() = legacySurface ?: surfaceProducer?.surface

    /**
     * Whether the active backend already applies the GL transform matrix
     * for video rotation (so Dart must NOT also apply RotatedBox).
     * True for legacy SurfaceTexture (transform is encoded in the texture)
     * and for SurfaceProducer when [TextureRegistry.SurfaceProducer.handlesCropAndRotation]
     * reports true.
     */
    private val backendHandlesRotation: Boolean
        get() = legacyEntry != null ||
            (surfaceProducer?.handlesCropAndRotation() == true)

    /**
     * Accumulated per-clip start offsets on the global timeline, expressed
     * in playback (speed-adjusted) time — i.e. the same coordinate space
     * Dart uses for the editor timeline. Source duration is divided by the
     * clip's playback speed (slower → longer on the timeline).
     */
    private var clipOffsets = listOf<Long>()
    /** Per-clip audio volumes (0.0–1.0). Multiplied by [volume] on each clip transition. */
    private var clipVolumes = listOf<Float>()
    /** Per-clip playback speed multipliers (1.0 = normal). Never zero. */
    private var clipSpeeds = listOf<Float>()
    private var clipCount = 0
    private var isLooping = false
    private var volume = 1.0
    private var speed = 1.0
    private var firstFrameRendered = false
    private var videoWidth = 0
    private var videoHeight = 0
    private var rotationDegrees = 0

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

    private val audioOverlayManager = audioOverlayManagerFactory(context)

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

    /**
     * Pending result for an async setClips call.
     * Held until ExoPlayer transitions to STATE_READY (or reports an error),
     * so `await setClips()` on the Dart side only resolves once the decoder
     * is truly ready. Required for OEM decoders (e.g. Mediatek) that take
     * variable time to reach STATE_READY after prepare().
     */
    private var pendingSetClipsResult: MethodChannel.Result? = null

    /** Safety timeout so Dart is never left hanging if STATE_READY is lost. */
    private val setClipsTimeoutRunnable = Runnable {
        if (pendingSetClipsResult != null) {
            DivineVideoPlayerLog.warning(
                "Player $playerId load froze: never reached ready within " +
                    "${SET_CLIPS_TIMEOUT_MS}ms",
                name = "DivineVideoPlayer.Freeze",
            )
        }
        pendingSetClipsResult?.success(null)
        pendingSetClipsResult = null
    }

    /**
     * Fires when the player stays in `STATE_BUFFERING` past
     * [BUFFERING_STALL_MS] — the spinner is stuck and the video appears
     * frozen to the user. Reset whenever the player leaves the buffering
     * state so each stall episode is reported at most once.
     */
    private var bufferingStallReported = false
    private val bufferingWatchdogRunnable = Runnable {
        bufferingStallReported = true
        DivineVideoPlayerLog.warning(
            "Player $playerId appears frozen: still buffering after " +
                "${BUFFERING_STALL_MS}ms",
            name = "DivineVideoPlayer.Freeze",
        )
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
     *
     * When [useLegacySurface] is `false` (default) this uses
     * [TextureRegistry.SurfaceProducer] so Android can notify us when
     * the underlying surface is destroyed and recreated (permission
     * dialogs, OEM compositor events on Vivo/Android 16).
     *
     * When [useLegacySurface] is `true` this uses the legacy
     * [TextureRegistry.SurfaceTextureEntry] which does not deliver
     * surface-recreate callbacks but is immune to the SurfaceProducer
     * ImageReader-pool ghost-frame issue. Use this for screens that
     * render many players at once (the feed) where a sibling decoder's
     * release can leak a stale frame onto a peer's surface.
     */
    fun enableTextureOutput(
        registry: TextureRegistry,
        useLegacySurface: Boolean = false,
    ): Long {
        if (useLegacySurface) {
            val entry = registry.createSurfaceTexture()
            legacyEntry = entry
            val surface = Surface(entry.surfaceTexture())
            legacySurface = surface
            needsSurface = false
            player?.setVideoSurface(surface)
            return entry.id()
        }
        val producer = registry.createSurfaceProducer()
        surfaceProducer = producer
        producer.setCallback(this)
        val surface = producer.surface
        needsSurface = surface == null
        if (surface != null) {
            player?.setVideoSurface(surface)
        }
        return producer.id()
    }

    private fun ensurePlayer(): ExoPlayer {
        return player ?: (playerFactory?.invoke(context) ?: buildDefaultPlayer())
            .also { newPlayer ->
                player = newPlayer
                newPlayer.setSeekParameters(SeekParameters.EXACT)
                newPlayer.addListener(playerListener)
                val surface = activeSurface
                if (surface != null) {
                    newPlayer.setVideoSurface(surface)
                    needsSurface = false
                }
            }
    }

    private fun buildDefaultPlayer(): ExoPlayer {
        val builder = ExoPlayer.Builder(context)
            .setMediaSourceFactory(
                DefaultMediaSourceFactory(
                    VideoCache.dataSourceFactory(context) { uri: Uri ->
                        httpHeadersForRequest(uri.toString())
                    },
                ),
            )
        // The feed keeps several players live on memory-constrained devices,
        // so cap their read-ahead to avoid ExoPlayer OOM (#3419). Editing
        // surfaces keep the default unbounded buffering.
        if (bufferProfile == BufferProfile.FEED) {
            builder.setLoadControl(FeedLoadControl.build())
        }
        return builder.build()
    }

    internal fun httpHeadersForRequest(url: String): Map<String, String> {
        httpHeadersByUri[url]?.let { return it }
        val hash = blobHashFromUrl(url) ?: return emptyMap()
        return httpHeadersByHash[hash] ?: emptyMap()
    }

    /**
     * Extracts the 64-char hex blob hash from the first path segment of [url],
     * mirroring the origin's hash-from-path rule. Pure string parsing so it
     * needs no `android.net.Uri` and stays unit-testable.
     */
    internal fun blobHashFromUrl(url: String): String? {
        val authorityAndPath = url.substringAfter("://", url)
        val path = authorityAndPath.substringAfter('/', "")
        val firstSegment = path
            .substringBefore('/')
            .substringBefore('?')
            .substringBefore('#')
        val candidate = firstSegment.substringBefore('.')
        val isHex = candidate.length == 64 &&
            candidate.all { it in '0'..'9' || it in 'a'..'f' || it in 'A'..'F' }
        return if (isHex) candidate.lowercase() else null
    }

    // -- SurfaceProducer.Callback --

    override fun onSurfaceAvailable() {
        if (needsSurface) {
            val surface = surfaceProducer?.surface ?: return
            val p = player
            if (p != null) {
                p.setVideoSurface(surface)
                needsSurface = false
                // ExoPlayer does not re-render the current frame after a surface
                // reattach when the player is paused — the surface stays black
                // until the next decoded frame arrives (i.e. not until play()).
                // Seeking to the current position forces the codec to decode and
                // display the frame at the current position without moving it.
                if (!p.isPlaying && p.playbackState == Player.STATE_READY) {
                    p.seekTo(p.currentPosition)
                }
            }
            // If player is null, needsSurface stays true so ensurePlayer()
            // attaches the surface when the player is eventually created.
        }
    }

    override fun onSurfaceCleanup() {
        player?.setVideoSurface(null)
        needsSurface = true
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
        val volumes = mutableListOf<Float>()
        val speeds = mutableListOf<Float>()
        val headersByUri = mutableMapOf<String, Map<String, String>>()
        val headersByHash = mutableMapOf<String, Map<String, String>>()
        var accumulated = 0L

        for (map in clipsRaw) {
            val uri = map["uri"] as? String
            if (uri == null) {
                DivineVideoPlayerLog.warning(
                    "Player $playerId skipped a clip: missing uri",
                    name = "DivineVideoPlayer.Load",
                )
                continue
            }
            val startMs = (map["startMs"] as? Number)?.toLong() ?: 0L
            val endMs = (map["endMs"] as? Number)?.toLong()
            val clipVol = (map["volume"] as? Number)?.toFloat() ?: 1.0f
            val clipSpeed = ((map["playbackSpeed"] as? Number)?.toFloat() ?: 1.0f)
                .coerceAtLeast(MIN_PLAYBACK_SPEED)
            val httpHeaders = (map["httpHeaders"] as? Map<*, *>)
                ?.mapNotNull { entry ->
                    val key = entry.key as? String
                    val value = entry.value as? String
                    if (key == null || value == null) null else key to value
                }
                ?.toMap()
                ?: emptyMap()
            if (httpHeaders.isNotEmpty()) {
                headersByUri[uri] = httpHeaders
                blobHashFromUrl(uri)?.let { headersByHash[it] = httpHeaders }
            }

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
            volumes.add(clipVol)
            speeds.add(clipSpeed)

            // If endMs is unknown, we'll recalculate after prepare.
            // Offsets accumulate in playback time so the global timeline
            // matches what the editor UI shows (slow clips occupy more
            // space, fast clips less).
            if (endMs != null) {
                accumulated += sourceToPlaybackMs(endMs - startMs, clipSpeed)
            }
        }

        clipOffsets = offsets
        clipVolumes = volumes
        clipSpeeds = speeds
        clipCount = mediaItems.size
        httpHeadersByUri = headersByUri
        httpHeadersByHash = headersByHash
        firstFrameRendered = false

        // Resolve the optional global start position to (clipIndex, localMs)
        // so ExoPlayer begins buffering at the right point immediately.
        // [globalStartMs] arrives in playback time; ExoPlayer.seekTo expects
        // source time, so we convert via the resolved clip's speed.
        val globalStartMs = (call.argument<Number>("startPositionMs"))?.toLong() ?: 0L
        var startIndex = 0
        var startLocalMs = globalStartMs
        if (globalStartMs > 0 && offsets.isNotEmpty()) {
            for (i in offsets.indices) {
                val nextOffset = if (i + 1 < offsets.size) offsets[i + 1] else Long.MAX_VALUE
                if (globalStartMs < nextOffset) {
                    startIndex = i
                    startLocalMs = playbackToSourceMs(
                        globalStartMs - offsets[i],
                        speeds[i],
                    )
                    break
                }
            }
        }

        // Replace the playlist in-place without calling stop() first.
        // stop() transitions ExoPlayer to STATE_IDLE which on some OEM decoders
        // (e.g. Vivo/Mediatek) triggers a full MediaCodec reset and surface
        // disconnect. setMediaItems() handles playlist replacement internally
        // without that overhead. isResettingPlayer suppresses intermediate
        // state events fired while ExoPlayer processes the new items.
        isResettingPlayer = true
        exoPlayer.setMediaItems(mediaItems, startIndex, startLocalMs)
        exoPlayer.prepare()
        isResettingPlayer = false
        DivineVideoPlayerLog.info(
            "Player $playerId prepared $clipCount clip(s)",
            name = "DivineVideoPlayer.Load",
        )
        // Apply the starting clip's per-clip volume immediately so the correct
        // level is audible as soon as the decoder is ready. Use startIndex
        // (not 0) so a resume mid-playlist doesn't play clip 0's volume
        // before onMediaItemTransition can correct it.
        exoPlayer.volume = clipVolumes.getOrElse(startIndex) { 1.0f } * volume.toFloat()
        exoPlayer.setPlaybackParameters(PlaybackParameters(clipSpeeds.getOrElse(startIndex) { 1.0f }))
        // While ExoPlayer buffers to the seek position, report the target
        // position so the timeline doesn't show intermediate values.
        pendingGlobalStartMs = globalStartMs

        // Hold the Dart result until STATE_READY so `await setClips()` only
        // resolves once the decoder is truly ready. Cancel any previous
        // in-flight setClips (shouldn't happen, but defensive) — surface as
        // an error so the superseded caller doesn't believe the player is
        // ready for its clips.
        mainHandler.removeCallbacks(setClipsTimeoutRunnable)
        pendingSetClipsResult?.error(
            "CANCELLED",
            "Superseded by newer setClips call",
            null,
        )
        pendingSetClipsResult = result
        // 10 s safety net — if STATE_READY never fires (e.g. corrupt file),
        // Dart is unblocked rather than hanging forever.
        mainHandler.postDelayed(setClipsTimeoutRunnable, SET_CLIPS_TIMEOUT_MS)
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

        // [globalMs] is in playback time; resolveGlobalPosition returns the
        // clip index plus a clip-local position already converted to source
        // time, which is what ExoPlayer.seekTo expects.
        val resolved = resolveGlobalPosition(globalMs)

        val targetIndex = resolved.first
        exoPlayer.seekTo(targetIndex, resolved.second)

        // Apply the target clip's per-clip speed and volume immediately.
        // ExoPlayer does not fire onPositionDiscontinuity / onMediaItemTransition
        // with a speed-update path for manual seeks — only AUTO_TRANSITION is
        // covered there. Without this, seeking from clip 2 (e.g. 0.25×) back
        // to clip 1 (e.g. 3×) leaves the player running at 0.25× indefinitely.
        exoPlayer.volume = (clipVolumes.getOrElse(targetIndex) { 1.0f }) * volume.toFloat()
        exoPlayer.setPlaybackParameters(
            PlaybackParameters(clipSpeeds.getOrElse(targetIndex) { 1.0f }),
        )

        syncAudioOverlays()

        // Safety timeout — complete after 500ms if the callback never fires.
        mainHandler.postDelayed(seekTimeoutRunnable, 500)
    }

    /**
     * Resolves a playback-time global position to a (clipIndex, localMs)
     * pair where [localMs] is in source (clip-local) time, ready for
     * `ExoPlayer.seekTo`.
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
            return Pair(0, playbackToSourceMs(globalMs, clipSpeeds.getOrElse(0) { 1.0f }))
        }

        var targetIndex = 0
        var localPlaybackMs = globalMs
        for (i in clipOffsets.indices) {
            val nextOffset = if (i + 1 < clipOffsets.size) clipOffsets[i + 1]
            else Long.MAX_VALUE
            if (globalMs < nextOffset) {
                targetIndex = i
                localPlaybackMs = globalMs - clipOffsets[i]
                break
            }
        }
        val targetSpeed = clipSpeeds.getOrElse(targetIndex) { 1.0f }
        return Pair(targetIndex, playbackToSourceMs(localPlaybackMs, targetSpeed))
    }

    private fun handleSetVolume(call: MethodCall, result: MethodChannel.Result) {
        volume = (call.argument<Number>("volume"))?.toDouble() ?: 1.0
        val currentIndex = player?.currentMediaItemIndex ?: 0
        player?.volume = (clipVolumes.getOrElse(currentIndex) { 1.0f }) * volume.toFloat()
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
        clipVolumes = listOf()
        clipSpeeds = listOf()
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
        DivineVideoPlayerLog.info(
            "Player $playerId set ${tracksRaw.size} audio overlay track(s)",
            name = "DivineVideoPlayer.Audio",
        )
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
        val globalPositionMs = currentGlobalPlaybackMs(videoPlayer)
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
        val globalPositionMs = when {
            // While buffering toward an initial seek, report the target so the
            // timeline doesn't wander through intermediate positions.
            pendingGlobalStartMs > 0 -> pendingGlobalStartMs
            else -> currentGlobalPlaybackMs(exoPlayer)
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
            "rotationDegrees" to rotationDegrees,
        )
        exoPlayer.playerError?.let { error ->
            map["errorMessage"] = error.localizedMessage
                ?: error.cause?.localizedMessage
                ?: error.errorCodeName
            map["errorCode"] = when (error.errorCode) {
                PlaybackException.ERROR_CODE_IO_BAD_HTTP_STATUS -> {
                    val status = (error.cause as? androidx.media3.datasource.HttpDataSource.InvalidResponseCodeException)?.responseCode ?: 0
                    if (status in 400..499) "http_client_error" else "http_server_error"
                }
                PlaybackException.ERROR_CODE_IO_FILE_NOT_FOUND,
                PlaybackException.ERROR_CODE_IO_INVALID_HTTP_CONTENT_TYPE,
                PlaybackException.ERROR_CODE_IO_NO_PERMISSION -> "http_client_error"
                PlaybackException.ERROR_CODE_IO_NETWORK_CONNECTION_FAILED -> "network_error"
                PlaybackException.ERROR_CODE_IO_NETWORK_CONNECTION_TIMEOUT -> "timeout"
                in 2000..2999 -> "decoder_error"
                in 3000..3999 -> "parse_error"
                in 4000..4999 -> "decoder_error"
                in 6000..6999 -> "decoder_error"
                else -> "unknown"
            }
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
            // Convert source duration → playback (timeline) duration so the
            // total matches the speed-adjusted timeline Dart renders.
            val clipSpeed = clipSpeeds.getOrElse(i) { 1.0f }
            total += sourceToPlaybackMs(windowDuration, clipSpeed)
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
            // Offsets accumulate in playback (speed-adjusted) time.
            val clipSpeed = clipSpeeds.getOrElse(i) { 1.0f }
            accum += sourceToPlaybackMs(durationMs, clipSpeed)
        }
        // Only update when ALL durations are known so partial data from clips
        // that haven't buffered yet doesn't corrupt earlier clip offsets.
        if (allResolved && accum > 0) clipOffsets = newOffsets
    }

    /** Returns the global buffered position in ms for the current clip. */
    private fun computeBufferedPosition(exoPlayer: ExoPlayer): Long {
        val currentIndex = exoPlayer.currentMediaItemIndex
        val localBufferedSource = exoPlayer.bufferedPosition
        val clipSpeed = clipSpeeds.getOrElse(currentIndex) { 1.0f }
        val localBufferedPlayback = sourceToPlaybackMs(localBufferedSource, clipSpeed)
        return if (currentIndex < clipOffsets.size) {
            clipOffsets[currentIndex] + localBufferedPlayback
        } else {
            localBufferedPlayback
        }
    }

    /**
     * Returns the current global playback-time position by mapping
     * ExoPlayer's source-time `currentPosition` through the active clip's
     * playback speed.
     */
    private fun currentGlobalPlaybackMs(exoPlayer: ExoPlayer): Long {
        val currentIndex = exoPlayer.currentMediaItemIndex
        val localSourceMs = exoPlayer.currentPosition
        val clipSpeed = clipSpeeds.getOrElse(currentIndex) { 1.0f }
        val localPlaybackMs = sourceToPlaybackMs(localSourceMs, clipSpeed)
        return if (currentIndex < clipOffsets.size) {
            clipOffsets[currentIndex] + localPlaybackMs
        } else {
            localPlaybackMs
        }
    }

    /** Source duration / speed = playback (timeline) duration. */
    private fun sourceToPlaybackMs(sourceMs: Long, speed: Float): Long {
        if (sourceMs <= 0L) return 0L
        val safe = speed.coerceAtLeast(MIN_PLAYBACK_SPEED)
        return (sourceMs.toDouble() / safe.toDouble()).toLong()
    }

    /** Playback (timeline) duration * speed = source duration. */
    private fun playbackToSourceMs(playbackMs: Long, speed: Float): Long {
        if (playbackMs <= 0L) return 0L
        val safe = speed.coerceAtLeast(MIN_PLAYBACK_SPEED)
        return (playbackMs.toDouble() * safe.toDouble()).toLong()
    }

    // -- player listener --

    private val playerListener = object : Player.Listener {
        override fun onPlaybackStateChanged(playbackState: Int) {
            if (playbackState == Player.STATE_BUFFERING) {
                // Arm the freeze watchdog once per stall episode.
                if (!bufferingStallReported) {
                    mainHandler.removeCallbacks(bufferingWatchdogRunnable)
                    mainHandler.postDelayed(
                        bufferingWatchdogRunnable,
                        BUFFERING_STALL_MS,
                    )
                }
            } else {
                mainHandler.removeCallbacks(bufferingWatchdogRunnable)
                bufferingStallReported = false
            }
            if (playbackState == Player.STATE_ENDED && isLooping) {
                syncAudioOverlays()
            }
            if (playbackState == Player.STATE_READY) {
                // Seek complete — switch from reporting target to actual position.
                pendingGlobalStartMs = 0L
                completeSeekIfPending()
                // setClips complete — unblock the Dart await.
                mainHandler.removeCallbacks(setClipsTimeoutRunnable)
                pendingSetClipsResult?.success(null)
                pendingSetClipsResult = null
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

        override fun onPositionDiscontinuity(
            oldPosition: Player.PositionInfo,
            newPosition: Player.PositionInfo,
            reason: Int,
        ) {
            // Apply per-clip speed/volume as early as possible on auto-transition.
            // [onMediaItemTransition] fires later in the pipeline, after a few
            // frames of the new clip have already rendered with the previous
            // clip's playback parameters — audible/visible as a brief
            // fast-forward (or slow-mo) at the start of the new clip when
            // speeds differ. Position discontinuity fires at the moment the
            // playback position jumps to the new media item, so resetting
            // here closes that window.
            // The mediaItemIndex guard also makes this a no-op for single-clip
            // loops (REPEAT_MODE_ALL with one item): both indices are 0, so the
            // block is skipped entirely → seamless loop regardless of speed.
            if (reason == Player.DISCONTINUITY_REASON_AUTO_TRANSITION &&
                newPosition.mediaItemIndex != oldPosition.mediaItemIndex
            ) {
                val newIndex = newPosition.mediaItemIndex
                val oldIndex = oldPosition.mediaItemIndex
                val newSpeed = clipSpeeds.getOrElse(newIndex) { 1.0f }
                val oldSpeed = clipSpeeds.getOrElse(oldIndex) { 1.0f }
                player?.volume = (clipVolumes.getOrElse(newIndex) { 1.0f }) * volume.toFloat()
                player?.setPlaybackParameters(PlaybackParameters(newSpeed))
                // setPlaybackParameters alone does not flush the audio sink
                // (Sonic) buffer that was filled at the previous clip's rate.
                // Audible result: the first ~500 ms of the new clip plays
                // at the previous clip's speed before Sonic catches up. A
                // [seekTo] of the new clip's start forces a renderer flush
                // so subsequent samples are stretched at the new rate from
                // frame zero. Only do this when the speed actually differs,
                // to avoid an unnecessary stutter on equal-speed transitions.
                if (newSpeed != oldSpeed) {
                    player?.seekTo(newIndex, 0L)
                }
            }
        }

        override fun onMediaItemTransition(mediaItem: MediaItem?, reason: Int) {
            // When ExoPlayer auto-advances to the next playlist item it reuses the
            // decoder without reconfiguring the output surface rotation. Force a
            // detach+reattach so the decoder re-initialises its rotation transform
            // for the new clip. Not needed for PLAYLIST_CHANGED (reason=3) because
            // the surface is freshly attached at that point.
            if (reason == Player.MEDIA_ITEM_TRANSITION_REASON_AUTO) {
                val surface = activeSurface
                if (surface != null && !needsSurface) {
                    player?.setVideoSurface(null)
                    player?.setVideoSurface(surface)
                }
            }
            // Apply per-clip volume and speed for the clip that just started.
            // [onPositionDiscontinuity] already handles the speed/volume switch
            // (including the Sonic-flush seekTo) for every automatic transition,
            // including REPEAT_MODE_ALL loops. This block is therefore a
            // safety-net only: it covers any edge case where
            // onPositionDiscontinuity did not fire (e.g. a single-item repeat
            // in REPEAT_MODE_ONE where mediaItemIndex does not change).
            // The seekTo flush is intentionally NOT repeated here — a second
            // seekTo on the same frame causes a double-stutter at the loop
            // restart point without any audio benefit.
            if (reason == Player.MEDIA_ITEM_TRANSITION_REASON_AUTO ||
                reason == Player.MEDIA_ITEM_TRANSITION_REASON_REPEAT
            ) {
                val newIndex = player?.currentMediaItemIndex ?: 0
                val newSpeed = clipSpeeds.getOrElse(newIndex) { 1.0f }
                player?.volume = (clipVolumes.getOrElse(newIndex) { 1.0f }) * volume.toFloat()
                player?.setPlaybackParameters(PlaybackParameters(newSpeed))
            }
            syncAudioOverlays()
            sendStateUpdate()
        }

        override fun onPlayerError(error: PlaybackException) {
            DivineVideoPlayerLog.error(
                "Player $playerId playback error [${error.errorCodeName}]: " +
                    (error.message ?: "unknown"),
                name = "DivineVideoPlayer.Playback",
            )
            // Unblock a pending setClips with an error so Dart can react
            // rather than waiting for the 10 s safety timeout.
            mainHandler.removeCallbacks(setClipsTimeoutRunnable)
            pendingSetClipsResult?.error(
                "PLAYER_ERROR",
                error.message ?: "Unknown playback error",
                null,
            )
            pendingSetClipsResult = null
            sendStateUpdate()
        }

        override fun onRenderedFirstFrame() {
            firstFrameRendered = true
            sendStateUpdate()
        }

        override fun onVideoSizeChanged(videoSize: androidx.media3.common.VideoSize) {
            videoWidth = videoSize.width
            videoHeight = videoSize.height
            // Send 0 when the active backend already applies the GL transform
            // matrix (legacy SurfaceTexture always does; SurfaceProducer does
            // when handlesCropAndRotation() reports true on Android 14+).
            // RotatedBox in Dart would double-rotate in those cases. On the
            // SurfaceProducer fallback path Dart must compensate.
            //
            // Guard: ExoPlayer emits onVideoSizeChanged(0, 0) as an intermediate
            // reset during seeks and transitions; skip to avoid a brief flash
            // of 0° rotation.
            val newRotation = if (backendHandlesRotation) {
                0
            } else {
                player?.videoFormat?.rotationDegrees ?: 0
            }
            if (videoSize.width > 0 && videoSize.height > 0) {
                rotationDegrees = newRotation
            }
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
     * Resumes playback only if it was playing before. For players that were
     * already paused before backgrounding, seeks to the current position so
     * ExoPlayer decodes and displays the current frame — without this the
     * surface stays black on devices where the Surface is not destroyed and
     * recreated on background (i.e. onSurfaceAvailable is never called).
     */
    fun onAppForegrounded() {
        val p = player
        if (wasPlayingBeforePause) {
            p?.play()
            audioOverlayManager.resumeActive()
            wasPlayingBeforePause = false
            sendStateUpdate()
        } else if (p != null && !p.isPlaying && p.playbackState == Player.STATE_READY) {
            // seekTo() does not reliably flush a frame to the surface on all
            // devices. play() forces the decoder to output a frame; we
            // immediately schedule a pause on the next main-thread loop so the
            // video doesn't actually advance. Mute during this single frame
            // to avoid an audible glitch.
            p.volume = 0f
            p.play()
            mainHandler.post {
                p.pause()
                p.volume = volume.toFloat()
            }
        }
    }

    fun getPlayer(): ExoPlayer? = player

    /**
     * Stops decoding and detaches the video surface without releasing the
     * player. Used during Activity teardown so in-flight decoder frames
     * narrow the window where they can land in a detaching
     * `ImageReaderSurfaceProducer`. The full [dispose] runs later, on
     * engine detach.
     *
     * Asymmetric with [onAppBackgrounded] by design: no resume is expected
     * after Activity detach, so [wasPlayingBeforePause] is not set.
     */
    fun stopForActivityDetach() {
        player?.let {
            it.stop()
            it.clearVideoSurface()
        }
        // Only the SurfaceProducer backend hands the surface back later via
        // onSurfaceAvailable. The legacy SurfaceTexture surface is owned
        // for the player's lifetime and reattaches eagerly, so leave
        // needsSurface untouched in that case.
        if (surfaceProducer != null) {
            needsSurface = true
        }
        audioOverlayManager.pauseAll()
    }

    fun dispose() {
        mainHandler.removeCallbacks(positionUpdater)
        mainHandler.removeCallbacks(seekTimeoutRunnable)
        mainHandler.removeCallbacks(setClipsTimeoutRunnable)
        mainHandler.removeCallbacks(bufferingWatchdogRunnable)
        seekCompletionResult?.success(null)
        seekCompletionResult = null
        pendingSetClipsResult?.success(null)
        pendingSetClipsResult = null
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        // Release the player before the surface producer. Releasing the
        // producer first can cause in-flight decoder frames to land in a
        // detaching surface, triggering native crashes on some OEMs (#3416).
        player?.let {
            it.removeListener(playerListener)
            it.stop()
            it.clearVideoSurface()
            it.release()
        }
        player = null
        surfaceProducer?.release()
        surfaceProducer = null
        legacySurface?.release()
        legacySurface = null
        legacyEntry?.release()
        legacyEntry = null
        audioOverlayManager.releaseAll()
        eventSink = null
    }

    companion object {
        private const val POSITION_UPDATE_INTERVAL_MS = 200L
        private const val SET_CLIPS_TIMEOUT_MS = 10_000L

        /**
         * How long the player may stay in `STATE_BUFFERING` before it is
         * treated as frozen and a diagnostic is emitted. Long enough to not
         * trip on routine rebuffering, short enough that a real freeze is
         * captured while the user is still on the screen.
         */
        private const val BUFFERING_STALL_MS = 8_000L

        /**
         * Floor for clip playback speed. Prevents division by zero when
         * converting between source and playback time, and matches the
         * sensible lower bound the editor UI exposes.
         */
        private const val MIN_PLAYBACK_SPEED = 0.001f
    }
}
