// ABOUTME: Batch Video Lookup API - Efficient bulk video metadata retrieval
// ABOUTME: Handles batch requests from clients that discovered videos via Nostr events

import { Env, ExecutionContext } from './types';
import { VideoAPI } from './video-api';
import { VideoAnalyticsService } from './video-analytics-service';

interface BatchRequest {
  videoIds: string[];
  quality?: 'auto' | '480p' | '720p';
}

interface VideoResult {
  videoId: string;
  duration?: number;
  renditions?: {
    '480p': string;
    '720p': string;
  };
  poster?: string;
  available: boolean;
  reason?: string;
}

interface BatchResponse {
  videos: Record<string, VideoResult>;
  found: number;
  missing: number;
}

export class BatchVideoAPI {
  private env: Env;
  private videoAPI: VideoAPI;
  private analytics: VideoAnalyticsService;
  private readonly MAX_BATCH_SIZE = 50;

  constructor(env: Env) {
    this.env = env;
    this.videoAPI = new VideoAPI(env);
    this.analytics = new VideoAnalyticsService(env);
  }

  async handleBatchRequest(request: Request, ctx: ExecutionContext): Promise<Response> {
    const startTime = Date.now();
    try {
      // Parse request body
      const body = await this.parseRequestBody(request);
      
      if (!body) {
        return new Response(
          JSON.stringify({ error: 'Invalid request body' }),
          { 
            status: 400,
            headers: { 'Content-Type': 'application/json' }
          }
        );
      }

      // Validate batch size
      if (body.videoIds.length === 0) {
        return new Response(
          JSON.stringify({ error: 'No video IDs provided' }),
          { 
            status: 400,
            headers: { 'Content-Type': 'application/json' }
          }
        );
      }

      if (body.videoIds.length > this.MAX_BATCH_SIZE) {
        return new Response(
          JSON.stringify({ 
            error: `Batch size exceeds maximum of ${this.MAX_BATCH_SIZE} videos` 
          }),
          { 
            status: 400,
            headers: { 'Content-Type': 'application/json' }
          }
        );
      }

      // Remove duplicates
      const uniqueVideoIds = [...new Set(body.videoIds)];

      // Process videos in parallel
      const results = await this.processVideoBatch(uniqueVideoIds, body.quality);

      // Build response
      const response = this.buildBatchResponse(results);

      // Track batch request analytics
      if (this.env.ENABLE_ANALYTICS !== false) {
        this.analytics.trackBatchVideoRequest(ctx, {
          requestedCount: uniqueVideoIds.length,
          foundCount: response.found,
          missingCount: response.missing,
          quality: body.quality,
          responseTime: Date.now() - startTime,
          timestamp: Date.now()
        });
      }

      return new Response(JSON.stringify(response), {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
          'Cache-Control': 'public, max-age=180' // Cache for 3 minutes
        }
      });

    } catch (error) {
      console.error('Error handling batch request:', error);
      
      // Track error analytics
      if (this.env.ENABLE_ANALYTICS !== false) {
        this.analytics.trackAPIError(ctx, {
          endpoint: 'batch_video',
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

  private async parseRequestBody(request: Request): Promise<BatchRequest | null> {
    try {
      const contentType = request.headers.get('content-type');
      if (!contentType?.includes('application/json')) {
        return null;
      }

      const body = await request.json() as BatchRequest;
      
      // Validate structure
      if (!Array.isArray(body.videoIds)) {
        return null;
      }

      // Validate each video ID
      for (const videoId of body.videoIds) {
        if (typeof videoId !== 'string' || !this.isValidVideoId(videoId)) {
          return null;
        }
      }

      return body;
    } catch {
      return null;
    }
  }

  private async processVideoBatch(
    videoIds: string[], 
    quality?: 'auto' | '480p' | '720p'
  ): Promise<VideoResult[]> {
    // Fetch metadata for all videos in parallel
    const metadataPromises = videoIds.map(videoId => 
      this.fetchVideoMetadata(videoId)
    );

    const metadataResults = await Promise.all(metadataPromises);

    // Generate signed URLs for found videos in parallel
    const videoPromises = metadataResults.map(async (metadata, index) => {
      const videoId = videoIds[index];

      if (!metadata) {
        return {
          videoId,
          available: false,
          reason: 'not_found'
        } as VideoResult;
      }

      try {
        // Generate signed URLs
        const signedUrls = await this.generateSignedUrls(metadata, quality);

        return {
          videoId,
          duration: metadata.duration,
          renditions: signedUrls.renditions,
          poster: signedUrls.poster,
          available: true
        } as VideoResult;
      } catch (error) {
        console.error(`Error processing video ${videoId}:`, error);
        return {
          videoId,
          available: false,
          reason: 'processing_error'
        } as VideoResult;
      }
    });

    return Promise.all(videoPromises);
  }

  private async fetchVideoMetadata(videoId: string): Promise<any> {
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
    const expiryTime = new Date(Date.now() + 5 * 60 * 1000);

    // For batch requests, we'll generate URLs for both qualities
    // Client can choose based on network conditions
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

  private buildBatchResponse(results: VideoResult[]): BatchResponse {
    const videos: Record<string, VideoResult> = {};
    let found = 0;
    let missing = 0;

    for (const result of results) {
      videos[result.videoId] = result;
      if (result.available) {
        found++;
      } else {
        missing++;
      }
    }

    return {
      videos,
      found,
      missing
    };
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