package com.divinevideo.divine_video_player

import android.content.Context
import android.os.Handler
import android.view.Surface
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.view.TextureRegistry
import io.mockk.clearMocks
import io.mockk.every
import io.mockk.just
import io.mockk.mockk
import io.mockk.runs
import io.mockk.slot
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
    private lateinit var mockRegistry: TextureRegistry
    private lateinit var mockProducer: TextureRegistry.SurfaceProducer
    private lateinit var mockSurface: Surface
    private lateinit var instance: DivineVideoPlayerInstance

    @Before
    fun setUp() {
        messenger = mockk(relaxed = true)
        context = mockk(relaxed = true)
        mockPlayer = mockk(relaxed = true)
        mockHandler = mockk(relaxed = true)
        mockAudioManager = mockk(relaxed = true)
        mockRegistry = mockk(relaxed = true)
        mockProducer = mockk(relaxed = true)
        mockSurface = mockk(relaxed = true)

        every { mockRegistry.createSurfaceProducer() } returns mockProducer
        every { mockProducer.id() } returns 42L

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

    // -- SurfaceProducer.Callback contract --

    @Test
    fun `onSurfaceAvailable attaches surface to player and clears needsSurface`() {
        // Start with a null surface so enableTextureOutput leaves needsSurface = true.
        every { mockProducer.surface } returns null
        instance.enableTextureOutput(mockRegistry)

        // Surface becomes available; simulate the callback firing with the real surface.
        every { mockProducer.surface } returns mockSurface
        materializePlayer()

        // onSurfaceCleanup + onSurfaceAvailable cycle.
        instance.onSurfaceCleanup()
        instance.onSurfaceAvailable()

        verify { mockPlayer.setVideoSurface(mockSurface) }
        // A second onSurfaceAvailable must be a no-op (needsSurface is now false).
        clearMocks(mockPlayer, answers = false, recordedCalls = true)
        instance.onSurfaceAvailable()
        verify(exactly = 0) { mockPlayer.setVideoSurface(any()) }
    }

    @Test
    fun `onSurfaceAvailable leaves needsSurface true when player has not been created`() {
        // Surface is null at enableTextureOutput time → needsSurface = true.
        every { mockProducer.surface } returns null
        instance.enableTextureOutput(mockRegistry)

        // Surface now available, but player still null.
        every { mockProducer.surface } returns mockSurface
        instance.onSurfaceAvailable()

        // No setVideoSurface call — player doesn't exist yet.
        verify(exactly = 0) { mockPlayer.setVideoSurface(any()) }

        // needsSurface must still be true: ensurePlayer() should attach the surface
        // when the player is eventually created.
        materializePlayer()
        verify { mockPlayer.setVideoSurface(mockSurface) }
    }

    @Test
    fun `onSurfaceCleanup detaches surface from player and raises needsSurface`() {
        every { mockProducer.surface } returns mockSurface
        instance.enableTextureOutput(mockRegistry)
        materializePlayer()

        instance.onSurfaceCleanup()

        verify { mockPlayer.setVideoSurface(null) }
        // needsSurface is now true: onSurfaceAvailable should reattach.
        instance.onSurfaceAvailable()
        verify { mockPlayer.setVideoSurface(mockSurface) }
    }

    @Test
    fun `onSurfaceCleanup raises needsSurface even when player is null`() {
        every { mockProducer.surface } returns null
        instance.enableTextureOutput(mockRegistry)
        // Player never materialised — setVideoSurface(null) is a no-op via ?.

        instance.onSurfaceCleanup()

        // Surface becomes available and then the player is created.
        every { mockProducer.surface } returns mockSurface
        materializePlayer()
        // ensurePlayer() must attach because needsSurface was left true.
        verify { mockPlayer.setVideoSurface(mockSurface) }
    }

    // -- onMediaItemTransition detach/reattach --

    private fun capturePlayerListener(): Player.Listener {
        val slot = slot<Player.Listener>()
        every { mockPlayer.addListener(capture(slot)) } just runs
        materializePlayer()
        return slot.captured
    }

    @Test
    fun `MEDIA_ITEM_TRANSITION_REASON_AUTO forces surface detach then reattach`() {
        every { mockProducer.surface } returns mockSurface
        instance.enableTextureOutput(mockRegistry)
        val listener = capturePlayerListener()

        listener.onMediaItemTransition(null, Player.MEDIA_ITEM_TRANSITION_REASON_AUTO)

        verifyOrder {
            mockPlayer.setVideoSurface(null)
            mockPlayer.setVideoSurface(mockSurface)
        }
    }

    @Test
    fun `MEDIA_ITEM_TRANSITION_REASON_AUTO is skipped when surface is not yet attached`() {
        // Surface null during enableTextureOutput → needsSurface = true.
        every { mockProducer.surface } returns null
        instance.enableTextureOutput(mockRegistry)
        every { mockProducer.surface } returns mockSurface
        val listener = capturePlayerListener()
        // ensurePlayer attached the surface (needsSurface = false). Force the flag
        // back to true by calling onSurfaceCleanup to simulate a surface loss before
        // the auto-transition fires.
        instance.onSurfaceCleanup()
        // Clear calls recorded during setup so the assertion only covers the
        // onMediaItemTransition invocation below.
        clearMocks(mockPlayer, answers = false, recordedCalls = true)

        listener.onMediaItemTransition(null, Player.MEDIA_ITEM_TRANSITION_REASON_AUTO)

        // setVideoSurface(null) must NOT be called — needsSurface is true, meaning
        // no surface is currently attached for ExoPlayer to lose.
        verify(exactly = 0) { mockPlayer.setVideoSurface(null) }
    }

    @Test
    fun `non-auto media item transition does not detach or reattach surface`() {
        every { mockProducer.surface } returns mockSurface
        instance.enableTextureOutput(mockRegistry)
        val listener = capturePlayerListener()
        // Clear calls recorded during setup (ensurePlayer → setVideoSurface(surface))
        // so the assertion only covers the onMediaItemTransition invocation below.
        clearMocks(mockPlayer, answers = false, recordedCalls = true)

        listener.onMediaItemTransition(null, Player.MEDIA_ITEM_TRANSITION_REASON_PLAYLIST_CHANGED)

        verify(exactly = 0) { mockPlayer.setVideoSurface(any()) }
    }
}
