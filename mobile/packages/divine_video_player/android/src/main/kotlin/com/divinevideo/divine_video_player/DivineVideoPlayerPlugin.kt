package com.divinevideo.divine_video_player

import android.app.Activity
import android.content.Context
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Entry point for the divine_video_player plugin on Android.
 *
 * Manages the lifecycle of [DivineVideoPlayerInstance] objects and
 * registers the platform view factory for rendering.
 */
class DivineVideoPlayerPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {

    private lateinit var globalChannel: MethodChannel
    private lateinit var binding: FlutterPlugin.FlutterPluginBinding

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        binding = flutterPluginBinding

        // Hot restart re-calls onAttachedToEngine without a preceding
        // onDetachedFromEngine. Dispose any leftover players so zombie
        // timers and event channels are cleaned up.
        PlayerRegistry.disposeAll()

        globalChannel = MethodChannel(
            flutterPluginBinding.binaryMessenger,
            "divine_video_player",
        )
        globalChannel.setMethodCallHandler(this)

        flutterPluginBinding.platformViewRegistry.registerViewFactory(
            "divine_video_player_view",
            DivineVideoPlayerViewFactory(flutterPluginBinding),
        )
    }

    override fun onDetachedFromEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        globalChannel.setMethodCallHandler(null)
        PlayerRegistry.disposeAll()
        VideoCache.release()
    }

    // -- ActivityAware: pause/resume players with app lifecycle --

    private val lifecycleObserver = object : DefaultLifecycleObserver {
        override fun onPause(owner: LifecycleOwner) {
            PlayerRegistry.forAll { it.onAppBackgrounded() }
        }

        override fun onResume(owner: LifecycleOwner) {
            PlayerRegistry.forAll { it.onAppForegrounded() }
        }
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        (binding.activity as? LifecycleOwner)?.lifecycle?.addObserver(lifecycleObserver)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        // No-op: observer is removed when activity is destroyed.
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        (binding.activity as? LifecycleOwner)?.lifecycle?.addObserver(lifecycleObserver)
    }

    override fun onDetachedFromActivity() {
        // Lifecycle observer is auto-removed when the lifecycle is destroyed.
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "create" -> {
                val id = call.argument<Int>("id")!!
                // Dispose any existing player with the same ID BEFORE
                // creating the new one. The new instance registers
                // MethodChannel/EventChannel handlers under the same
                // channel name, so the old instance must release them
                // first to avoid nullifying the new handlers.
                PlayerRegistry.remove(id)?.dispose()
                val instance = DivineVideoPlayerInstance(
                    binding.binaryMessenger,
                    binding.applicationContext,
                    id,
                )
                PlayerRegistry.put(id, instance)

                val useTexture = call.argument<Boolean>("useTexture") ?: false
                if (useTexture) {
                    val textureId = instance.enableTextureOutput(
                        binding.textureRegistry,
                    )
                    result.success(mapOf("textureId" to textureId))
                } else {
                    result.success(null)
                }
            }
            "dispose" -> {
                val id = call.argument<Int>("id")!!
                PlayerRegistry.remove(id)?.dispose()
                result.success(null)
            }
            "preload" -> {
                handlePreload(call, result)
            }
            "configureCache" -> {
                val maxSizeBytes = (call.argument<Number>("maxSizeBytes"))?.toLong()
                    ?: (500L * 1024 * 1024)
                VideoCache.configure(binding.applicationContext, maxSizeBytes)
                result.success(null)
            }
            "disposeAll" -> {
                PlayerRegistry.disposeAll()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    /**
     * Preloads video metadata and initial buffer data by creating a
     * temporary ExoPlayer, preparing the media, and releasing it once
     * ready. The OS-level network/disk cache retains the buffered data
     * so that a real player starts faster.
     */
    private fun handlePreload(call: MethodCall, result: MethodChannel.Result) {
        val clipsRaw = call.argument<List<Map<String, Any?>>>("clips")
        if (clipsRaw.isNullOrEmpty()) {
            result.success(null)
            return
        }

        val context: Context = binding.applicationContext
        val preloadPlayer = ExoPlayer.Builder(context)
            .setMediaSourceFactory(
                DefaultMediaSourceFactory(VideoCache.dataSourceFactory(context)),
            )
            .build()

        val mediaItems = clipsRaw.mapNotNull { map ->
            val uri = map["uri"] as? String ?: return@mapNotNull null
            val startMs = (map["startMs"] as? Number)?.toLong() ?: 0L
            val endMs = (map["endMs"] as? Number)?.toLong()

            MediaItem.Builder().setUri(uri)
                .setClippingConfiguration(
                    MediaItem.ClippingConfiguration.Builder()
                        .setStartPositionMs(startMs)
                        .apply { if (endMs != null) setEndPositionMs(endMs) }
                        .build(),
                )
                .build()
        }

        if (mediaItems.isEmpty()) {
            preloadPlayer.release()
            result.success(null)
            return
        }

        preloadPlayer.addListener(object : Player.Listener {
            override fun onPlaybackStateChanged(playbackState: Int) {
                if (playbackState == Player.STATE_READY ||
                    playbackState == Player.STATE_IDLE
                ) {
                    preloadPlayer.release()
                    result.success(null)
                }
            }

            override fun onPlayerError(error: androidx.media3.common.PlaybackException) {
                preloadPlayer.release()
                result.success(null)
            }
        })

        preloadPlayer.setMediaItems(mediaItems)
        preloadPlayer.prepare()
    }
}

/**
 * Global registry so that [DivineVideoPlayerViewFactory] can find
 * instances created by [DivineVideoPlayerPlugin].
 */
internal object PlayerRegistry {
    private val players = mutableMapOf<Int, DivineVideoPlayerInstance>()

    fun get(id: Int): DivineVideoPlayerInstance? = players[id]
    fun put(id: Int, instance: DivineVideoPlayerInstance) { players[id] = instance }
    fun remove(id: Int): DivineVideoPlayerInstance? = players.remove(id)
    fun forAll(action: (DivineVideoPlayerInstance) -> Unit) {
        players.values.forEach(action)
    }
    fun disposeAll() {
        players.values.forEach { it.dispose() }
        players.clear()
    }
}
