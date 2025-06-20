// ABOUTME: Analytics and monitoring service for video delivery performance tracking
// ABOUTME: Collects metrics on requests, cache performance, and system health

export interface VideoAnalytics {
  videoId: string;
  requestCount: number;
  cacheHits: number;
  cacheMisses: number;
  qualityBreakdown: {
    '480p': number;
    '720p': number;
  };
  averageResponseTime: number;
  errorRate: number;
  lastAccessed: number;
}

export interface HealthStatus {
  status: 'healthy' | 'degraded' | 'unhealthy';
  timestamp: string;
  metrics: SystemMetrics;
  dependencies: {
    r2: 'healthy' | 'error' | 'unknown';
    kv: 'healthy' | 'error' | 'unknown';
    rateLimiter: 'healthy' | 'error' | 'unknown';
  };
}

export interface SystemMetrics {
  totalRequests: number;
  cacheHitRate: number;
  averageResponseTime: number;
  activeVideos: number;
  errorRate: number;
  requestsPerMinute: number;
}

export interface RequestMetrics {
  timestamp: number;
  videoId?: string;
  endpoint: string;
  quality?: string;
  cacheHit?: boolean;
  responseTime: number;
  statusCode: number;
  userAgent?: string;
  country?: string;
  error?: string;
}

// Time windows for analytics aggregation
export const TIME_WINDOWS = {
  REAL_TIME: 60 * 1000,        // 1 minute
  HOURLY: 60 * 60 * 1000,      // 1 hour
  DAILY: 24 * 60 * 60 * 1000,  // 24 hours
  WEEKLY: 7 * 24 * 60 * 60 * 1000, // 7 days
} as const;

export class VideoAnalyticsService {
  constructor(
    private env: Env,
    private ctx: ExecutionContext
  ) {}

  /**
   * Track a video request
   */
  async trackVideoRequest(
    videoId: string,
    quality: string,
    cacheHit: boolean,
    responseTime: number,
    request: Request
  ): Promise<void> {
    const metrics: RequestMetrics = {
      timestamp: Date.now(),
      videoId,
      endpoint: '/api/video',
      quality,
      cacheHit,
      responseTime,
      statusCode: 200,
      userAgent: request.headers.get('User-Agent') || undefined,
      country: (request as any).cf?.country || undefined,
    };

    // Track in background without blocking response
    this.ctx.waitUntil(
      Promise.all([
        this.updateVideoCounters(videoId, quality, cacheHit),
        this.updateGlobalMetrics(metrics),
        this.updatePopularityRankings(videoId),
        this.sendToCloudflareAnalytics(metrics),
      ])
    );
  }

  /**
   * Track batch API request
   */
  async trackBatchRequest(
    videoIds: string[],
    found: number,
    missing: number,
    responseTime: number,
    request: Request,
    apiKey?: string
  ): Promise<void> {
    const metrics: RequestMetrics = {
      timestamp: Date.now(),
      endpoint: '/api/videos/batch',
      responseTime,
      statusCode: 200,
      userAgent: request.headers.get('User-Agent') || undefined,
      country: (request as any).cf?.country || undefined,
    };

    // Track batch-specific metrics
    this.ctx.waitUntil(
      Promise.all([
        this.updateGlobalMetrics(metrics),
        this.updateBatchMetrics(videoIds.length, found, missing),
        this.sendToCloudflareAnalytics(metrics),
      ])
    );
  }

  /**
   * Track API errors
   */
  async trackError(
    error: Error,
    endpoint: string,
    request: Request
  ): Promise<void> {
    const metrics: RequestMetrics = {
      timestamp: Date.now(),
      endpoint,
      responseTime: 0,
      statusCode: 500,
      userAgent: request.headers.get('User-Agent') || undefined,
      country: (request as any).cf?.country || undefined,
      error: error.message,
    };

    this.ctx.waitUntil(
      Promise.all([
        this.updateErrorCounters(endpoint),
        this.logError(error, metrics),
        this.sendToCloudflareAnalytics(metrics),
      ])
    );
  }

  /**
   * Get popular videos for a time window
   */
  async getPopularVideos(
    timeframe: '1h' | '24h' | '7d' = '24h',
    limit: number = 10
  ): Promise<VideoAnalytics[]> {
    const key = `popular:${timeframe}`;
    const data = await this.env.METADATA_CACHE.get<VideoAnalytics[]>(key, 'json');
    
    if (!data) {
      return [];
    }

    // Sort by request count and return top N
    return data
      .sort((a, b) => b.requestCount - a.requestCount)
      .slice(0, limit);
  }

