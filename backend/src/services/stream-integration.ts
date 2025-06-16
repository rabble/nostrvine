// ABOUTME: Cloudflare Stream API integration service
// ABOUTME: Handles video upload, processing, and webhook notifications from Stream

import { StreamUploadResult, StreamWebhookPayload, FileMetadata } from '../types/nip96';

/**
 * Service for integrating with Cloudflare Stream API
 */
export class StreamIntegrationService {
  private accountId: string;
  private apiToken: string;
  private baseUrl: string;

  constructor(accountId: string, apiToken: string) {
    this.accountId = accountId;
    this.apiToken = apiToken;
    this.baseUrl = `https://api.cloudflare.com/client/v4/accounts/${accountId}/stream`;
  }

  /**
   * Create a new Stream upload URL for direct upload
   */
  async createUploadUrl(metadata: {
    filename: string;
    contentType: string;
    maxDurationSeconds?: number;
  }): Promise<StreamUploadResult> {
    try {
      const response = await fetch(`${this.baseUrl}/direct_upload`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${this.apiToken}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          maxDurationSeconds: metadata.maxDurationSeconds || 600, // 10 minutes max for vines
          expiry: new Date(Date.now() + 3600000).toISOString(), // 1 hour expiry
          meta: {
            filename: metadata.filename,
            contentType: metadata.contentType,
            uploadedAt: new Date().toISOString()
          },
          // Enable webhook notifications
          webhook: {
            url: `${self.location.origin}/api/webhooks/stream-complete`,
            secret: 'nostrvine-webhook-secret' // TODO: Use proper secret management
          }
        })
      });

      if (!response.ok) {
        throw new Error(`Stream API error: ${response.status}`);
      }

      const data = await response.json();
      
      return {
        uid: data.result.uid,
        uploadUrl: data.result.uploadURL,
        status: 'uploading'
      };

    } catch (error) {
      console.error('Failed to create Stream upload URL:', error);
      throw new Error('Failed to create video upload URL');
    }
  }

  /**
   * Get video details from Stream
   */
  async getVideoDetails(videoId: string): Promise<StreamUploadResult | null> {
    try {
      const response = await fetch(`${this.baseUrl}/${videoId}`, {
        headers: {
          'Authorization': `Bearer ${this.apiToken}`
        }
      });

      if (!response.ok) {
        if (response.status === 404) {
          return null;
        }
        throw new Error(`Stream API error: ${response.status}`);
      }

      const data = await response.json();
      const video = data.result;

      return {
        uid: video.uid,
        uploadUrl: '', // Not needed for retrieval
        playback: video.playback?.hls,
        thumbnail: video.thumbnail,
        status: video.status.state as 'uploading' | 'processing' | 'ready' | 'error'
      };

    } catch (error) {
      console.error('Failed to get video details:', error);
      return null;
    }
  }

  /**
   * Generate video thumbnails
   */
  async generateThumbnail(
    videoId: string, 
    options: {
      time?: number; // Timestamp in seconds
      width?: number;
      height?: number;
    } = {}
  ): Promise<string | null> {
    try {
      const params = new URLSearchParams();
      if (options.time) params.set('time', options.time.toString());
      if (options.width) params.set('width', options.width.toString());
      if (options.height) params.set('height', options.height.toString());

      const thumbnailUrl = `https://videodelivery.net/${videoId}/thumbnails/thumbnail.jpg?${params}`;
      
      // Validate thumbnail exists
      const response = await fetch(thumbnailUrl, { method: 'HEAD' });
      if (response.ok) {
        return thumbnailUrl;
      }

      return null;

    } catch (error) {
      console.error('Failed to generate thumbnail:', error);
      return null;
    }
  }

  /**
   * Delete video from Stream
   */
  async deleteVideo(videoId: string): Promise<boolean> {
    try {
      const response = await fetch(`${this.baseUrl}/${videoId}`, {
        method: 'DELETE',
        headers: {
          'Authorization': `Bearer ${this.apiToken}`
        }
      });

      return response.ok;

    } catch (error) {
      console.error('Failed to delete video:', error);
      return false;
    }
  }

  /**
   * Update video metadata
   */
  async updateVideoMetadata(
    videoId: string,
    metadata: {
      name?: string;
      meta?: Record<string, string>;
    }
  ): Promise<boolean> {
    try {
      const response = await fetch(`${this.baseUrl}/${videoId}`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${this.apiToken}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(metadata)
      });

      return response.ok;

    } catch (error) {
      console.error('Failed to update video metadata:', error);
      return false;
    }
  }
}

