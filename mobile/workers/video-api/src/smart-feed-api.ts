// ABOUTME: Smart Feed API - Returns paginated video feeds optimized for mobile consumption
// ABOUTME: Provides TikTok-style video discovery with intelligent prefetching and caching hints

import { Env, ExecutionContext } from './types';
import { VideoAPI } from './video-api';
import { VideoAnalyticsService } from './video-analytics-service';

interface FeedRequest {
  cursor?: string;
  limit: number;
  quality?: 'auto' | '480p' | '720p';
  userId?: string;
}

interface FeedVideo {
  videoId: string;
  duration: number;
  renditions: {
    '480p': string;
    '720p': string;
  };
  poster: string;
  uploadTimestamp: number;
  originalEventId?: string;
}

interface FeedResponse {
  videos: FeedVideo[];
  nextCursor?: string;
  prefetchCount: number;
  totalAvailable: number;
  feedVersion: string;
}

export class SmartFeedAPI {
  private env: Env;
  private videoAPI: VideoAPI;
  private analytics: VideoAnalyticsService;
  private readonly DEFAULT_LIMIT = 10;
  private readonly MAX_LIMIT = 50;
  private readonly PREFETCH_COUNT = 5;

  constructor(env: Env) {
    this.env = env;
    this.videoAPI = new VideoAPI(env);
    this.analytics = new VideoAnalyticsService(env);
  }