  /**
   * Get system health status
   */
  async getHealthStatus(): Promise<HealthStatus> {
    const [r2Health, kvHealth, rateLimiterHealth, metrics] = await Promise.allSettled([
      this.checkR2Health(),
      this.checkKVHealth(),
      this.checkRateLimiterHealth(),
      this.getCurrentMetrics(),
    ]);

    const dependencies = {
      r2: r2Health.status === 'fulfilled' && r2Health.value ? 'healthy' : 'error',
      kv: kvHealth.status === 'fulfilled' && kvHealth.value ? 'healthy' : 'error',
      rateLimiter: rateLimiterHealth.status === 'fulfilled' && rateLimiterHealth.value ? 'healthy' : 'error',
    };

    const allHealthy = Object.values(dependencies).every(d => d === 'healthy');
    const anyError = Object.values(dependencies).some(d => d === 'error');

    return {
      status: allHealthy ? 'healthy' : anyError ? 'unhealthy' : 'degraded',
      timestamp: new Date().toISOString(),
      metrics: metrics.status === 'fulfilled' ? metrics.value : this.getEmptyMetrics(),
      dependencies,
    };
  }

  /**
   * Get current system metrics
   */
  async getCurrentMetrics(): Promise<SystemMetrics> {
    const now = Date.now();
    const oneMinuteAgo = now - TIME_WINDOWS.REAL_TIME;

    // Get real-time metrics from KV
    const [
      totalRequests,
      cacheHits,
      cacheMisses,
      totalResponseTime,
      errors,
      activeVideos,
    ] = await Promise.all([
      this.getCounter('global:requests'),
      this.getCounter('global:cache_hits'),
      this.getCounter('global:cache_misses'),
      this.getCounter('global:response_time_total'),
      this.getCounter('global:errors'),
      this.getCounter('global:active_videos'),
    ]);

    const totalCacheRequests = cacheHits + cacheMisses;
    const cacheHitRate = totalCacheRequests > 0 ? cacheHits / totalCacheRequests : 0;
    const averageResponseTime = totalRequests > 0 ? totalResponseTime / totalRequests : 0;
    const errorRate = totalRequests > 0 ? errors / totalRequests : 0;

    // Get requests in the last minute
    const recentRequests = await this.getCounter(`requests:${Math.floor(oneMinuteAgo / 60000)}`);

    return {
      totalRequests,
      cacheHitRate,
      averageResponseTime,
      activeVideos,
      errorRate,
      requestsPerMinute: recentRequests,
    };
  }

  /**
   * Update video-specific counters
   */
  private async updateVideoCounters(
    videoId: string,
    quality: string,
    cacheHit: boolean
  ): Promise<void> {
    const videoKey = `video:${videoId}:analytics`;
    const existing = await this.env.METADATA_CACHE.get<VideoAnalytics>(videoKey, 'json');

    const analytics: VideoAnalytics = existing || {
      videoId,
      requestCount: 0,
      cacheHits: 0,
      cacheMisses: 0,
      qualityBreakdown: { '480p': 0, '720p': 0 },
      averageResponseTime: 0,
      errorRate: 0,
      lastAccessed: Date.now(),
    };

    // Update counters
    analytics.requestCount++;
    if (cacheHit) {
      analytics.cacheHits++;
    } else {
      analytics.cacheMisses++;
    }

    // Update quality breakdown
    if (quality === '480p' || quality === '720p') {
      analytics.qualityBreakdown[quality]++;
    }

    analytics.lastAccessed = Date.now();

    // Save back to KV with TTL
    await this.env.METADATA_CACHE.put(videoKey, JSON.stringify(analytics), {
      expirationTtl: 86400, // 24 hours
    });
  }

  /**
   * Update global metrics
   */
  private async updateGlobalMetrics(metrics: RequestMetrics): Promise<void> {
    // Increment global counters
    await Promise.all([
      this.incrementCounter('global:requests'),
      metrics.cacheHit !== undefined && metrics.cacheHit
        ? this.incrementCounter('global:cache_hits')
        : this.incrementCounter('global:cache_misses'),
      this.incrementCounter('global:response_time_total', metrics.responseTime),
      this.incrementCounter(`requests:${Math.floor(metrics.timestamp / 60000)}`), // Per-minute counter
    ]);
  }

  /**
   * Update batch-specific metrics
   */
  private async updateBatchMetrics(
    requested: number,
    found: number,
    missing: number
  ): Promise<void> {
    await Promise.all([
      this.incrementCounter('batch:total_requests'),
      this.incrementCounter('batch:videos_requested', requested),
      this.incrementCounter('batch:videos_found', found),
      this.incrementCounter('batch:videos_missing', missing),
    ]);
  }

