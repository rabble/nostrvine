// ABOUTME: PrefetchManager - Intelligent video preloading system for smooth TikTok-style scrolling
// ABOUTME: Analyzes user behavior and network conditions to optimize video prefetch strategies

import { Env, ExecutionContext } from './types';
import { SmartFeedAPI } from './smart-feed-api';
import { VideoAnalyticsService } from './video-analytics-service';

interface NetworkConditions {
  bandwidth: number; // Mbps estimate
  latency: number;   // ms
  type: 'slow' | 'medium' | 'fast';
  confidence: number; // 0-1 confidence in the estimate
}

interface ScrollPattern {
  averageViewTime: number;     // ms per video
  scrollVelocity: number;      // videos per second
  directionChanges: number;    // back/forward frequency
  qualityPreference: '480p' | '720p' | 'auto';
}

interface PrefetchStrategy {
  baseCount: number;           // Base videos to prefetch (3-7)
  qualityPriority: string[];   // Quality priority order
  networkThresholds: {
    slow: number;    // < 1Mbps - 480p only, reduce prefetch
    medium: number;  // 1-5Mbps - 480p + selective 720p
    fast: number;    // > 5Mbps - both qualities, increase prefetch
  };
  scrollVelocityMultiplier: number; // Adjust prefetch based on scroll speed
  maxPrefetchSize: number;     // Maximum MB to prefetch
}

interface PrefetchRecommendation {
  videoIds: string[];
  qualityMap: Record<string, '480p' | '720p' | 'both'>;
  priorityOrder: string[];
  estimatedSize: number; // MB
  reasoning: {
    networkCondition: string;
    scrollPattern: string;
    strategy: string;
  };
}

interface PrefetchAnalytics {
  userId?: string;
  sessionId: string;
  prefetchedCount: number;
  hitRate: number;           // % of prefetched videos actually viewed
  qualityUpgradeSuccess: number; // % of successful 480p→720p upgrades
  networkPredictionAccuracy: number;
  avgPrefetchTime: number;   // ms to prefetch videos
  bandwidthSaved: number;    // MB saved by intelligent prefetch
  timestamp: number;
}

export class PrefetchManager {
  private env: Env;
  private feedAPI: SmartFeedAPI;
  private analytics: VideoAnalyticsService;
  
  private readonly DEFAULT_STRATEGY: PrefetchStrategy = {
    baseCount: 4,
    qualityPriority: ['480p', '720p'],
    networkThresholds: {
      slow: 1.0,    // 1 Mbps
      medium: 5.0,  // 5 Mbps  
      fast: 10.0    // 10 Mbps
    },
    scrollVelocityMultiplier: 1.5,
    maxPrefetchSize: 50 // 50MB max
  };

  constructor(env: Env) {
    this.env = env;
    this.feedAPI = new SmartFeedAPI(env);
    this.analytics = new VideoAnalyticsService(env);
  }

