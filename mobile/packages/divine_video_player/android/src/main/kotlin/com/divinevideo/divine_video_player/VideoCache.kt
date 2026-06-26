package com.divinevideo.divine_video_player

import android.content.Context
import android.net.Uri
import androidx.media3.common.C
import androidx.media3.common.util.UnstableApi
import androidx.media3.database.StandaloneDatabaseProvider
import androidx.media3.datasource.DataSource
import androidx.media3.datasource.DefaultDataSource
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.datasource.DataSpec
import androidx.media3.datasource.TransferListener
import androidx.media3.datasource.cache.CacheDataSource
import androidx.media3.datasource.cache.LeastRecentlyUsedCacheEvictor
import androidx.media3.datasource.cache.SimpleCache
import java.io.File

/**
 * Singleton managing ExoPlayer's disk-backed [SimpleCache].
 *
 * Initialised once via [configure] at app startup. All player instances
 * share the same cache directory and eviction policy.
 *
 * When configured, [dataSourceFactory] returns a [CacheDataSource.Factory]
 * that reads from cache first and fills it progressively on cache misses.
 * When **not** configured, it falls back to a plain [DefaultDataSource.Factory].
 */
@UnstableApi
internal object VideoCache {

    private var cache: SimpleCache? = null
    private var cacheDataSourceFactory: CacheDataSource.Factory? = null

    /** Whether [configure] has been called successfully. */
    val isConfigured: Boolean get() = cache != null

    /**
     * Initialises the shared cache.
     *
     * @param context  Application context (used for the cache dir and
     *                 database provider).
     * @param maxSizeBytes  Maximum size of the LRU disk cache in bytes.
     */
    @Synchronized
    fun configure(context: Context, maxSizeBytes: Long) {
        // Avoid re-creating if already initialised.
        if (cache != null) return

        val cacheDir = File(context.cacheDir, "divine_video_cache")
        val evictor = LeastRecentlyUsedCacheEvictor(maxSizeBytes)
        val databaseProvider = StandaloneDatabaseProvider(context)

        cache = SimpleCache(cacheDir, evictor, databaseProvider)

        cacheDataSourceFactory = CacheDataSource.Factory()
            .setCache(cache!!)
            .setUpstreamDataSourceFactory(upstreamFactory(context))
            // Read from cache first, fill progressively on miss.
            .setFlags(CacheDataSource.FLAG_IGNORE_CACHE_ON_ERROR)
    }

    /**
     * Returns a [DataSource.Factory] that hits the cache when available,
     * or a plain [DefaultDataSource.Factory] if the cache has not been
     * configured.
     */
    fun dataSourceFactory(
        context: Context,
        httpHeadersForUri: (Uri) -> Map<String, String> = { emptyMap() },
    ): DataSource.Factory {
        val cachedFactory = cacheDataSourceFactory ?: upstreamFactory(context)
        val uncachedFactory = upstreamFactory(context)
        return DataSource.Factory {
            AuthAwareCacheBypassDataSource(
                cachedFactory = cachedFactory,
                uncachedFactory = uncachedFactory,
                httpHeadersForUri = httpHeadersForUri,
            )
        }
    }

    private fun upstreamFactory(context: Context): DataSource.Factory {
        val httpDataSourceFactory = DefaultHttpDataSource.Factory()
            .setAllowCrossProtocolRedirects(true)
        return DefaultDataSource.Factory(context, httpDataSourceFactory)
    }

    /** Releases the cache. Called on engine detach. */
    @Synchronized
    fun release() {
        cache?.release()
        cache = null
        cacheDataSourceFactory = null
    }
}

internal class AuthAwareCacheBypassDataSource(
    private val cachedFactory: DataSource.Factory,
    private val uncachedFactory: DataSource.Factory,
    private val httpHeadersForUri: (Uri) -> Map<String, String>,
) : DataSource {

    private val transferListeners = mutableListOf<TransferListener>()
    private var delegate: DataSource? = null

    override fun addTransferListener(transferListener: TransferListener) {
        transferListeners += transferListener
        delegate?.addTransferListener(transferListener)
    }

    override fun open(dataSpec: DataSpec): Long {
        val httpHeaders = httpHeadersForUri(dataSpec.uri)
        val resolvedDataSpec = if (httpHeaders.isEmpty()) {
            dataSpec
        } else {
            // Authenticated age-gated responses are served no-store by the
            // origin. Attach the viewer auth headers but bypass SimpleCache so
            // those private bytes are not persisted on disk.
            dataSpec.withRequestHeaders(dataSpec.httpRequestHeaders + httpHeaders)
        }
        val selectedDelegate = if (httpHeaders.isEmpty()) {
            cachedFactory.createDataSource()
        } else {
            uncachedFactory.createDataSource()
        }
        transferListeners.forEach(selectedDelegate::addTransferListener)
        delegate = selectedDelegate
        return selectedDelegate.open(resolvedDataSpec)
    }

    override fun read(buffer: ByteArray, offset: Int, length: Int): Int {
        return delegate?.read(buffer, offset, length) ?: C.RESULT_END_OF_INPUT
    }

    override fun getUri(): Uri? = delegate?.uri

    override fun getResponseHeaders(): Map<String, List<String>> {
        return delegate?.responseHeaders ?: emptyMap()
    }

    override fun close() {
        delegate?.close()
        delegate = null
    }
}