  /**
   * Update popularity rankings
   */
  private async updatePopularityRankings(videoId: string): Promise<void> {
    const popularityKey = `popularity:${videoId}`;
    const current = await this.env.METADATA_CACHE.get(popularityKey);
    const count = current ? parseInt(current) + 1 : 1;

    await this.env.METADATA_CACHE.put(popularityKey, count.toString(), {
      expirationTtl: 86400, // 24 hour sliding window
    });

    // Update hourly and daily rankings
    await Promise.all([
      this.updateTimeWindowRanking('1h', videoId, count),
      this.updateTimeWindowRanking('24h', videoId, count),
      this.updateTimeWindowRanking('7d', videoId, count),
    ]);
  }

  /**
   * Update time-window specific rankings
   */
  private async updateTimeWindowRanking(
    window: string,
    videoId: string,
    count: number
  ): Promise<void> {
    const key = `popular:${window}`;
    const existing = await this.env.METADATA_CACHE.get<VideoAnalytics[]>(key, 'json') || [];
    
    // Find or create entry for this video
    const index = existing.findIndex(v => v.videoId === videoId);
    if (index >= 0) {
      existing[index].requestCount = count;
      existing[index].lastAccessed = Date.now();
    } else {
      const videoAnalytics = await this.env.METADATA_CACHE.get<VideoAnalytics>(
        `video:${videoId}:analytics`,
        'json'
      );
      if (videoAnalytics) {
        existing.push(videoAnalytics);
      }
    }

    // Sort and keep top 100
    const sorted = existing
      .sort((a, b) => b.requestCount - a.requestCount)
      .slice(0, 100);

    await this.env.METADATA_CACHE.put(key, JSON.stringify(sorted), {
      expirationTtl: window === '1h' ? 3600 : window === '24h' ? 86400 : 604800,
    });
  }

  /**
   * Send metrics to Cloudflare Analytics
   */
  private async sendToCloudflareAnalytics(metrics: RequestMetrics): Promise<void> {
    if (this.env.ENVIRONMENT === 'development') {
      console.log('📊 Analytics:', JSON.stringify(metrics));
      return;
    }

    // Use Cloudflare Analytics Engine if available
    if (this.env.ANALYTICS) {
      await this.env.ANALYTICS.writeDataPoint({
        blobs: [metrics.endpoint, metrics.videoId || 'none'],
        doubles: [metrics.responseTime, metrics.cacheHit ? 1 : 0],
        indexes: ['video_analytics'],
      });
    }
  }

  /**
   * Update error counters
   */
  private async updateErrorCounters(endpoint: string): Promise<void> {
    await Promise.all([
      this.incrementCounter('global:errors'),
      this.incrementCounter(`errors:${endpoint}`),
    ]);
  }

  /**
   * Log error details
   */
  private async logError(error: Error, context: RequestMetrics): Promise<void> {
    const errorLog = {
      timestamp: context.timestamp,
      message: error.message,
      stack: error.stack,
      endpoint: context.endpoint,
      userAgent: context.userAgent,
      country: context.country,
    };

    // Store error log with TTL
    const errorKey = `error:${Date.now()}:${Math.random()}`;
    await this.env.METADATA_CACHE.put(errorKey, JSON.stringify(errorLog), {
      expirationTtl: 86400, // Keep error logs for 24 hours
    });

    console.error('🚨 API Error:', errorLog);
  }

  /**
   * Health check helpers
   */
  private async checkR2Health(): Promise<boolean> {
    try {
      // Try to head a known object or list bucket
      const objects = await this.env.MEDIA_BUCKET.list({ limit: 1 });
      return true;
    } catch (error) {
      console.error('R2 health check failed:', error);
      return false;
    }
  }

  private async checkKVHealth(): Promise<boolean> {
    try {
      // Try a simple KV operation
      await this.env.METADATA_CACHE.get('health_check');
      return true;
    } catch (error) {
      console.error('KV health check failed:', error);
      return false;
    }
  }

  private async checkRateLimiterHealth(): Promise<boolean> {
    try {
      // Check if we can access rate limit data
      const testKey = 'rate_limit:health_check:0';
      await this.env.METADATA_CACHE.get(testKey);
      return true;
    } catch (error) {
      console.error('Rate limiter health check failed:', error);
      return false;
    }
  }

  /**
   * Counter helpers
   */
  private async incrementCounter(key: string, amount: number = 1): Promise<void> {
    const current = await this.getCounter(key);
    await this.env.METADATA_CACHE.put(key, (current + amount).toString(), {
      expirationTtl: 86400, // 24 hour TTL for all counters
    });
  }

  private async getCounter(key: string): Promise<number> {
    const value = await this.env.METADATA_CACHE.get(key);
    return value ? parseInt(value) : 0;
  }

  private getEmptyMetrics(): SystemMetrics {
    return {
      totalRequests: 0,
      cacheHitRate: 0,
      averageResponseTime: 0,
      activeVideos: 0,
      errorRate: 0,
      requestsPerMinute: 0,
    };
  }
}