  async handleFeedRequest(request: Request, ctx: ExecutionContext): Promise<Response> {
    const startTime = Date.now();
    
    try {
      // Parse request parameters
      const feedRequest = this.parseFeedRequest(request);
      
      if (!feedRequest) {
        return new Response(
          JSON.stringify({ error: 'Invalid feed request parameters' }),
          { 
            status: 400,
            headers: { 'Content-Type': 'application/json' }
          }
        );
      }

      // Get video list from KV store
      const videoList = await this.getVideoList(feedRequest);
      
      // Build feed response
      const response = await this.buildFeedResponse(videoList, feedRequest);

      // Track feed request analytics
      if (this.env.ENABLE_ANALYTICS !== false) {
        this.analytics.trackFeedRequest(ctx, {
          cursor: feedRequest.cursor,
          limit: feedRequest.limit,
          quality: feedRequest.quality,
          videosReturned: response.videos.length,
          hasMore: !!response.nextCursor,
          responseTime: Date.now() - startTime,
          timestamp: Date.now(),
          userId: feedRequest.userId
        });
      }

      return new Response(JSON.stringify(response), {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
          'Cache-Control': 'public, max-age=60' // Cache for 1 minute
        }
      });

    } catch (error) {
      console.error('Error handling feed request:', error);
      
      // Track error analytics
      if (this.env.ENABLE_ANALYTICS !== false) {
        this.analytics.trackAPIError(ctx, {
          endpoint: 'smart_feed',
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

  private parseFeedRequest(request: Request): FeedRequest | null {
    try {
      const url = new URL(request.url);
      const cursor = url.searchParams.get('cursor') || undefined;
      const limitParam = url.searchParams.get('limit');
      const quality = url.searchParams.get('quality') as 'auto' | '480p' | '720p' || 'auto';
      const userId = url.searchParams.get('userId') || undefined;

      let limit = this.DEFAULT_LIMIT;
      if (limitParam) {
        const parsedLimit = parseInt(limitParam, 10);
        if (isNaN(parsedLimit) || parsedLimit < 1) {
          return null;
        }
        limit = Math.min(parsedLimit, this.MAX_LIMIT);
      }

      // Validate quality parameter
      if (quality && !['auto', '480p', '720p'].includes(quality)) {
        return null;
      }

      return {
        cursor,
        limit,
        quality,
        userId
      };
    } catch {
      return null;
    }
  }

  private async getVideoList(feedRequest: FeedRequest): Promise<string[]> {
    const videoIds: string[] = [];
    const prefix = 'video:';
    
    // Use cursor for pagination
    let cursor = feedRequest.cursor;
    let collected = 0;
    const targetCount = feedRequest.limit + this.PREFETCH_COUNT; // Get extra for prefetch

    do {
      const result = await this.env.VIDEO_METADATA.list({
        prefix,
        cursor,
        limit: Math.min(1000, targetCount - collected)
      });

      for (const key of result.keys) {
        if (collected >= targetCount) break;
        
        // Extract video ID from key (remove 'video:' prefix)
        const videoId = key.name.substring(6);
        if (this.isValidVideoId(videoId)) {
          videoIds.push(videoId);
          collected++;
        }
      }

      cursor = result.list_complete ? undefined : (result as any).cursor;
    } while (cursor && collected < targetCount);

    return videoIds;
  }

  private async buildFeedResponse(
    videoIds: string[], 
    feedRequest: FeedRequest
  ): Promise<FeedResponse> {
    const videos: FeedVideo[] = [];
    const limit = feedRequest.limit;
    
    // Process videos in parallel, but only up to the requested limit
    const mainVideoIds = videoIds.slice(0, limit);
    const metadataPromises = mainVideoIds.map(videoId => 
      this.getVideoMetadata(videoId)
    );

    const metadataResults = await Promise.all(metadataPromises);

    // Build video objects with signed URLs
    const videoPromises = metadataResults.map(async (metadata, index) => {
      if (!metadata) return null;
      
      try {
        // Generate signed URLs
        const signedUrls = await this.generateSignedUrls(metadata, feedRequest.quality);
        
        return {
          videoId: metadata.videoId,
          duration: metadata.duration,
          renditions: signedUrls.renditions,
          poster: signedUrls.poster,
          uploadTimestamp: metadata.uploadTimestamp,
          originalEventId: metadata.originalEventId
        } as FeedVideo;
      } catch (error) {
        console.error(`Error processing video ${metadata.videoId}:`, error);
        return null;
      }
    });

    const videoResults = await Promise.all(videoPromises);
    
    // Filter out null results
    for (const video of videoResults) {
      if (video) {
        videos.push(video);
      }
    }

    // Determine next cursor
    let nextCursor: string | undefined;
    if (videoIds.length > limit) {
      // Use the last video ID as cursor for next page
      const lastVideoId = videoIds[limit - 1];
      nextCursor = this.createCursor(lastVideoId);
    }

    return {
      videos,
      nextCursor,
      prefetchCount: this.PREFETCH_COUNT,
      totalAvailable: await this.getTotalVideoCount(),
      feedVersion: '1.0'
    };
  }

  private async getVideoMetadata(videoId: string): Promise<any> {
    try {
      const key = `video:${videoId}`;
      return await this.env.VIDEO_METADATA.get(key, 'json');
    } catch (error) {
      console.error(`Error fetching metadata for ${videoId}:`, error);
      return null;
    }
  }

  private async generateSignedUrls(
    metadata: any, 
    quality?: 'auto' | '480p' | '720p'
  ): Promise<{
    renditions: { '480p': string; '720p': string };
    poster: string;
  }> {
    const baseUrl = this.getR2BaseUrl();
    const expiryTime = new Date(Date.now() + 5 * 60 * 1000); // 5 minutes

    const urls = {
      renditions: {
        '480p': await this.createSignedUrl(
          `${baseUrl}/videos/${metadata.videoId}/480p.mp4`,
          expiryTime
        ),
        '720p': await this.createSignedUrl(
          `${baseUrl}/videos/${metadata.videoId}/720p.mp4`,
          expiryTime
        )
      },
      poster: await this.createSignedUrl(
        `${baseUrl}/videos/${metadata.videoId}/poster.jpg`,
        expiryTime
      )
    };

    // If specific quality requested and not 'auto', only include that quality
    if (quality && quality !== 'auto') {
      const selectedUrl = urls.renditions[quality];
      urls.renditions = {
        '480p': quality === '480p' ? selectedUrl : '',
        '720p': quality === '720p' ? selectedUrl : ''
      };
    }

    return urls;
  }

  private async getTotalVideoCount(): Promise<number> {
    try {
      // Get approximate count by listing with a high limit
      const result = await this.env.VIDEO_METADATA.list({
        prefix: 'video:',
        limit: 10000
      });
      
      // This is an approximation since KV list has pagination
      return result.keys.length;
    } catch (error) {
      console.error('Error getting total video count:', error);
      return 0;
    }
  }

  private createCursor(lastVideoId: string): string {
    // Create a simple cursor from the last video ID
    const timestamp = Date.now();
    const cursorData = { lastVideoId, timestamp };
    return Buffer.from(JSON.stringify(cursorData)).toString('base64');
  }

  private parseCursor(cursor: string): { lastVideoId: string; timestamp: number } | null {
    try {
      const decoded = Buffer.from(cursor, 'base64').toString('utf-8');
      return JSON.parse(decoded);
    } catch {
      return null;
    }
  }

  private isValidVideoId(videoId: string): boolean {
    // Video IDs should be SHA256 hashes (64 hex characters)
    return /^[a-f0-9]{64}$/i.test(videoId);
  }

  private getR2BaseUrl(): string {
    switch (this.env.ENVIRONMENT) {
      case 'production':
        return 'https://videos.nostrvine.com';
      case 'staging':
        return 'https://staging-videos.nostrvine.com';
      default:
        return 'https://dev-videos.nostrvine.com';
    }
  }

  private async createSignedUrl(objectPath: string, expiryTime: Date): Promise<string> {
    const timestamp = expiryTime.getTime();
    const signature = await this.generateSignature(objectPath, timestamp);
    return `${objectPath}?expires=${timestamp}&signature=${signature}`;
  }

  private async generateSignature(path: string, timestamp: number): Promise<string> {
    const encoder = new TextEncoder();
    const data = encoder.encode(`${path}:${timestamp}:${this.env.ENVIRONMENT}`);
    const hashBuffer = await crypto.subtle.digest('SHA-256', data);
    const hashArray = Array.from(new Uint8Array(hashBuffer));
    return hashArray.map(b => b.toString(16).padStart(2, '0')).join('').substring(0, 16);
  }
}