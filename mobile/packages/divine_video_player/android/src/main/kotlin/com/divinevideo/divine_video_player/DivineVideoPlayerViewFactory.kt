package com.divinevideo.divine_video_player

import android.content.Context
import android.view.View
import androidx.media3.ui.PlayerView
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/**
 * Factory that creates [DivineVideoPlayerPlatformView] instances
 * for the Flutter platform view system.
 *
 * Each view looks up the [DivineVideoPlayerInstance] by the
 * `playerId` passed in the creation parameters, and attaches its
 * ExoPlayer to a [PlayerView].
 */
internal class DivineVideoPlayerViewFactory(
    private val binding: FlutterPlugin.FlutterPluginBinding,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val params = args as? Map<*, *>
        val playerId = (params?.get("playerId") as? Number)?.toInt() ?: -1
        return DivineVideoPlayerPlatformView(context, playerId)
    }
}

/**
 * Android [PlatformView] that renders video via Media3's [PlayerView].
 */
internal class DivineVideoPlayerPlatformView(
    private val playerView: PlayerView,
) : PlatformView {

    constructor(context: Context, playerId: Int) : this(
        PlayerView(context).apply {
            useController = false
            val instance = PlayerRegistry.get(playerId)
            player = instance?.getPlayer()
        },
    )

    override fun getView(): View = playerView

    override fun dispose() {
        // Stop decoder before the PlatformView's ImageReader is torn down;
        // narrows the window where an in-flight frame can land in a
        // detaching ImageReaderSurfaceProducer. See #3416.
        val player = playerView.player
        player?.let {
            it.stop()
            it.clearVideoSurface()
        }
        playerView.player = null
    }
}
