// ABOUTME: VideoAnalyticsService - Tracks video API metrics and performance
// ABOUTME: Provides non-blocking analytics collection for video metadata and batch requests

import { Env, ExecutionContext } from './types';

interface VideoMetadataMetrics {
  videoId: string;
  cacheHit: boolean;
  quality?: '480p' | '720p' | 'both';
  responseTime: number;
  timestamp: number;
  error?: string;
}

interface BatchVideoMetrics {
  requestedCount: number;
  foundCount: number;
  missingCount: number;
  quality?: 'auto' | '480p' | '720p';
  responseTime: number;
  timestamp: number;
  error?: string;
}

interface APIErrorMetrics {
  endpoint: string;
  error: string;
  statusCode: number;
  timestamp: number;
  videoId?: string;
}

interface FeedRequestMetrics {
  cursor?: string;
  limit: number;
  quality?: 'auto' | '480p' | '720p';
  videosReturned: number;
  hasMore: boolean;
  responseTime: number;
  timestamp: number;
  userId?: string;
}

interface PrefetchRequestMetrics {
  sessionId: string;
  userId?: string;
  networkType: 'slow' | 'medium' | 'fast';
  prefetchCount: number;
  estimatedSize: number;
  strategy: string;
  responseTime: number;
  timestamp: number;
}

interface PrefetchPerformanceMetrics {
  sessionId: string;
  userId?: string;
  hitRate: number;           // % of prefetched videos actually viewed
  qualityUpgradeSuccess: number; // % of successful 480p→720p upgrades
  bandwidthSaved: number;    // MB saved by intelligent prefetch
  networkPredictionAccuracy: number;
  timestamp: number;
}

export class VideoAnalyticsService {
  private env: Env;
  private readonly ANALYTICS_PREFIX = 'analytics:';
  private readonly BATCH_SIZE = 100;

  constructor(env: Env) {
    this.env = env;
  }

  /**
   * Track video metadata request metrics
   */
  async trackVideoMetadataRequest(
    ctx: ExecutionContext,
    metrics: VideoMetadataMetrics
  ): Promise<void> {
    ctx.waitUntil(this.recordVideoMetadataMetrics(metrics));
  }

  /**
   * Track batch video lookup metrics
   */
  async trackBatchVideoRequest(
    ctx: ExecutionContext,
    metrics: BatchVideoMetrics
  ): Promise<void> {
    ctx.waitUntil(this.recordBatchVideoMetrics(metrics));
  }

  /**
   * Track API errors
   */
  async trackAPIError(
    ctx: ExecutionContext,
    error: APIErrorMetrics
  ): Promise<void> {
    ctx.waitUntil(this.recordErrorMetrics(error));
  }

  /**
   * Track feed request metrics
   */
  async trackFeedRequest(
    ctx: ExecutionContext,
    metrics: FeedRequestMetrics
  ): Promise<void> {
    ctx.waitUntil(this.recordFeedRequestMetrics(metrics));
  }

  /**
   * Track prefetch request metrics
   */
  async trackPrefetchRequest(
    ctx: ExecutionContext,
    metrics: PrefetchRequestMetrics
  ): Promise<void> {
    ctx.waitUntil(this.recordPrefetchRequestMetrics(metrics));
  }

  /**
   * Track prefetch performance metrics
   */
  async trackPrefetchPerformance(
    ctx: ExecutionContext,
    metrics: PrefetchPerformanceMetrics
  ): Promise<void> {
    ctx.waitUntil(this.recordPrefetchPerformanceMetrics(metrics));
  }

  /**
   * Get quality preference from request headers or query params
   */
  getQualityPreference(request: Request): '480p' | '720p' | 'both' {
    const url = new URL(request.url);
    const queryQuality = url.searchParams.get('quality');
    const headerQuality = request.headers.get('x-video-quality');
    
    const quality = queryQuality || headerQuality;
    
    if (quality === '480p' || quality === '720p') {
      return quality;
    }
    
    return 'both';
  }

