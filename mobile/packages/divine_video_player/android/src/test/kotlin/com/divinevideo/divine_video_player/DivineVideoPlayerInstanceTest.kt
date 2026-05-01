package com.divinevideo.divine_video_player

import android.content.Context
import android.os.Handler
import androidx.media3.exoplayer.ExoPlayer
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.mockk.mockk
import io.mockk.verify
import io.mockk.verifyOrder
import org.junit.Before
import org.junit.Test

/**
 * Pins the disposal contract of [DivineVideoPlayerInstance] — call ordering is the
 * load-bearing behavior of the #3416 fix, and this test exists so a future refactor
 * of `dispose()` cannot silently revert any of stop / clearVideoSurface / release.
 *
 * The Instance has tight Android-framework coupling (Handler/Looper, AudioOverlayManager
 * with internal ExoPlayers); rather than mock framework classes, we use the injected
 * factories the production constructor exposes.
 */
class DivineVideoPlayerInstanceTest {

    private lateinit var messenger: BinaryMessenger
    private lateinit var context: Context
    private lateinit var mockPlayer: ExoPlayer
    private lateinit var mockHandler: Handler
    private lateinit var mockAudioManager: AudioOverlayManager
    private lateinit var instance: DivineVideoPlayerInstance

    @Before
    fun setUp() {
        messenger = mockk(relaxed = true)
        context = mockk(relaxed = true)
        mockPlayer = mockk(relaxed = true)
        mockHandler = mockk(relaxed = true)
        mockAudioManager = mockk(relaxed = true)

        instance = DivineVideoPlayerInstance(
            messenger = messenger,
            context = context,
            playerId = 1,
            playerFactory = { _ -> mockPlayer },
            mainHandler = mockHandler,
            audioOverlayManagerFactory = { _ -> mockAudioManager },
        )
    }

    /**
     * Forces lazy [ExoPlayer] creation by routing a `play` call through the public
     * MethodChannel handler — the same path production uses.
     */
    private fun materializePlayer() {
        instance.onMethodCall(MethodCall("play", null), mockk(relaxed = true))
    }

    @Test
    fun `dispose removes listener, stops decoder, clears surface, then releases (in order)`() {
        materializePlayer()

        instance.dispose()

        verifyOrder {
            mockPlayer.removeListener(any())
            mockPlayer.stop()
            mockPlayer.clearVideoSurface()
            mockPlayer.release()
        }
    }

    @Test
    fun `dispose is a no-op on the player when player was never materialized`() {
        // Do NOT materialize — player is null.
        instance.dispose()

        verify(exactly = 0) { mockPlayer.stop() }
        verify(exactly = 0) { mockPlayer.clearVideoSurface() }
        verify(exactly = 0) { mockPlayer.release() }
    }

    @Test
    fun `stopForActivityDetach stops decoder and clears surface but does not release`() {
        materializePlayer()

        instance.stopForActivityDetach()

        verifyOrder {
            mockPlayer.stop()
            mockPlayer.clearVideoSurface()
        }
        verify(exactly = 0) { mockPlayer.release() }
    }

    @Test
    fun `stopForActivityDetach pauses audio overlays for symmetry with onAppBackgrounded`() {
        materializePlayer()

        instance.stopForActivityDetach()

        verify { mockAudioManager.pauseAll() }
    }

    @Test
    fun `stopForActivityDetach is safe when player was never materialized`() {
        instance.stopForActivityDetach()

        verify(exactly = 0) { mockPlayer.stop() }
        verify(exactly = 0) { mockPlayer.clearVideoSurface() }
        // Audio overlay pause still runs — the method is also responsible for
        // muting any orphaned overlay even when no main player exists.
        verify { mockAudioManager.pauseAll() }
    }
}
