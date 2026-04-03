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
    context: Context,
    playerId: Int,
) : PlatformView {

    private val playerView: PlayerView = PlayerView(context).apply {
        useController = false
        val instance = PlayerRegistry.get(playerId)
        player = instance?.getPlayer()
    }

    override fun getView(): View = playerView

    override fun dispose() {
        playerView.player = null
    }
}