  private async recordVideoMetadataMetrics(metrics: VideoMetadataMetrics): Promise<void> {
    try {
      // Store individual metrics
      const key = `${this.ANALYTICS_PREFIX}video:${metrics.videoId}:${Date.now()}`;
      await this.env.VIDEO_METADATA.put(key, JSON.stringify(metrics), {
        expirationTtl: 86400 * 7 // Keep for 7 days
      });

      // Update aggregated metrics
      await this.updateAggregatedMetrics('video_metadata', {
        totalRequests: 1,
        cacheHits: metrics.cacheHit ? 1 : 0,
        avgResponseTime: metrics.responseTime,
        qualityBreakdown: {
          [metrics.quality || 'both']: 1
        }
      });
    } catch (error) {
      console.error('Failed to record video metadata metrics:', error);
    }
  }

  private async recordBatchVideoMetrics(metrics: BatchVideoMetrics): Promise<void> {
    try {
      // Store individual batch metrics
      const key = `${this.ANALYTICS_PREFIX}batch:${Date.now()}`;
      await this.env.VIDEO_METADATA.put(key, JSON.stringify(metrics), {
        expirationTtl: 86400 * 7 // Keep for 7 days
      });

      // Update aggregated metrics
      await this.updateAggregatedMetrics('batch_video', {
        totalRequests: 1,
        totalVideosRequested: metrics.requestedCount,
        totalVideosFound: metrics.foundCount,
        totalVideosMissing: metrics.missingCount,
        avgResponseTime: metrics.responseTime,
        avgBatchSize: metrics.requestedCount
      });
    } catch (error) {
      console.error('Failed to record batch video metrics:', error);
    }
  }

  private async recordErrorMetrics(error: APIErrorMetrics): Promise<void> {
    try {
      // Store error metrics
      const key = `${this.ANALYTICS_PREFIX}error:${error.endpoint}:${Date.now()}`;
      await this.env.VIDEO_METADATA.put(key, JSON.stringify(error), {
        expirationTtl: 86400 * 7 // Keep for 7 days
      });

      // Update error counts
      await this.updateAggregatedMetrics('errors', {
        [error.endpoint]: {
          [error.statusCode]: 1
        }
      });
    } catch (error) {
      console.error('Failed to record error metrics:', error);
    }
  }

  private async recordFeedRequestMetrics(metrics: FeedRequestMetrics): Promise<void> {
    try {
      // Store individual feed metrics
      const key = `${this.ANALYTICS_PREFIX}feed:${Date.now()}`;
      await this.env.VIDEO_METADATA.put(key, JSON.stringify(metrics), {
        expirationTtl: 86400 * 7 // Keep for 7 days
      });

      // Update aggregated metrics
      await this.updateAggregatedMetrics('smart_feed', {
        totalRequests: 1,
        totalVideosServed: metrics.videosReturned,
        avgResponseTime: metrics.responseTime,
        avgVideosPerRequest: metrics.videosReturned,
        paginationRate: metrics.hasMore ? 1 : 0,
        qualityBreakdown: {
          [metrics.quality || 'auto']: 1
        }
      });
    } catch (error) {
      console.error('Failed to record feed request metrics:', error);
    }
  }

  private async recordPrefetchRequestMetrics(metrics: PrefetchRequestMetrics): Promise<void> {
    try {
      // Store individual prefetch request metrics
      const key = `${this.ANALYTICS_PREFIX}prefetch:${metrics.sessionId}:${Date.now()}`;
      await this.env.VIDEO_METADATA.put(key, JSON.stringify(metrics), {
        expirationTtl: 86400 * 7 // Keep for 7 days
      });

      // Update aggregated metrics
      await this.updateAggregatedMetrics('prefetch_manager', {
        totalRequests: 1,
        totalVideosRecommended: metrics.prefetchCount,
        avgEstimatedSize: metrics.estimatedSize,
        avgResponseTime: metrics.responseTime,
        networkTypeBreakdown: {
          [metrics.networkType]: 1
        }
      });
    } catch (error) {
      console.error('Failed to record prefetch request metrics:', error);
    }
  }

