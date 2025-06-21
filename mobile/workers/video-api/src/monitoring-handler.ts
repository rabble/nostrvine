// ABOUTME: MonitoringHandler - Provides health check and analytics dashboard endpoints
// ABOUTME: Includes enhanced health status, popular videos, and comprehensive system metrics

import { VideoAnalyticsService } from './video-analytics-service';
import { Env, ExecutionContext } from './types';

interface HealthStatus {
  status: 'healthy' | 'degraded' | 'unhealthy';
  timestamp: string;
  environment: string;
  services: {
    kv: {
      status: 'operational' | 'degraded' | 'down';
      latency?: number;
    };
    r2: {
      status: 'operational' | 'degraded' | 'down';
      latency?: number;
    };
  };
  metrics?: {
    lastHourRequests?: number;
    cacheHitRate?: number;
    avgResponseTime?: number;
    errorRate?: number;
  };
}

interface PopularVideo {
  videoId: string;
  viewCount: number;
  uniqueViewers: number;
  avgResponseTime: number;
  cacheHitRate: number;
}

interface DashboardData {
  health: HealthStatus;
  performance: {
    requestsPerHour: number[];
    avgResponseTimes: number[];
    cacheHitRates: number[];
    errorRates: number[];
  };
  popularVideos: {
    lastHour: PopularVideo[];
    last24Hours: PopularVideo[];
    last7Days: PopularVideo[];
  };
  errors: {
    recent: Array<{
      endpoint: string;
      error: string;
      statusCode: number;
      timestamp: string;
      count: number;
    }>;
    byEndpoint: Record<string, number>;
    byStatusCode: Record<string, number>;
  };
  cache: {
    hitRate: number;
    missRate: number;
    totalRequests: number;
    avgTTL: number;
  };
}

export class MonitoringHandler {
  private env: Env;
  private analyticsService: VideoAnalyticsService;

  constructor(env: Env) {
    this.env = env;
    this.analyticsService = new VideoAnalyticsService(env);
  }

  /**
   * Enhanced health check endpoint
   */
  async handleHealthCheck(ctx: ExecutionContext): Promise<Response> {
    const startTime = Date.now();
    const health: HealthStatus = {
      status: 'healthy',
      timestamp: new Date().toISOString(),
      environment: this.env.ENVIRONMENT,
      services: {
        kv: { status: 'operational' },
        r2: { status: 'operational' }
      }
    };

    try {
      // Test KV health
      const kvStart = Date.now();
      await this.env.VIDEO_METADATA.get('health-check-test');
      health.services.kv.latency = Date.now() - kvStart;

      // Test R2 health
      const r2Start = Date.now();
      await this.env.VIDEO_BUCKET.head('health-check-test');
      health.services.r2.latency = Date.now() - r2Start;
    } catch (error) {
      console.error('Health check service test failed:', error);
      health.status = 'degraded';
      if (error instanceof Error) {
        if (error.message.includes('KV')) {
          health.services.kv.status = 'down';
        } else if (error.message.includes('R2')) {
          health.services.r2.status = 'down';
        }
      }
    }

    // Get last hour metrics if analytics are enabled
    if (this.env.ENABLE_ANALYTICS) {
      try {
        const summary = await this.analyticsService.getAnalyticsSummary(1);
        if (summary.length > 0) {
          const lastHour = summary[0];
          const videoMetrics = lastHour.videoMetadata || {};
          const errorMetrics = lastHour.errors || {};
          
          const totalRequests = videoMetrics.totalRequests || 0;
          const cacheHits = videoMetrics.cacheHits || 0;
          const totalErrors = Object.values(errorMetrics).reduce((sum: number, endpoint: any) => {
            return sum + Object.values(endpoint).reduce((s: number, count: any) => s + count, 0);
          }, 0);

          health.metrics = {
            lastHourRequests: totalRequests,
            cacheHitRate: totalRequests > 0 ? cacheHits / totalRequests : 0,
            avgResponseTime: videoMetrics.avgResponseTime || 0,
            errorRate: totalRequests > 0 ? totalErrors / totalRequests : 0
          };

          // Determine overall health based on metrics
          const errorRate = health.metrics?.errorRate || 0;
          const avgResponseTime = health.metrics?.avgResponseTime || 0;
          if (errorRate > 0.1) {
            health.status = 'unhealthy';
          } else if (errorRate > 0.05 || avgResponseTime > 1000) {
            health.status = 'degraded';
          }
        }
      } catch (error) {
        console.error('Failed to get health metrics:', error);
      }
    }

    return new Response(JSON.stringify(health), {
      headers: {
        'Content-Type': 'application/json',
        'Cache-Control': 'no-cache, no-store, must-revalidate'
      }
    });
  }

