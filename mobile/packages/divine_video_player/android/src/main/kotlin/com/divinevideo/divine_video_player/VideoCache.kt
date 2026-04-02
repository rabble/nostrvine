package com.divinevideo.divine_video_player

import android.content.Context
import androidx.media3.database.StandaloneDatabaseProvider
import androidx.media3.datasource.DataSource
import androidx.media3.datasource.DefaultDataSource
import androidx.media3.datasource.DefaultHttpDataSource
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

        // Upstream factory for network requests.
        val httpDataSourceFactory = DefaultHttpDataSource.Factory()
            .setAllowCrossProtocolRedirects(true)

        val upstreamFactory = DefaultDataSource.Factory(
            context,
            httpDataSourceFactory,
        )

        cacheDataSourceFactory = CacheDataSource.Factory()
            .setCache(cache!!)
            .setUpstreamDataSourceFactory(upstreamFactory)
            // Read from cache first, fill progressively on miss.
            .setFlags(CacheDataSource.FLAG_IGNORE_CACHE_ON_ERROR)
    }

    /**
     * Returns a [DataSource.Factory] that hits the cache when available,
     * or a plain [DefaultDataSource.Factory] if the cache has not been
     * configured.
     */
    fun dataSourceFactory(context: Context): DataSource.Factory {
        return cacheDataSourceFactory ?: DefaultDataSource.Factory(context)
    }

    /** Releases the cache. Called on engine detach. */
    @Synchronized
    fun release() {
        cache?.release()
        cache = null
        cacheDataSourceFactory = null
    }
}