  /**
   * Main prefetch recommendation endpoint
   */
  async handlePrefetchRequest(request: Request, ctx: ExecutionContext): Promise<Response> {
    const startTime = Date.now();
    
    try {
      // Parse prefetch request
      const prefetchRequest = await this.parsePrefetchRequest(request);
      
      if (!prefetchRequest) {
        return new Response(
          JSON.stringify({ error: 'Invalid prefetch request parameters' }),
          { 
            status: 400,
            headers: { 'Content-Type': 'application/json' }
          }
        );
      }

      // Analyze network conditions and user patterns
      const networkConditions = this.analyzeNetworkConditions(prefetchRequest);
      const scrollPattern = this.analyzeScrollPattern(prefetchRequest);
      
      // Generate optimal prefetch strategy
      const strategy = this.calculatePrefetchStrategy(networkConditions, scrollPattern);
      
      // Get prefetch recommendations
      const recommendations = await this.generatePrefetchRecommendations(
        prefetchRequest,
        strategy,
        networkConditions,
        scrollPattern
      );

      // Track prefetch analytics
      if (this.env.ENABLE_ANALYTICS !== false) {
        this.analytics.trackPrefetchRequest(ctx, {
          sessionId: prefetchRequest.sessionId,
          userId: prefetchRequest.userId,
          networkType: networkConditions.type,
          prefetchCount: recommendations.videoIds.length,
          estimatedSize: recommendations.estimatedSize,
          strategy: JSON.stringify(strategy),
          responseTime: Date.now() - startTime,
          timestamp: Date.now()
        });
      }

      return new Response(JSON.stringify({
        prefetch: recommendations,
        strategy: {
          networkCondition: networkConditions.type,
          bandwidth: networkConditions.bandwidth,
          baseCount: strategy.baseCount,
          qualityPriority: strategy.qualityPriority
        },
        meta: {
          responseTime: Date.now() - startTime,
          timestamp: new Date().toISOString(),
          version: '1.0'
        }
      }), {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
          'Cache-Control': 'private, max-age=30' // Cache for 30 seconds
        }
      });

    } catch (error) {
      console.error('Error handling prefetch request:', error);
      
      // Track error analytics
      if (this.env.ENABLE_ANALYTICS !== false) {
        this.analytics.trackAPIError(ctx, {
          endpoint: 'prefetch_manager',
          error: error instanceof Error ? error.message : 'Unknown error',
          statusCode: 500,
          timestamp: Date.now()
        });
      }

      return new Response(
        JSON.stringify({ error: 'Internal server error' }),
        { 
          status: 500,
          headers: { 'Content-Type': 'application/json' }
        }
      );
    }
  }

  /**
   * Analytics endpoint for prefetch performance
   */
  async handlePrefetchAnalytics(request: Request, ctx: ExecutionContext): Promise<Response> {
    try {
      const url = new URL(request.url);
      const sessionId = url.searchParams.get('sessionId');
      const hours = parseInt(url.searchParams.get('hours') || '24', 10);

      if (!sessionId) {
        return new Response(
          JSON.stringify({ error: 'sessionId parameter required' }),
          { status: 400, headers: { 'Content-Type': 'application/json' } }
        );
      }

      const analytics = await this.getPrefetchAnalytics(sessionId, hours);
      
      return new Response(JSON.stringify({
        sessionId,
        period: { hours },
        analytics,
        timestamp: new Date().toISOString()
      }), {
        headers: {
          'Content-Type': 'application/json',
          'Cache-Control': 'private, max-age=300' // Cache for 5 minutes
        }
      });
    } catch (error) {
      console.error('Error getting prefetch analytics:', error);
      return new Response(
        JSON.stringify({ error: 'Failed to retrieve analytics' }),
        { status: 500, headers: { 'Content-Type': 'application/json' } }
      );
    }
  }

  private async parsePrefetchRequest(request: Request): Promise<any> {
    try {
      const url = new URL(request.url);
      const body = request.method === 'POST' ? await request.json() : {};
      
      return {
        sessionId: url.searchParams.get('sessionId') || body.sessionId || 'anonymous',
        userId: url.searchParams.get('userId') || body.userId,
        currentVideoId: url.searchParams.get('currentVideoId') || body.currentVideoId,
        cursor: url.searchParams.get('cursor') || body.cursor,
        
        // Network condition hints from client
        networkHints: {
          bandwidth: parseFloat(url.searchParams.get('bandwidth') || body.bandwidth || '0'),
          latency: parseInt(url.searchParams.get('latency') || body.latency || '0', 10),
          connectionType: url.searchParams.get('connectionType') || body.connectionType || 'unknown'
        },
        
        // User behavior patterns from client
        userHints: {
          averageViewTime: parseInt(url.searchParams.get('avgViewTime') || body.avgViewTime || '6000', 10),
          scrollVelocity: parseFloat(url.searchParams.get('scrollVelocity') || body.scrollVelocity || '1.0'),
          qualityPreference: url.searchParams.get('quality') || body.quality || 'auto'
        },
        
        // Prefetch context
        prefetchCount: parseInt(url.searchParams.get('prefetchCount') || body.prefetchCount || '5', 10)
      };
    } catch {
      return null;
    }
  }

  private analyzeNetworkConditions(request: any): NetworkConditions {
    const hints = request.networkHints;
    let bandwidth = hints.bandwidth || 0;
    let latency = hints.latency || 100;
    
    // If no bandwidth hint, estimate from connection type
    if (bandwidth === 0) {
      switch (hints.connectionType) {
        case 'slow-2g':
        case '2g':
          bandwidth = 0.25;
          latency = 300;
          break;
        case '3g':
          bandwidth = 1.5;
          latency = 150;
          break;
        case '4g':
          bandwidth = 10;
          latency = 50;
          break;
        case 'wifi':
          bandwidth = 25;
          latency = 20;
          break;
        default:
          bandwidth = 5; // Conservative default
          latency = 100;
      }
    }

    // Determine network type
    let type: 'slow' | 'medium' | 'fast';
    if (bandwidth < this.DEFAULT_STRATEGY.networkThresholds.slow) {
      type = 'slow';
    } else if (bandwidth < this.DEFAULT_STRATEGY.networkThresholds.medium) {
      type = 'medium';
    } else {
      type = 'fast';
    }

    return {
      bandwidth,
      latency,
      type,
      confidence: hints.bandwidth > 0 ? 0.9 : 0.6 // Higher confidence if client provided
    };
  }

  private analyzeScrollPattern(request: any): ScrollPattern {
    const hints = request.userHints;
    
    return {
      averageViewTime: hints.averageViewTime || 6000, // Default 6 seconds
      scrollVelocity: hints.scrollVelocity || 1.0,     // Videos per second
      directionChanges: 0, // Could be tracked by client
      qualityPreference: hints.qualityPreference || 'auto'
    };
  }

  private calculatePrefetchStrategy(
    network: NetworkConditions, 
    scroll: ScrollPattern
  ): PrefetchStrategy {
    const strategy = { ...this.DEFAULT_STRATEGY };
    
    // Adjust prefetch count based on network
    switch (network.type) {
      case 'slow':
        strategy.baseCount = 2; // Minimal prefetch
        strategy.qualityPriority = ['480p'];
        strategy.maxPrefetchSize = 10; // 10MB max
        break;
      case 'medium':
        strategy.baseCount = 4;
        strategy.qualityPriority = ['480p', '720p'];
        strategy.maxPrefetchSize = 30;
        break;
      case 'fast':
        strategy.baseCount = 6; // Aggressive prefetch
        strategy.qualityPriority = ['720p', '480p']; // Prefer high quality
        strategy.maxPrefetchSize = 100;
        break;
    }

    // Adjust based on scroll velocity
    if (scroll.scrollVelocity > 2.0) {
      // Fast scrolling - increase prefetch
      strategy.baseCount = Math.min(strategy.baseCount + 2, 8);
    } else if (scroll.scrollVelocity < 0.5) {
      // Slow scrolling - reduce prefetch
      strategy.baseCount = Math.max(strategy.baseCount - 1, 2);
    }

    return strategy;
  }

  private async generatePrefetchRecommendations(
    request: any,
    strategy: PrefetchStrategy,
    network: NetworkConditions,
    scroll: ScrollPattern
  ): Promise<PrefetchRecommendation> {
    // Get upcoming videos from feed API
    const feedResponse = await this.getFeedVideos(request.cursor, strategy.baseCount + 2);
    
    const videoIds = feedResponse.videoIds || [];
    const qualityMap: Record<string, '480p' | '720p' | 'both'> = {};
    const priorityOrder: string[] = [];
    let estimatedSize = 0;

    // Assign quality and priority based on strategy
    for (let i = 0; i < Math.min(videoIds.length, strategy.baseCount); i++) {
      const videoId = videoIds[i];
      priorityOrder.push(videoId);

      // Determine quality based on position and network
      if (i < 2) {
        // First 2 videos: always high priority
        qualityMap[videoId] = network.type === 'slow' ? '480p' : 'both';
        estimatedSize += network.type === 'slow' ? 1.5 : 4.0; // MB estimate
      } else if (network.type === 'fast') {
        // Fast network: prefetch both qualities
        qualityMap[videoId] = 'both';
        estimatedSize += 4.0;
      } else {
        // Conservative: start with 480p
        qualityMap[videoId] = '480p';
        estimatedSize += 1.5;
      }
    }

    return {
      videoIds: priorityOrder,
      qualityMap,
      priorityOrder,
      estimatedSize: Math.round(estimatedSize * 100) / 100, // Round to 2 decimals
      reasoning: {
        networkCondition: `${network.type} (${network.bandwidth}Mbps)`,
        scrollPattern: `${scroll.scrollVelocity} videos/sec, ${scroll.averageViewTime}ms avg view`,
        strategy: `${strategy.baseCount} videos, ${strategy.qualityPriority.join('→')} priority`
      }
    };
  }

  private async getFeedVideos(cursor?: string, limit: number = 10): Promise<{ videoIds: string[] }> {
    try {
      // Mock request to feed API
      const feedRequest = new Request(`http://internal/api/feed?limit=${limit}${cursor ? `&cursor=${cursor}` : ''}`);
      const feedResponse = await this.feedAPI.handleFeedRequest(feedRequest, {
        waitUntil: () => {},
        passThroughOnException: () => {}
      } as ExecutionContext);
      
      const feedData = await feedResponse.json();
      const videoIds = feedData.videos?.map((v: any) => v.videoId) || [];
      
      return { videoIds };
    } catch (error) {
      console.error('Error getting feed videos for prefetch:', error);
      return { videoIds: [] };
    }
  }

  private async getPrefetchAnalytics(sessionId: string, hours: number): Promise<any> {
    // Get prefetch analytics from KV store
    const startTime = Date.now() - (hours * 60 * 60 * 1000);
    const prefix = `analytics:prefetch:${sessionId}:`;
    
    const analytics = {
      totalRequests: 0,
      avgHitRate: 0,
      avgQualityUpgradeSuccess: 0,
      avgResponseTime: 0,
      bandwidthSaved: 0,
      networkConditions: {} as Record<string, number>
    };

    try {
      let cursor: string | undefined;
      do {
        const result = await this.env.VIDEO_METADATA.list({
          prefix,
          cursor,
          limit: 1000
        });

        for (const key of result.keys) {
          const timestamp = parseInt(key.name.split(':').pop() || '0', 10);
          if (timestamp >= startTime) {
            const data = await this.env.VIDEO_METADATA.get(key.name, 'json') as any;
            if (data) {
              analytics.totalRequests++;
              analytics.avgHitRate += data.hitRate || 0;
              analytics.avgQualityUpgradeSuccess += data.qualityUpgradeSuccess || 0;
              analytics.avgResponseTime += data.responseTime || 0;
              analytics.bandwidthSaved += data.bandwidthSaved || 0;
              
              const networkType = data.networkType || 'unknown';
              analytics.networkConditions[networkType] = (analytics.networkConditions[networkType] || 0) + 1;
            }
          }
        }

        cursor = result.list_complete ? undefined : (result as any).cursor;
      } while (cursor);
    } catch (error) {
      console.error('Error fetching prefetch analytics:', error);
    }

    // Calculate averages
    if (analytics.totalRequests > 0) {
      analytics.avgHitRate /= analytics.totalRequests;
      analytics.avgQualityUpgradeSuccess /= analytics.totalRequests;
      analytics.avgResponseTime /= analytics.totalRequests;
    }

    return analytics;
  }
}