  /**
   * Get popular videos for different time windows
   */
  async handlePopularVideos(request: Request, ctx: ExecutionContext): Promise<Response> {
    // Validate authentication first
    if (!this.validateAuth(request)) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { status: 401, headers: { 'Content-Type': 'application/json' } }
      );
    }

    const url = new URL(request.url);
    const window = url.searchParams.get('window') || '24h';
    
    let hours: number;
    switch (window) {
      case '1h':
        hours = 1;
        break;
      case '24h':
        hours = 24;
        break;
      case '7d':
        hours = 168;
        break;
      default:
        return new Response(
          JSON.stringify({ error: 'Invalid window. Use 1h, 24h, or 7d' }),
          { status: 400, headers: { 'Content-Type': 'application/json' } }
        );
    }

    try {
      const popularVideos = await this.getPopularVideos(hours);
      
      return new Response(JSON.stringify({
        window,
        videos: popularVideos,
        timestamp: new Date().toISOString()
      }), {
        headers: {
          'Content-Type': 'application/json',
          'Cache-Control': 'public, max-age=300' // Cache for 5 minutes
        }
      });
    } catch (error) {
      console.error('Failed to get popular videos:', error);
      return new Response(
        JSON.stringify({ error: 'Failed to retrieve popular videos' }),
        { status: 500, headers: { 'Content-Type': 'application/json' } }
      );
    }
  }

  /**
   * Comprehensive dashboard data endpoint
   */
  async handleDashboard(request: Request, ctx: ExecutionContext): Promise<Response> {
    // Validate authentication first
    if (!this.validateAuth(request)) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { status: 401, headers: { 'Content-Type': 'application/json' } }
      );
    }

    const url = new URL(request.url);
    const hours = parseInt(url.searchParams.get('hours') || '24', 10);

    try {
      // Get health status
      const healthResponse = await this.handleHealthCheck(ctx);
      const health = await healthResponse.json() as HealthStatus;

      // Get analytics summary
      const summary = await this.analyticsService.getAnalyticsSummary(hours);

      // Process analytics data
      const performance = this.processPerformanceMetrics(summary);
      const errors = this.processErrorMetrics(summary);
      const cache = this.processCacheMetrics(summary);

      // Get popular videos for different windows
      const popularVideos = {
        lastHour: await this.getPopularVideos(1),
        last24Hours: await this.getPopularVideos(24),
        last7Days: await this.getPopularVideos(168)
      };

      const dashboardData: DashboardData = {
        health,
        performance,
        popularVideos,
        errors,
        cache
      };

      return new Response(JSON.stringify({
        data: dashboardData,
        timestamp: new Date().toISOString(),
        period: { hours }
      }), {
        headers: {
          'Content-Type': 'application/json',
          'Cache-Control': 'public, max-age=60' // Cache for 1 minute
        }
      });
    } catch (error) {
      console.error('Failed to generate dashboard data:', error);
      return new Response(
        JSON.stringify({ error: 'Failed to generate dashboard data' }),
        { status: 500, headers: { 'Content-Type': 'application/json' } }
      );
    }
  }

  /**
   * Get popular videos based on request metrics
   */
  private async getPopularVideos(hours: number): Promise<PopularVideo[]> {
    const videoStats: Map<string, {
      viewCount: number;
      uniqueViewers: Set<string>;
      totalResponseTime: number;
      cacheHits: number;
    }> = new Map();

    // Scan through recent video requests
    const startTime = Date.now() - (hours * 60 * 60 * 1000);
    const prefix = 'analytics:video:';
    
    // Use KV list to find video analytics entries
    let cursor: string | undefined;
    do {
      const result = await this.env.VIDEO_METADATA.list({
        prefix,
        cursor,
        limit: 1000
      });

      for (const key of result.keys) {
        // Extract timestamp from key
        const parts = key.name.split(':');
        const timestamp = parseInt(parts[parts.length - 1], 10);
        
        if (timestamp >= startTime) {
          const data = await this.env.VIDEO_METADATA.get(key.name, 'json') as any;
          if (data && data.videoId) {
            const stats = videoStats.get(data.videoId) || {
              viewCount: 0,
              uniqueViewers: new Set<string>(),
              totalResponseTime: 0,
              cacheHits: 0
            };

            stats.viewCount++;
            stats.totalResponseTime += data.responseTime || 0;
            if (data.cacheHit) stats.cacheHits++;
            
            // Track unique viewers if available (could be from IP or user ID)
            if (data.viewerId) {
              stats.uniqueViewers.add(data.viewerId);
            }

            videoStats.set(data.videoId, stats);
          }
        }
      }

      cursor = result.list_complete ? undefined : (result as any).cursor;
    } while (cursor);

    // Convert to array and sort by view count
    const popularVideos: PopularVideo[] = Array.from(videoStats.entries())
      .map(([videoId, stats]) => ({
        videoId,
        viewCount: stats.viewCount,
        uniqueViewers: stats.uniqueViewers.size,
        avgResponseTime: stats.viewCount > 0 ? stats.totalResponseTime / stats.viewCount : 0,
        cacheHitRate: stats.viewCount > 0 ? stats.cacheHits / stats.viewCount : 0
      }))
      .sort((a, b) => b.viewCount - a.viewCount)
      .slice(0, 20); // Top 20 videos

    return popularVideos;
  }

  /**
   * Process performance metrics from analytics summary
   */
  private processPerformanceMetrics(summary: any[]): DashboardData['performance'] {
    const requestsPerHour: number[] = [];
    const avgResponseTimes: number[] = [];
    const cacheHitRates: number[] = [];
    const errorRates: number[] = [];

    for (const hour of summary) {
      const videoMetrics = hour.videoMetadata || {};
      const batchMetrics = hour.batchVideo || {};
      const errorMetrics = hour.errors || {};

      const totalRequests = (videoMetrics.totalRequests || 0) + (batchMetrics.totalRequests || 0);
      const cacheHits = videoMetrics.cacheHits || 0;
      const avgResponseTime = videoMetrics.avgResponseTime || 0;
      
      const totalErrors = Object.values(errorMetrics).reduce((sum: number, endpoint: any) => {
        return sum + Object.values(endpoint).reduce((s: number, count: any) => s + count, 0);
      }, 0);

      requestsPerHour.push(totalRequests);
      avgResponseTimes.push(avgResponseTime);
      cacheHitRates.push(totalRequests > 0 ? cacheHits / totalRequests : 0);
      errorRates.push(totalRequests > 0 ? totalErrors / totalRequests : 0);
    }

    return {
      requestsPerHour: requestsPerHour.reverse(), // Oldest to newest
      avgResponseTimes: avgResponseTimes.reverse(),
      cacheHitRates: cacheHitRates.reverse(),
      errorRates: errorRates.reverse()
    };
  }

  /**
   * Process error metrics from analytics summary
   */
  private processErrorMetrics(summary: any[]): DashboardData['errors'] {
    const recentErrors: Array<{
      endpoint: string;
      error: string;
      statusCode: number;
      timestamp: string;
      count: number;
    }> = [];
    
    const byEndpoint: Record<string, number> = {};
    const byStatusCode: Record<string, number> = {};

    // Aggregate errors
    for (const hour of summary) {
      const errorMetrics = hour.errors || {};
      
      for (const [endpoint, statusCodes] of Object.entries(errorMetrics)) {
        for (const [statusCode, count] of Object.entries(statusCodes as any)) {
          byEndpoint[endpoint] = (byEndpoint[endpoint] || 0) + (count as number);
          byStatusCode[statusCode] = (byStatusCode[statusCode] || 0) + (count as number);
        }
      }
    }

    // Get recent error details (last 10 errors)
    // Note: This is a simplified version. In production, you'd want to store more detailed error info
    const recentErrorKeys = summary.slice(0, 5).flatMap(hour => {
      const errors = [];
      const errorMetrics = hour.errors || {};
      
      for (const [endpoint, statusCodes] of Object.entries(errorMetrics)) {
        for (const [statusCode, count] of Object.entries(statusCodes as any)) {
          const countNum = typeof count === 'number' ? count : 0;
          if (countNum > 0) {
            errors.push({
              endpoint,
              error: `HTTP ${statusCode}`,
              statusCode: parseInt(statusCode, 10),
              timestamp: hour.hour,
              count: countNum
            });
          }
        }
      }
      
      return errors;
    });

    return {
      recent: recentErrorKeys.slice(0, 10),
      byEndpoint,
      byStatusCode
    };
  }

  /**
   * Process cache metrics from analytics summary
   */
  private processCacheMetrics(summary: any[]): DashboardData['cache'] {
    let totalRequests = 0;
    let totalCacheHits = 0;

    for (const hour of summary) {
      const videoMetrics = hour.videoMetadata || {};
      totalRequests += videoMetrics.totalRequests || 0;
      totalCacheHits += videoMetrics.cacheHits || 0;
    }

    const hitRate = totalRequests > 0 ? totalCacheHits / totalRequests : 0;

    return {
      hitRate,
      missRate: 1 - hitRate,
      totalRequests,
      avgTTL: 3600 // Default 1 hour TTL, could be made configurable
    };
  }

  /**
   * Validate API authentication
   */
  validateAuth(request: Request): boolean {
    const authHeader = request.headers.get('Authorization');
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return false;
    }

    // In production, you'd validate the token here
    // For now, we'll just check if a token is present
    const token = authHeader.substring(7);
    return token.length > 0;
  }
}