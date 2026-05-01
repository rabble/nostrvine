package com.divinevideo.divine_video_player

import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.PlayerView
import io.mockk.Runs
import io.mockk.every
import io.mockk.just
import io.mockk.mockk
import io.mockk.verify
import io.mockk.verifyOrder
import org.junit.Before
import org.junit.Test

/**
 * Pins the order [DivineVideoPlayerPlatformView.dispose] uses to tear down the
 * Media3 PlayerView: stop the decoder, clear the surface, then null the
 * PlayerView's player reference. Matches the brainstorm's prescribed order and
 * stays consistent with `DivineVideoPlayerInstance.dispose`.
 */
class DivineVideoPlayerViewFactoryTest {

    private lateinit var mockPlayer: ExoPlayer
    private lateinit var mockPlayerView: PlayerView

    @Before
    fun setUp() {
        mockPlayer = mockk(relaxed = true)
        mockPlayerView = mockk(relaxed = true)
        every { mockPlayerView.player } returns mockPlayer
        every { mockPlayerView.player = any() } just Runs
    }

    @Test
    fun `PlatformView dispose stops player, clears surface, then nulls PlayerView player (in order)`() {
        val view = DivineVideoPlayerPlatformView(mockPlayerView)

        view.dispose()

        verifyOrder {
            mockPlayer.stop()
            mockPlayer.clearVideoSurface()
            mockPlayerView.player = null
        }
    }

    @Test
    fun `PlatformView dispose does not release the player`() {
        val view = DivineVideoPlayerPlatformView(mockPlayerView)

        view.dispose()

        verify(exactly = 0) { mockPlayer.release() }
    }

    @Test
    fun `PlatformView dispose is safe when player is null`() {
        every { mockPlayerView.player } returns null
        val view = DivineVideoPlayerPlatformView(mockPlayerView)

        // Should not throw.
        view.dispose()

        verify(exactly = 0) { mockPlayer.stop() }
        verify(exactly = 0) { mockPlayer.clearVideoSurface() }
    }
}