  private async recordPrefetchPerformanceMetrics(metrics: PrefetchPerformanceMetrics): Promise<void> {
    try {
      // Store individual prefetch performance metrics
      const key = `${this.ANALYTICS_PREFIX}prefetch_perf:${metrics.sessionId}:${Date.now()}`;
      await this.env.VIDEO_METADATA.put(key, JSON.stringify(metrics), {
        expirationTtl: 86400 * 7 // Keep for 7 days
      });

      // Update aggregated metrics
      await this.updateAggregatedMetrics('prefetch_performance', {
        totalSessions: 1,
        avgHitRate: metrics.hitRate,
        avgQualityUpgradeSuccess: metrics.qualityUpgradeSuccess,
        avgBandwidthSaved: metrics.bandwidthSaved,
        avgNetworkPredictionAccuracy: metrics.networkPredictionAccuracy
      });
    } catch (error) {
      console.error('Failed to record prefetch performance metrics:', error);
    }
  }

  private async updateAggregatedMetrics(
    category: string,
    updates: Record<string, any>
  ): Promise<void> {
    const hourlyKey = `${this.ANALYTICS_PREFIX}aggregate:${category}:${this.getCurrentHour()}`;
    
    try {
      // Get existing metrics
      const existing = await this.env.VIDEO_METADATA.get(hourlyKey, 'json') as any || {};
      
      // Merge updates
      const merged = this.mergeMetrics(existing, updates);
      
      // Save back
      await this.env.VIDEO_METADATA.put(hourlyKey, JSON.stringify(merged), {
        expirationTtl: 86400 * 30 // Keep aggregated data for 30 days
      });
    } catch (error) {
      console.error('Failed to update aggregated metrics:', error);
    }
  }

  private mergeMetrics(existing: any, updates: any): any {
    const result = { ...existing };
    
    for (const [key, value] of Object.entries(updates)) {
      if (typeof value === 'number') {
        if (key.startsWith('avg')) {
          // Handle averages
          const countKey = key.replace('avg', 'total') + 'Count';
          const currentCount = result[countKey] || 0;
          const currentAvg = result[key] || 0;
          const newCount = currentCount + 1;
          result[key] = (currentAvg * currentCount + value) / newCount;
          result[countKey] = newCount;
        } else {
          // Simple increment
          result[key] = (result[key] || 0) + value;
        }
      } else if (typeof value === 'object') {
        // Recursively merge objects
        result[key] = this.mergeMetrics(result[key] || {}, value);
      } else {
        result[key] = value;
      }
    }
    
    return result;
  }

  private getCurrentHour(): string {
    const now = new Date();
    return `${now.getUTCFullYear()}-${String(now.getUTCMonth() + 1).padStart(2, '0')}-${String(now.getUTCDate()).padStart(2, '0')}-${String(now.getUTCHours()).padStart(2, '0')}`;
  }

  /**
   * Get analytics summary for monitoring
   */
  async getAnalyticsSummary(hours: number = 24): Promise<any> {
    const summaries = [];
    const now = new Date();
    
    for (let i = 0; i < hours; i++) {
      const hour = new Date(now.getTime() - i * 60 * 60 * 1000);
      const hourKey = `${hour.getUTCFullYear()}-${String(hour.getUTCMonth() + 1).padStart(2, '0')}-${String(hour.getUTCDate()).padStart(2, '0')}-${String(hour.getUTCHours()).padStart(2, '0')}`;
      
      const videoMetrics = await this.env.VIDEO_METADATA.get(
        `${this.ANALYTICS_PREFIX}aggregate:video_metadata:${hourKey}`,
        'json'
      );
      
      const batchMetrics = await this.env.VIDEO_METADATA.get(
        `${this.ANALYTICS_PREFIX}aggregate:batch_video:${hourKey}`,
        'json'
      );
      
      const errorMetrics = await this.env.VIDEO_METADATA.get(
        `${this.ANALYTICS_PREFIX}aggregate:errors:${hourKey}`,
        'json'
      );
      
      if (videoMetrics || batchMetrics || errorMetrics) {
        summaries.push({
          hour: hourKey,
          videoMetadata: videoMetrics || {},
          batchVideo: batchMetrics || {},
          errors: errorMetrics || {}
        });
      }
    }
    
    return summaries;
  }

