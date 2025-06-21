// ABOUTME: Handles video status polling requests with UUID validation
// ABOUTME: Provides optimized responses based on processing state

import { Env, ExecutionContext } from '../types';

interface VideoStatusData {
  status: 'pending_upload' | 'processing' | 'published' | 'failed' | 'quarantined';
  createdAt: string;
  updatedAt: string;
  stream?: {
    hlsUrl: string;
    dashUrl: string;
    thumbnailUrl: string;
  };
  source?: {
    error?: string;
  };
}

interface StatusResponse {
  status: string;
  hlsUrl?: string;
  dashUrl?: string;
  thumbnailUrl?: string;
  createdAt?: string;
  error?: string;
}

export class VideoStatusHandler {
  private env: Env;
  
  constructor(env: Env) {
    this.env = env;
  }

  async handleStatusCheck(request: Request, videoId: string, ctx: ExecutionContext): Promise<Response> {
    try {
      // Validate UUID format (security against enumeration)
      if (!this.isValidUUID(videoId)) {
        return this.errorResponse('invalid_video_id', 'Video ID must be a valid UUID', 400);
      }

      // Optional rate limiting
      const clientIP = request.headers.get('CF-Connecting-IP') || 'unknown';
      const rateLimitOk = await this.checkRateLimit(clientIP, ctx);
      if (!rateLimitOk) {
        return this.errorResponse('rate_limit_exceeded', 'Too many status requests, please use exponential backoff', 429);
      }

      // Fetch video status from KV
      const statusKey = `v1:video:${videoId}`;
      const statusData = await this.env.VIDEO_STATUS.get(statusKey);

      if (!statusData) {
        return this.errorResponse('video_not_found', 'Video not found', 404);
      }

      const videoStatus: VideoStatusData = JSON.parse(statusData);

      // Build conditional response based on status
      const response = this.buildStatusResponse(videoStatus);
      const cacheHeaders = this.getCacheHeaders(videoStatus.status);

      return new Response(JSON.stringify(response), {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
          ...cacheHeaders
        }
      });

    } catch (error) {
      console.error('Status check error:', error);
      return this.errorResponse('internal_error', 'Internal server error', 500);
    }
  }

  private isValidUUID(uuid: string): boolean {
    const uuidV4Regex = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
    return uuidV4Regex.test(uuid);
  }

  private buildStatusResponse(videoStatus: VideoStatusData): StatusResponse {
    const baseResponse: StatusResponse = {
      status: videoStatus.status
    };

    // Only include URLs and metadata for published videos
    if (videoStatus.status === 'published' && videoStatus.stream) {
      return {
        ...baseResponse,
        hlsUrl: videoStatus.stream.hlsUrl,
        dashUrl: videoStatus.stream.dashUrl,
        thumbnailUrl: this.transformToCloudflareImagesUrl(
          videoStatus.stream.thumbnailUrl
        ),
        createdAt: videoStatus.createdAt
      };
    }

    // For failed videos, include user-friendly error message
    if (videoStatus.status === 'failed' && videoStatus.source?.error) {
      return {
        ...baseResponse,
        error: this.getUserFriendlyError(videoStatus.source.error)
      };
    }

    // For all other statuses, return minimal information
    return baseResponse;
  }

  private transformToCloudflareImagesUrl(streamThumbnailUrl: string): string {
    // For now, just return the original URL
    // TODO: Implement actual thumbnail transformation when we have real Cloudflare Images setup
    return streamThumbnailUrl;
  }

  private getUserFriendlyError(internalError: string): string {
    // Map internal errors to user-friendly messages
    if (internalError.includes('timeout')) {
      return 'Processing timeout - please try uploading again';
    }
    if (internalError.includes('moderation')) {
      return 'Video processing failed - please contact support';
    }
    if (internalError.includes('format')) {
      return 'Unsupported video format - please try a different file';
    }
    if (internalError.includes('size')) {
      return 'Video file too large - please reduce file size';
    }
    return 'Processing failed - please try again';
  }

  private getCacheHeaders(status: VideoStatusData['status']): Record<string, string> {
    switch (status) {
      case 'published':
        // Published videos can be cached longer
        return {
          'Cache-Control': 'public, max-age=3600', // 1 hour
          'CDN-Cache-Control': 'max-age=86400' // 24 hours on edge
        };

      case 'failed':
      case 'quarantined':
        // Terminal states won't change
        return {
          'Cache-Control': 'public, max-age=1800' // 30 minutes
        };

      case 'processing':
        // Processing videos change frequently
        return {
          'Cache-Control': 'no-cache',
          'CDN-Cache-Control': 'no-cache'
        };

      case 'pending_upload':
        // Very short cache for pending uploads
        return {
          'Cache-Control': 'public, max-age=30' // 30 seconds
        };

      default:
        return { 'Cache-Control': 'no-cache' };
    }
  }

  private async checkRateLimit(clientIP: string, ctx: ExecutionContext): Promise<boolean> {
    // Optional: Basic rate limiting for polling endpoint
    const rateLimitKey = `ratelimit:status:${clientIP}`;
    const requests = await this.env.VIDEO_STATUS.get(rateLimitKey);
    const count = requests ? parseInt(requests) : 0;

    if (count > 180) { // 180 requests per minute (3 per second max)
      return false;
    }

    // Update counter with TTL
    ctx.waitUntil(
      this.env.VIDEO_STATUS.put(rateLimitKey, (count + 1).toString(), { 
        expirationTtl: 60 
      })
    );
    
    return true;
  }

  private errorResponse(code: string, message: string, status: number): Response {
    return new Response(JSON.stringify({
      error: { code, message }
    }), {
      status,
      headers: { 'Content-Type': 'application/json' }
    });
  }
}