/**
 * Handle Stream webhook notifications
 */
export async function handleStreamWebhook(
  request: Request,
  env: Env,
  ctx: ExecutionContext
): Promise<Response> {
  try {
    // Verify webhook signature (simplified)
    const signature = request.headers.get('cf-webhook-signature');
    if (!signature) {
      return new Response('Missing webhook signature', { status: 401 });
    }

    const payload: StreamWebhookPayload = await request.json();
    
    console.log('Stream webhook received:', payload);

    // Process the webhook based on status
    switch (payload.status) {
      case 'ready':
        await handleVideoReady(payload, env, ctx);
        break;
      case 'error':
        await handleVideoError(payload, env, ctx);
        break;
      case 'processing':
        await handleVideoProcessing(payload, env, ctx);
        break;
    }

    return new Response('Webhook processed', { status: 200 });

  } catch (error) {
    console.error('Webhook processing error:', error);
    return new Response('Webhook processing failed', { status: 500 });
  }
}

/**
 * Handle video ready webhook
 */
async function handleVideoReady(
  payload: StreamWebhookPayload,
  env: Env,
  ctx: ExecutionContext
): Promise<void> {
  try {
    // TODO: Update job status in Durable Object
    // TODO: Generate final NIP-94 metadata
    // TODO: Optionally notify client via WebSocket or server-sent events
    
    console.log(`Video ${payload.uid} is ready for playback`);
    
    // Create file metadata for completed video
    const metadata: FileMetadata = {
      id: payload.uid,
      filename: `video_${payload.uid}.mp4`,
      content_type: 'video/mp4',
      size: payload.size || 0,
      sha256: '', // TODO: Calculate from Stream
      uploaded_at: Date.now(),
      url: payload.playback || '',
      thumbnail_url: payload.thumbnail,
      dimensions: payload.width && payload.height ? `${payload.width}x${payload.height}` : undefined,
      duration: payload.duration
    };

    // TODO: Store completed metadata in R2 or KV
    // TODO: Update job status to completed

  } catch (error) {
    console.error('Error handling video ready webhook:', error);
  }
}

/**
 * Handle video error webhook
 */
async function handleVideoError(
  payload: StreamWebhookPayload,
  env: Env,
  ctx: ExecutionContext
): Promise<void> {
  try {
    console.error(`Video ${payload.uid} processing failed:`, payload.error);
    
    // TODO: Update job status to failed
    // TODO: Notify client of failure
    
  } catch (error) {
    console.error('Error handling video error webhook:', error);
  }
}

/**
 * Handle video processing webhook
 */
async function handleVideoProcessing(
  payload: StreamWebhookPayload,
  env: Env,
  ctx: ExecutionContext
): Promise<void> {
  try {
    console.log(`Video ${payload.uid} is processing`);
    
    // TODO: Update job status with processing progress
    
  } catch (error) {
    console.error('Error handling video processing webhook:', error);
  }
}

/**
 * Create Stream service instance from environment
 */
export function createStreamService(env: Env): StreamIntegrationService {
  const accountId = env.CLOUDFLARE_ACCOUNT_ID;
  const apiToken = env.CLOUDFLARE_STREAM_TOKEN;
  
  if (!accountId || !apiToken) {
    throw new Error('Cloudflare Stream credentials not configured');
  }
  
  return new StreamIntegrationService(accountId, apiToken);
}