package com.divinevideo.divine_video_player

import android.content.Context
import android.graphics.SurfaceTexture
import android.os.Handler
import android.view.Surface
import androidx.media3.common.PlaybackException
import androidx.media3.common.PlaybackParameters
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry
import io.mockk.clearMocks
import io.mockk.every
import io.mockk.just
import io.mockk.mockk
import io.mockk.mockkConstructor
import io.mockk.runs
import io.mockk.slot
import io.mockk.unmockkConstructor
import io.mockk.verify
import io.mockk.verifyOrder
import org.junit.Assert.assertEquals
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
    private lateinit var mockTextureEntry: TextureRegistry.SurfaceTextureEntry
    private lateinit var mockSurfaceTexture: SurfaceTexture
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
        mockTextureEntry = mockk(relaxed = true)
        mockSurfaceTexture = mockk(relaxed = true)

        every { mockRegistry.createSurfaceProducer() } returns mockProducer
        every { mockProducer.id() } returns 42L
        every { mockRegistry.createSurfaceTexture() } returns mockTextureEntry
        every { mockTextureEntry.surfaceTexture() } returns mockSurfaceTexture
        every { mockTextureEntry.id() } returns 99L

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
    fun `blobHashFromUrl extracts the hash from every blob variant URL`() {
        val hash = "a".repeat(64)
        assertEquals(hash, instance.blobHashFromUrl("https://media.divine.video/$hash"))
        assertEquals(
            hash,
            instance.blobHashFromUrl("https://media.divine.video/$hash/720p.mp4"),
        )
        assertEquals(
            hash,
            instance.blobHashFromUrl("https://media.divine.video/$hash/hls/master.m3u8"),
        )
        assertEquals(
            hash,
            instance.blobHashFromUrl("https://media.divine.video/$hash/hls/segment_1.ts"),
        )
        assertEquals(
            hash,
            instance.blobHashFromUrl("https://media.divine.video/$hash.mp4"),
        )
    }

    @Test
    fun `blobHashFromUrl returns null for non-blob URLs`() {
        assertEquals(null, instance.blobHashFromUrl("https://example.com/video.mp4"))
        assertEquals(
            null,
            instance.blobHashFromUrl("https://media.divine.video/notahash/720p.mp4"),
        )
    }

    // -- viewer auth header resolution (gated HLS, #4884 / #4897) --

    @Test
    fun `httpHeadersForRequest returns the viewer header for the exact clip URI`() {
        val url = "https://media.divine.video/${"a".repeat(64)}/720p.mp4"
        instance.onMethodCall(
            setClipsWithHeaders(url, mapOf("Authorization" to "Nostr token")),
            mockk(relaxed = true),
        )

        assertEquals(
            mapOf("Authorization" to "Nostr token"),
            instance.httpHeadersForRequest(url),
        )
    }

    @Test
    fun `httpHeadersForRequest authenticates HLS segments via the hash fallback`() {
        val hash = "a".repeat(64)
        instance.onMethodCall(
            setClipsWithHeaders(
                "https://media.divine.video/$hash/hls/master.m3u8",
                mapOf("Authorization" to "Nostr token"),
            ),
            mockk(relaxed = true),
        )

        // A media segment lives under the same blob hash but at a different URI;
        // it must resolve the same viewer-auth header (the #4884 fix) so gated
        // HLS playback authenticates end-to-end.
        assertEquals(
            mapOf("Authorization" to "Nostr token"),
            instance.httpHeadersForRequest(
                "https://media.divine.video/$hash/hls/segment_1.ts",
            ),
        )
    }

    @Test
    fun `httpHeadersForRequest returns empty for a URL outside the gated blob`() {
        val hash = "a".repeat(64)
        instance.onMethodCall(
            setClipsWithHeaders(
                "https://media.divine.video/$hash/720p.mp4",
                mapOf("Authorization" to "Nostr token"),
            ),
            mockk(relaxed = true),
        )

        assertEquals(
            emptyMap<String, String>(),
            instance.httpHeadersForRequest("https://cdn.example.com/other.ts"),
        )
    }

    @Test
    fun `httpHeadersForRequest returns empty for a different, unregistered blob hash`() {
        instance.onMethodCall(
            setClipsWithHeaders(
                "https://media.divine.video/${"a".repeat(64)}/720p.mp4",
                mapOf("Authorization" to "Nostr token"),
            ),
            mockk(relaxed = true),
        )

        // A valid 64-hex hash that was never registered must NOT inherit another
        // blob's viewer header. Unlike the miss above (the URL parses to no hash),
        // this hits the hash-miss branch: blobHashFromUrl succeeds but the hash is
        // absent from httpHeadersByHash, so it falls through to emptyMap().
        assertEquals(
            emptyMap<String, String>(),
            instance.httpHeadersForRequest(
                "https://media.divine.video/${"b".repeat(64)}/hls/segment_1.ts",
            ),
        )
    }

    private fun setClipsWithHeaders(
        uri: String,
        httpHeaders: Map<String, String>,
    ): MethodCall =
        MethodCall(
            "setClips",
            mapOf(
                "clips" to listOf(
                    mapOf(
                        "uri" to uri,
                        "startMs" to 0,
                        "endMs" to 1000,
                        "httpHeaders" to httpHeaders,
                    ),
                ),
            ),
        )

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

    @Test
    fun `enableTextureOutput true uses createSurfaceTexture not createSurfaceProducer`() {
        mockkConstructor(Surface::class)
        try {
            val textureId = instance.enableTextureOutput(
                mockRegistry,
                useLegacySurface = true,
            )

            verify(exactly = 1) { mockRegistry.createSurfaceTexture() }
            verify(exactly = 0) { mockRegistry.createSurfaceProducer() }
            verify(exactly = 1) { mockTextureEntry.surfaceTexture() }
            assertEquals(99L, textureId)
        } finally {
            unmockkConstructor(Surface::class)
        }
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

        listener.onMediaItemTransition(null, Player.MEDIA_ITEM_TRANSITION_REASON_PLAYLIST_CHANGED)

        verify(exactly = 0) { mockPlayer.setVideoSurface(any()) }
    }

    // -- setClips async completion contract --

    private fun setClipsCall(uri: String = "file:///tmp/a.mp4"): MethodCall =
        MethodCall(
            "setClips",
            mapOf(
                "clips" to listOf(
                    mapOf("uri" to uri, "startMs" to 0, "endMs" to 1000),
                ),
            ),
        )

    @Test
    fun `setClips holds Dart result until STATE_READY then completes with success`() {
        val listener = capturePlayerListener()
        val result = mockk<MethodChannel.Result>(relaxed = true)

        instance.onMethodCall(setClipsCall(), result)

        // Result must NOT have completed yet — STATE_READY hasn't fired.
        verify(exactly = 0) { result.success(any()) }
        verify(exactly = 0) { result.error(any(), any(), any()) }

        listener.onPlaybackStateChanged(Player.STATE_READY)

        verify(exactly = 1) { result.success(null) }
    }

    @Test
    fun `onPlayerError completes pending setClips result with error`() {
        val listener = capturePlayerListener()
        val result = mockk<MethodChannel.Result>(relaxed = true)
        instance.onMethodCall(setClipsCall(), result)

        val error = mockk<PlaybackException>(relaxed = true)
        every { error.message } returns "boom"
        listener.onPlayerError(error)

        verify(exactly = 1) { result.error("PLAYER_ERROR", "boom", null) }
        verify(exactly = 0) { result.success(any()) }
    }

    @Test
    fun `superseding setClips completes the previous result with CANCELLED`() {
        capturePlayerListener()
        val first = mockk<MethodChannel.Result>(relaxed = true)
        val second = mockk<MethodChannel.Result>(relaxed = true)

        instance.onMethodCall(setClipsCall("file:///tmp/a.mp4"), first)
        instance.onMethodCall(setClipsCall("file:///tmp/b.mp4"), second)

        verify(exactly = 1) {
            first.error("CANCELLED", "Superseded by newer setClips call", null)
        }
        verify(exactly = 0) { first.success(any()) }
        verify(exactly = 0) { second.success(any()) }
    }

    @Test
    fun `dispose completes pending setClips result so Dart is not left hanging`() {
        capturePlayerListener()
        val result = mockk<MethodChannel.Result>(relaxed = true)
        instance.onMethodCall(setClipsCall(), result)

        instance.dispose()

        verify(exactly = 1) { result.success(null) }
    }

    // -- seekTo per-clip speed --

    /**
     * Regression test for the seek-backward speed bug:
     * Clip 0 at 3× (source 3 s → 1 s on the timeline),
     * clip 1 at 0.25× (source 4 s → 16 s on the timeline).
     *
     * After setClips the player is at clip 0.  When the user seeks to a
     * position inside clip 0 the player must apply clip 0's speed (3×),
     * NOT whatever speed was last active before the seek.
     */
    @Test
    fun `seekTo applies the target clip speed so seeking backward from slow clip restores fast clip speed`() {
        capturePlayerListener()

        // Clip 0: 3 s source at 3× → 1 000 ms of playback timeline (offset 0..1000).
        // Clip 1: 4 s source at 0.25× → 16 000 ms of playback timeline (offset 1000..17000).
        instance.onMethodCall(
            MethodCall(
                "setClips",
                mapOf(
                    "clips" to listOf(
                        mapOf(
                            "uri" to "file:///a.mp4",
                            "startMs" to 0,
                            "endMs" to 3000,
                            "playbackSpeed" to 3.0,
                        ),
                        mapOf(
                            "uri" to "file:///b.mp4",
                            "startMs" to 0,
                            "endMs" to 4000,
                            "playbackSpeed" to 0.25,
                        ),
                    ),
                ),
            ),
            mockk(relaxed = true),
        )

        // Discard calls made by setClips so only the seekTo invocation is verified.
        clearMocks(mockPlayer, answers = false, recordedCalls = true)

        // Seek to global 500 ms → resolves to clip 0 (offset range 0–1000 ms).
        instance.onMethodCall(
            MethodCall("seekTo", mapOf("positionMs" to 500)),
            mockk(relaxed = true),
        )

        // Clip 0's speed (3×) must be applied.
        verify { mockPlayer.setPlaybackParameters(PlaybackParameters(3.0f)) }
        // Clip 1's speed must NOT be applied.
        verify(exactly = 0) { mockPlayer.setPlaybackParameters(PlaybackParameters(0.25f)) }
    }
}
