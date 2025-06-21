// ABOUTME: Video Metadata API - Returns video metadata with signed R2 URLs
// ABOUTME: Handles single video lookups for NostrVine short-form videos

import { Env, ExecutionContext } from './types';
import { VideoAnalyticsService } from './video-analytics-service';

interface VideoMetadata {
  videoId: string;
  duration: number;
  fileSize: number;
  renditions: {
    '480p': { key: string; size: number };
    '720p': { key: string; size: number };
  };
  poster: string;
  uploadTimestamp: number;
  originalEventId?: string;
}

interface VideoResponse {
  videoId: string;
  duration: number;
  renditions: {
    '480p': string;
    '720p': string;
  };
  poster: string;
}

export class VideoAPI {
  private env: Env;
  private analytics: VideoAnalyticsService;

  constructor(env: Env) {
    this.env = env;
    this.analytics = new VideoAnalyticsService(env);
  }

  async handleVideoRequest(videoId: string, request: Request, ctx: ExecutionContext): Promise<Response> {
    const startTime = Date.now();
    try {
      // Validate video ID format
      if (!this.isValidVideoId(videoId)) {
        return new Response(
          JSON.stringify({ error: 'Invalid video ID format' }),
          { 
            status: 400,
            headers: { 'Content-Type': 'application/json' }
          }
        );
      }

      // Fetch metadata from KV
      const metadata = await this.getVideoMetadata(videoId);
      const cacheHit = metadata !== null;
      
      if (!metadata) {
        // Track analytics for missing video
        if (this.env.ENABLE_ANALYTICS !== false) {
          this.analytics.trackVideoMetadataRequest(ctx, {
            videoId,
            cacheHit: false,
            responseTime: Date.now() - startTime,
            timestamp: Date.now(),
            error: 'not_found'
          });
        }
        return new Response(
          JSON.stringify({ error: 'Video not found' }),
          { 
            status: 404,
            headers: { 'Content-Type': 'application/json' }
          }
        );
      }

      // Generate signed URLs for each rendition
      const signedUrls = await this.generateSignedUrls(metadata);

      // Build response
      const response: VideoResponse = {
        videoId: metadata.videoId,
        duration: metadata.duration,
        renditions: {
          '480p': signedUrls['480p'],
          '720p': signedUrls['720p']
        },
        poster: signedUrls.poster
      };

      // Track successful request analytics
      if (this.env.ENABLE_ANALYTICS !== false) {
        const quality = this.analytics.getQualityPreference(request);
        this.analytics.trackVideoMetadataRequest(ctx, {
          videoId,
          cacheHit,
          quality,
          responseTime: Date.now() - startTime,
          timestamp: Date.now()
        });
      }

      return new Response(JSON.stringify(response), {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
          'Cache-Control': 'public, max-age=300' // Cache for 5 minutes
        }
      });

    } catch (error) {
      console.error('Error handling video request:', error);
      
      // Track error analytics
      if (this.env.ENABLE_ANALYTICS !== false) {
        this.analytics.trackAPIError(ctx, {
          endpoint: 'video_metadata',
          error: error instanceof Error ? error.message : 'Unknown error',
          statusCode: 500,
          timestamp: Date.now(),
          videoId
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

  private async getVideoMetadata(videoId: string): Promise<VideoMetadata | null> {
    try {
      const key = `video:${videoId}`;
      const metadata = await this.env.VIDEO_METADATA.get(key, 'json') as VideoMetadata;
      return metadata;
    } catch (error) {
      console.error('Error fetching metadata from KV:', error);
      return null;
    }
  }

  private async generateSignedUrls(metadata: VideoMetadata): Promise<{
    '480p': string;
    '720p': string;
    poster: string;
  }> {
    const expiryMinutes = 5;
    const expiryTime = new Date(Date.now() + expiryMinutes * 60 * 1000);

    // For R2, we can create pre-signed URLs using the S3 API compatibility
    // In a real implementation, you'd use the AWS SDK or similar
    // For now, we'll create temporary public URLs

    const baseUrl = this.getR2BaseUrl();

    return {
      '480p': await this.createSignedUrl(
        `${baseUrl}/videos/${metadata.videoId}/480p.mp4`,
        expiryTime
      ),
      '720p': await this.createSignedUrl(
        `${baseUrl}/videos/${metadata.videoId}/720p.mp4`,
        expiryTime
      ),
      poster: await this.createSignedUrl(
        `${baseUrl}/videos/${metadata.videoId}/poster.jpg`,
        expiryTime
      )
    };
  }

  private async createSignedUrl(objectPath: string, expiryTime: Date): Promise<string> {
    // In production, this would generate a proper signed URL
    // For now, we'll return a temporary URL structure
    const timestamp = expiryTime.getTime();
    const signature = await this.generateSignature(objectPath, timestamp);
    
    return `${objectPath}?expires=${timestamp}&signature=${signature}`;
  }

  private async generateSignature(path: string, timestamp: number): Promise<string> {
    // Simple signature generation - in production use proper HMAC
    const encoder = new TextEncoder();
    const data = encoder.encode(`${path}:${timestamp}:${this.env.ENVIRONMENT}`);
    const hashBuffer = await crypto.subtle.digest('SHA-256', data);
    const hashArray = Array.from(new Uint8Array(hashBuffer));
    return hashArray.map(b => b.toString(16).padStart(2, '0')).join('').substring(0, 16);
  }

  private getR2BaseUrl(): string {
    // In production, this would be your actual R2 public URL
    switch (this.env.ENVIRONMENT) {
      case 'production':
        return 'https://videos.nostrvine.com';
      case 'staging':
        return 'https://staging-videos.nostrvine.com';
      default:
        return 'https://dev-videos.nostrvine.com';
    }
  }

  private isValidVideoId(videoId: string): boolean {
    // Video IDs should be SHA256 hashes (64 hex characters)
    return /^[a-f0-9]{64}$/i.test(videoId);
  }
}