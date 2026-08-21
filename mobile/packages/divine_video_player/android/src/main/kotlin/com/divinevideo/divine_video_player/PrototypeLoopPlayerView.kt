package com.divinevideo.divine_video_player

import android.content.Context
import android.graphics.SurfaceTexture
import android.net.Uri
import android.view.Choreographer
import android.view.Surface
import android.view.TextureView
import android.view.View
import androidx.annotation.OptIn
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.common.VideoSize
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.analytics.AnalyticsListener
import io.flutter.FlutterInjector
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

internal const val VIEW_TYPE = "divine_video_player/prototype_loop"
internal const val ASSET_SCHEME = "asset:"

/** How many copies of the clip to queue before the playlist itself wraps. */
private const val PLAYLIST_COPIES = 60

/** How far ahead ExoPlayer should preload the next playlist item. */
private const val PRELOAD_TARGET_US = 2_000_000L

/**
 * A gapless looping player built on Media3's [ExoPlayer].
 *
 * `REPEAT_MODE_ONE` is what makes the loop seamless: ExoPlayer prepares the
 * next media period while the current one is still playing, and because the
 * format is byte-identical across the wrap it reuses the codec instead of
 * flushing it. A `seekTo(0)` on end-of-stream — the usual way to loop — has to
 * flush the decoder and re-fill the pipeline, which is the hitch we are
 * avoiding.
 *
 * Rendering goes through a [TextureView] rather than a `SurfaceView` because
 * Flutter composites Android platform views into a texture layer; a
 * `SurfaceView` would punch its own window out of that composition.
 */