  /**
   * Get health status with detailed metrics
   */
  async getHealthStatus(): Promise<{
    status: 'healthy' | 'degraded' | 'unhealthy';
    metrics: {
      lastHourRequests: number;
      cacheHitRate: number;
      avgResponseTime: number;
      errorRate: number;
      activeVideos: number;
    };
  }> {
    try {
      const summary = await this.getAnalyticsSummary(1);
      
      if (summary.length === 0) {
        return {
          status: 'healthy',
          metrics: {
            lastHourRequests: 0,
            cacheHitRate: 0,
            avgResponseTime: 0,
            errorRate: 0,
            activeVideos: 0
          }
        };
      }

      const lastHour = summary[0];
      const videoMetrics = lastHour.videoMetadata || {};
      const batchMetrics = lastHour.batchVideo || {};
      const errorMetrics = lastHour.errors || {};
      
      const totalRequests = (videoMetrics.totalRequests || 0) + (batchMetrics.totalRequests || 0);
      const cacheHits = videoMetrics.cacheHits || 0;
      const avgResponseTime = videoMetrics.avgResponseTime || 0;
      
      // Count total errors
      const totalErrors = Object.values(errorMetrics).reduce((sum: number, endpoint: any) => {
        return sum + Object.values(endpoint).reduce((s: number, count: any) => s + count, 0);
      }, 0);

      const errorRate = totalRequests > 0 ? totalErrors / totalRequests : 0;
      const cacheHitRate = totalRequests > 0 ? cacheHits / totalRequests : 0;

      // Determine health status
      let status: 'healthy' | 'degraded' | 'unhealthy' = 'healthy';
      if (errorRate > 0.1 || avgResponseTime > 2000) {
        status = 'unhealthy';
      } else if (errorRate > 0.05 || avgResponseTime > 1000 || cacheHitRate < 0.5) {
        status = 'degraded';
      }

      // Count active videos (videos with recent requests)
      const activeVideos = await this.countActiveVideos(1);

      return {
        status,
        metrics: {
          lastHourRequests: totalRequests,
          cacheHitRate,
          avgResponseTime,
          errorRate,
          activeVideos
        }
      };
    } catch (error) {
      console.error('Failed to get health status:', error);
      return {
        status: 'unhealthy',
        metrics: {
          lastHourRequests: 0,
          cacheHitRate: 0,
          avgResponseTime: 0,
          errorRate: 1,
          activeVideos: 0
        }
      };
    }
  }

  /**
   * Count unique videos accessed in the last N hours
   */
  private async countActiveVideos(hours: number): Promise<number> {
    const uniqueVideos = new Set<string>();
    const startTime = Date.now() - (hours * 60 * 60 * 1000);
    const prefix = 'analytics:video:';
    
    let cursor: string | undefined;
    let count = 0;
    
    do {
      const result = await this.env.VIDEO_METADATA.list({
        prefix,
        cursor,
        limit: 1000
      });

      for (const key of result.keys) {
        const parts = key.name.split(':');
        const timestamp = parseInt(parts[parts.length - 1], 10);
        
        if (timestamp >= startTime) {
          const videoId = parts[2]; // Extract video ID from key
          uniqueVideos.add(videoId);
        }
        
        count++;
        // Limit scan to prevent timeout
        if (count > 5000) break;
      }

      cursor = result.list_complete ? undefined : (result as any).cursor;
    } while (cursor && count <= 5000);

    return uniqueVideos.size;
  }
}