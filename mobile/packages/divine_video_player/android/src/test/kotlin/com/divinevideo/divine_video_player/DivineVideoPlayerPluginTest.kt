package com.divinevideo.divine_video_player

import io.mockk.mockk
import io.mockk.verify
import org.junit.After
import org.junit.Test

/**
 * Pins the activity-teardown contract: when the Activity detaches, every live
 * player is stopped (no new frames produced into the renderer) but NOT released —
 * full release stays on engine detach so configuration-free destroys can fall
 * through to `onDetachedFromEngine`.
 */
class DivineVideoPlayerPluginTest {

    @After
    fun tearDown() {
        // PlayerRegistry is an internal singleton; reset between tests.
        // dispose() on relaxed mocks is a no-op.
        PlayerRegistry.disposeAll()
    }

    @Test
    fun `onDetachedFromActivity invokes stopForActivityDetach on every registered player`() {
        val plugin = DivineVideoPlayerPlugin()
        val instanceA = mockk<DivineVideoPlayerInstance>(relaxed = true)
        val instanceB = mockk<DivineVideoPlayerInstance>(relaxed = true)
        PlayerRegistry.put(1, instanceA)
        PlayerRegistry.put(2, instanceB)

        plugin.onDetachedFromActivity()

        verify { instanceA.stopForActivityDetach() }
        verify { instanceB.stopForActivityDetach() }
    }

    @Test
    fun `onDetachedFromActivity does not release any player`() {
        val plugin = DivineVideoPlayerPlugin()
        val instanceA = mockk<DivineVideoPlayerInstance>(relaxed = true)
        PlayerRegistry.put(1, instanceA)

        plugin.onDetachedFromActivity()

        verify(exactly = 0) { instanceA.dispose() }
    }

    @Test
    fun `onDetachedFromActivity is a no-op when no players are registered`() {
        val plugin = DivineVideoPlayerPlugin()

        // Should not throw.
        plugin.onDetachedFromActivity()
    }
}