@OptIn(UnstableApi::class)
class PrototypeLoopPlayerView(
    context: Context,
    viewId: Int,
    params: Map<*, *>,
    messenger: BinaryMessenger,
) : PlatformView, MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, "$VIEW_TYPE/$viewId")
    private val textureView = TextureView(context)
    private val player = ExoPlayer.Builder(context).build()

    private var surface: Surface? = null
    private var pcmTrack: PrototypePcmLoopTrack? = null
    private var loopCount = 0

    // Loop-seam instrumentation, mirroring the iOS side. A freeze at the wrap
    // shows up as the playback clock standing still while the frame clock keeps
    // going, so sample both every vsync and report the worst run per cycle.
    private var frameCallback: Choreographer.FrameCallback? = null
    private var lastItemMs = -1L
    private var lastTickNanos = 0L
    private var cycleStartNanos = 0L
    private var stallRunMs = 0.0
    private var worstStallMs = 0.0

    // The playback clock keeps advancing even when no new frame reaches the
    // screen, so a frozen picture is invisible to the clock comparison above.
    // onSurfaceTextureUpdated fires per delivered frame, which is the signal
    // that actually says whether the image moved.
    private var lastFrameNanos = 0L
    private var worstFrameGapMs = 0.0
    /** Playback position when the worst gap happened, to locate it in the clip. */
    private var worstFrameGapAtMs = 0L
    /** Every gap in the cycle, so the max can be read against the typical one. */
    private val frameGapsMs = ArrayList<Double>(128)
    private var droppedFrames = 0

    init {
        channel.setMethodCallHandler(this)

        val source = params["source"] as? String ?: ""
        val muted = params["muted"] as? Boolean ?: false
        val usePlaylist = params["playlistLoop"] as? Boolean ?: false
        val nativeAudio = params["nativeAudioPath"] as? String

        textureView.surfaceTextureListener = object : TextureView.SurfaceTextureListener {
            override fun onSurfaceTextureAvailable(st: SurfaceTexture, width: Int, height: Int) {
                surface = Surface(st).also(player::setVideoSurface)
            }

            override fun onSurfaceTextureSizeChanged(st: SurfaceTexture, width: Int, height: Int) = Unit

            override fun onSurfaceTextureDestroyed(st: SurfaceTexture): Boolean {
                player.setVideoSurface(null)
                surface?.release()
                surface = null
                return true
            }

            override fun onSurfaceTextureUpdated(st: SurfaceTexture) {
                val now = System.nanoTime()
                if (lastFrameNanos != 0L) {
                    val gapMs = (now - lastFrameNanos) / 1_000_000.0
                    frameGapsMs.add(gapMs)
                    if (gapMs > worstFrameGapMs) {
                        worstFrameGapMs = gapMs
                        worstFrameGapAtMs = player.currentPosition
                    }
                }
                lastFrameNanos = now
            }
        }

        player.addAnalyticsListener(object : AnalyticsListener {
            override fun onDroppedVideoFrames(
                eventTime: AnalyticsListener.EventTime,
                dropped: Int,
                elapsedMs: Long,
            ) {
                droppedFrames += dropped
            }
        })

        player.addListener(object : Player.Listener {
            override fun onPositionDiscontinuity(
                oldPosition: Player.PositionInfo,
                newPosition: Player.PositionInfo,
                reason: Int,
            ) {
                if (reason == Player.DISCONTINUITY_REASON_AUTO_TRANSITION) {
                    channel.invokeMethod("onLoop", ++loopCount)
                }
            }

            override fun onVideoSizeChanged(videoSize: VideoSize) {
                if (videoSize.width > 0 && videoSize.height > 0) {
                    channel.invokeMethod("onVideoSize", listOf(videoSize.width, videoSize.height))
                }
            }
        })

        // REPEAT_MODE_ONE re-prepares the same media period at the wrap, which
        // measures ~66ms of stall per cycle. Queuing the clip as a playlist
        // instead routes every wrap through ExoPlayer's playlist transition,
        // which preloads the next period while the current one still plays.
        val mediaItem = MediaItem.fromUri(resolveAssetUri(source))
        if (usePlaylist) {
            player.setMediaItems(List(PLAYLIST_COPIES) { mediaItem })
            player.repeatMode = Player.REPEAT_MODE_ALL
            // Without this the next item is only prepared once the current one
            // ends, and the audio decoder pays a full restart at every wrap.
            player.preloadConfiguration =
                ExoPlayer.PreloadConfiguration(PRELOAD_TARGET_US)
        } else {
            player.setMediaItem(mediaItem)
            player.repeatMode = Player.REPEAT_MODE_ONE
        }
        if (nativeAudio != null) {
            // Audio leaves the player entirely — see PrototypePcmLoopTrack for why.
            player.trackSelectionParameters = player.trackSelectionParameters
                .buildUpon()
                .setTrackTypeDisabled(C.TRACK_TYPE_AUDIO, true)
                .build()
            pcmTrack = PrototypePcmLoopTrack(context, nativeAudio).also { it.play(muted) }
        }

        player.volume = if (muted) 0f else 1f
        player.playWhenReady = true
        player.prepare()

        startInstrumentation()
    }

    private fun startInstrumentation() {
        val callback = object : Choreographer.FrameCallback {
            override fun doFrame(frameTimeNanos: Long) {
                tick(frameTimeNanos)
                Choreographer.getInstance().postFrameCallback(this)
            }
        }
        frameCallback = callback
        Choreographer.getInstance().postFrameCallback(callback)
    }

    /**
     * Called once per vsync. [hostMs] is real time elapsed, [itemDelta] is how
     * far playback actually moved. When playback freezes the second stays near
     * zero while the first keeps counting.
     */
    private fun tick(frameTimeNanos: Long) {
        val item = player.currentPosition
        val previousItem = lastItemMs
        val previousTick = lastTickNanos
        lastItemMs = item
        lastTickNanos = frameTimeNanos

        if (previousTick == 0L) {
            cycleStartNanos = frameTimeNanos
            return
        }

        val hostMs = (frameTimeNanos - previousTick) / 1_000_000.0
        val itemDelta = (item - previousItem).toDouble()

        // Playback clock jumped backwards: the loop wrapped.
        if (itemDelta < -500) {
            val cycleMs = ((frameTimeNanos - cycleStartNanos) / 1_000_000.0).toInt()
            cycleStartNanos = frameTimeNanos
            val median = if (frameGapsMs.isEmpty()) 0 else {
                frameGapsMs.sorted()[frameGapsMs.size / 2].toInt()
            }
            channel.invokeMethod(
                "onCycle",
                listOf(
                    cycleMs,
                    worstStallMs.toInt(),
                    worstFrameGapMs.toInt(),
                    worstFrameGapAtMs.toInt(),
                    frameGapsMs.size + 1,
                    median,
                    droppedFrames,
                ),
            )
            frameGapsMs.clear()
            droppedFrames = 0
            worstStallMs = 0.0
            stallRunMs = 0.0
            worstFrameGapMs = 0.0
            worstFrameGapAtMs = 0L
            return
        }

        if (itemDelta < hostMs * 0.25) {
            stallRunMs += hostMs
            worstStallMs = maxOf(worstStallMs, stallRunMs)
        } else {
            stallRunMs = 0.0
        }
    }

    override fun getView(): View = textureView

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "setMuted" -> {
                val muted = call.arguments as? Boolean == true
                player.volume = if (muted) 0f else 1f
                pcmTrack?.setMuted(muted)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    override fun dispose() {
        frameCallback?.let(Choreographer.getInstance()::removeFrameCallback)
        frameCallback = null
        channel.setMethodCallHandler(null)
        pcmTrack?.release()
        pcmTrack = null
        player.release()
        surface?.release()
        surface = null
    }

}

/**
 * Flutter assets ship inside the APK, so hand ExoPlayer the `asset://` URI of
 * the bundle entry instead of unpacking the file to disk first.
 */
fun resolveAssetUri(source: String): Uri {
    if (!source.startsWith(ASSET_SCHEME)) return Uri.parse(source)

    val assetPath = source.removePrefix(ASSET_SCHEME)
    val key = FlutterInjector.instance().flutterLoader().getLookupKeyForAsset(assetPath)
    return Uri.parse("asset:///$key")
}

class PrototypeLoopPlayerViewFactory(
    private val messenger: BinaryMessenger,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val params = args as? Map<*, *> ?: emptyMap<String, Any>()
        // The prototype's dual-player variant is not copied over: it measured
        // no better there and is not what this comparison is about.
        return PrototypeLoopPlayerView(context, viewId, params, messenger)
    }
}
