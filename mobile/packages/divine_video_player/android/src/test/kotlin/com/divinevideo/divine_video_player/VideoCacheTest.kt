package com.divinevideo.divine_video_player

import android.net.Uri
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DataSource
import androidx.media3.datasource.DataSpec
import io.mockk.every
import io.mockk.mockk
import io.mockk.slot
import io.mockk.verify
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the transport contract of [AuthAwareCacheBypassDataSource]: gated
 * (viewer-authenticated) requests attach the auth header AND bypass the disk
 * cache so private bytes are never persisted, while anonymous requests use the
 * cache and add no headers. This is the per-request half of the gated-HLS fix
 * (#4884 / #4897) — the resolver runs on every `open()`, so HLS media segments
 * authenticate alongside the master manifest.
 */
@UnstableApi
class VideoCacheTest {

    private val authHeaders = mapOf("Authorization" to "Nostr token")

    private fun dataSpec(): DataSpec =
        DataSpec.Builder().setUri(mockk<Uri>(relaxed = true)).build()

    @Test
    fun `open attaches viewer headers and bypasses the cache for gated content`() {
        val cachedDelegate = mockk<DataSource>(relaxed = true)
        val uncachedDelegate = mockk<DataSource>(relaxed = true)
        val cachedFactory = mockk<DataSource.Factory> {
            every { createDataSource() } returns cachedDelegate
        }
        val uncachedFactory = mockk<DataSource.Factory> {
            every { createDataSource() } returns uncachedDelegate
        }
        val openedSpec = slot<DataSpec>()
        every { uncachedDelegate.open(capture(openedSpec)) } returns 0L

        val source = AuthAwareCacheBypassDataSource(
            cachedFactory = cachedFactory,
            uncachedFactory = uncachedFactory,
            httpHeadersForUri = { authHeaders },
        )

        source.open(dataSpec())

        // Gated content must NOT touch the disk cache (no-store private bytes)...
        verify(exactly = 1) { uncachedFactory.createDataSource() }
        verify(exactly = 0) { cachedFactory.createDataSource() }
        // ...and the viewer-auth header must ride on the request.
        assertEquals(
            "Nostr token",
            openedSpec.captured.httpRequestHeaders["Authorization"],
        )
    }

    @Test
    fun `open uses the cache and adds no headers for anonymous content`() {
        val cachedDelegate = mockk<DataSource>(relaxed = true)
        val uncachedDelegate = mockk<DataSource>(relaxed = true)
        val cachedFactory = mockk<DataSource.Factory> {
            every { createDataSource() } returns cachedDelegate
        }
        val uncachedFactory = mockk<DataSource.Factory> {
            every { createDataSource() } returns uncachedDelegate
        }
        val openedSpec = slot<DataSpec>()
        every { cachedDelegate.open(capture(openedSpec)) } returns 0L

        val source = AuthAwareCacheBypassDataSource(
            cachedFactory = cachedFactory,
            uncachedFactory = uncachedFactory,
            httpHeadersForUri = { emptyMap() },
        )

        source.open(dataSpec())

        verify(exactly = 1) { cachedFactory.createDataSource() }
        verify(exactly = 0) { uncachedFactory.createDataSource() }
        assertTrue(openedSpec.captured.httpRequestHeaders.isEmpty())
    }
}
