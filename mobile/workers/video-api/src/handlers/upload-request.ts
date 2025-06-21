// ABOUTME: Handles video upload requests with NIP-98 authentication and Cloudflare Stream integration
// ABOUTME: Implements rate limiting and stores upload status in KV

import { Env, ExecutionContext } from '../types';
import { validateNIP98Event, NIP98AuthError } from '../lib/auth';

interface UploadRequestBody {
  fileName: string;
  fileSize: number;
}

interface UploadResponse {
  videoId: string;
  uploadURL: string;
  expiresAt: string;
}

interface ErrorResponse {
  error: {
    code: string;
    message: string;
    retryAfter?: number;
  };
}

interface VideoStatus {
  videoId: string;
  nostrPubkey: string;
  status: 'pending_upload' | 'uploading' | 'processing' | 'completed' | 'failed';
  createdAt: string;
  updatedAt: string;
  source: {
    uploadedAt: string | null;
    error: string | null;
  };
  stream: {
    uid: string;
    hlsUrl: string | null;
    dashUrl: string | null;
    thumbnailUrl: string | null;
  };
  moderation: {
    status: 'pending' | 'approved' | 'rejected';
    flaggedCategories: string[];
    checkedAt: string | null;
  };
}

export class UploadRequestHandler {
  private env: Env;
  private readonly RATE_LIMIT_PER_HOUR = 30;
  private readonly RATE_LIMIT_WINDOW = 3600; // 1 hour in seconds
  private readonly MAX_FILE_SIZE = 500 * 1024 * 1024; // 500MB
  private readonly MAX_DURATION_SECONDS = 300; // 5 minutes

  constructor(env: Env) {
    this.env = env;
  }

  async handleRequest(request: Request, ctx: ExecutionContext): Promise<Response> {
    try {
      // Validate NIP-98 authentication
      const authHeader = request.headers.get('Authorization');
      if (!authHeader) {
        return this.errorResponse('auth_failed', 'Missing Authorization header', 401);
      }

      let nostrEvent;
      try {
        nostrEvent = await validateNIP98Event(authHeader, request.url, 'POST');
      } catch (error) {
        if (error instanceof NIP98AuthError) {
          return this.errorResponse(error.code, error.message, 401);
        }
        throw error;
      }

      const pubkey = nostrEvent.pubkey;

      // Parse and validate request body
      const body = await this.parseRequestBody(request);
      if (!body) {
        return this.errorResponse('invalid_request', 'Invalid request body', 400);
      }

      // Validate file parameters
      if (!body.fileName || typeof body.fileName !== 'string') {
        return this.errorResponse('invalid_request', 'fileName is required', 400);
      }

      if (!body.fileSize || typeof body.fileSize !== 'number' || body.fileSize <= 0) {
        return this.errorResponse('invalid_request', 'fileSize must be a positive number', 400);
      }

      if (body.fileSize > this.MAX_FILE_SIZE) {
        return this.errorResponse(
          'file_too_large',
          `File size exceeds maximum of ${this.MAX_FILE_SIZE / 1024 / 1024}MB`,
          400
        );
      }

      // Check rate limit
      const rateLimitKey = `ratelimit:upload:${pubkey}`;
      const rateLimitResult = await this.checkRateLimit(rateLimitKey);
      if (!rateLimitResult.allowed) {
        return this.errorResponse(
          'rate_limit_exceeded',
          'Upload limit of 30 per hour exceeded',
          429,
          rateLimitResult.retryAfter
        );
      }

      // Check if Cloudflare Stream is configured
      if (!this.env.CLOUDFLARE_API_TOKEN || !this.env.STREAM_ACCOUNT_ID) {
        console.error('Cloudflare Stream credentials not configured');
        return this.errorResponse(
          'service_unavailable',
          'Video upload service is not configured',
          503
        );
      }

      // Request upload URL from Cloudflare Stream
      const streamResponse = await this.requestStreamUpload();
      if (!streamResponse.success) {
        return this.errorResponse(
          'service_unavailable',
          streamResponse.error || 'Cloudflare Stream API temporarily unavailable',
          503
        );
      }

      // Generate video ID and store initial status
      const videoId = crypto.randomUUID();
      const videoStatus: VideoStatus = {
        videoId,
        nostrPubkey: pubkey,
        status: 'pending_upload',
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
        source: {
          uploadedAt: null,
          error: null
        },
        stream: {
          uid: streamResponse.uid!,
          hlsUrl: null,
          dashUrl: null,
          thumbnailUrl: null
        },
        moderation: {
          status: 'pending',
          flaggedCategories: [],
          checkedAt: null
        }
      };

      // Store video status and increment rate limit counter
      await Promise.all([
        this.env.VIDEO_STATUS.put(
          `v1:video:${videoId}`,
          JSON.stringify(videoStatus),
          { expirationTtl: 86400 * 7 } // 7 days TTL
        ),
        this.incrementRateLimit(rateLimitKey)
      ]);

      // Build response
      const response: UploadResponse = {
        videoId,
        uploadURL: streamResponse.uploadURL!,
        expiresAt: new Date(Date.now() + 30 * 60 * 1000).toISOString() // 30 minutes
      };

      return new Response(JSON.stringify(response), {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
          'Cache-Control': 'no-store'
        }
      });

    } catch (error) {
      console.error('Error handling upload request:', error);
      return this.errorResponse(
        'internal_error',
        'An unexpected error occurred',
        500
      );
    }
  }

  private async parseRequestBody(request: Request): Promise<UploadRequestBody | null> {
    try {
      const contentType = request.headers.get('content-type');
      if (!contentType?.includes('application/json')) {
        return null;
      }

      const body = await request.json() as UploadRequestBody;
      return body;
    } catch {
      return null;
    }
  }

  private async checkRateLimit(key: string): Promise<{ allowed: boolean; retryAfter?: number }> {
    const count = await this.env.VIDEO_STATUS.get(key);
    const currentCount = count ? parseInt(count, 10) : 0;

    if (currentCount >= this.RATE_LIMIT_PER_HOUR) {
      // Get TTL to calculate retry after
      // Note: KV doesn't expose TTL directly, so we'll estimate based on window
      return {
        allowed: false,
        retryAfter: this.RATE_LIMIT_WINDOW
      };
    }

    return { allowed: true };
  }

  private async incrementRateLimit(key: string): Promise<void> {
    const count = await this.env.VIDEO_STATUS.get(key);
    const currentCount = count ? parseInt(count, 10) : 0;
    
    await this.env.VIDEO_STATUS.put(
      key,
      (currentCount + 1).toString(),
      { expirationTtl: this.RATE_LIMIT_WINDOW }
    );
  }

  private async requestStreamUpload(): Promise<{
    success: boolean;
    uid?: string;
    uploadURL?: string;
    error?: string;
  }> {
    try {
      const response = await fetch(
        `https://api.cloudflare.com/client/v4/accounts/${this.env.STREAM_ACCOUNT_ID}/stream?direct_user=true`,
        {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${this.env.CLOUDFLARE_API_TOKEN}`,
            'Content-Type': 'application/json'
          },
          body: JSON.stringify({
            maxDurationSeconds: this.MAX_DURATION_SECONDS,
            allowedOrigins: ['https://nostrvine.com', 'https://api.nostrvine.com'],
            requireSignedURLs: false,
            thumbnailTimestampPct: 0.5,
            meta: {
              name: 'NostrVine Video Upload'
            }
          })
        }
      );

      if (!response.ok) {
        const errorText = await response.text();
        console.error('Cloudflare Stream API error:', response.status, errorText);
        return {
          success: false,
          error: `Stream API returned ${response.status}`
        };
      }

      const data = await response.json() as any;
      
      if (!data.success || !data.result) {
        console.error('Cloudflare Stream API invalid response:', data);
        return {
          success: false,
          error: 'Invalid response from Stream API'
        };
      }

      return {
        success: true,
        uid: data.result.uid,
        uploadURL: data.result.uploadURL || `https://upload.videodelivery.net/${data.result.uid}`
      };
    } catch (error) {
      console.error('Error calling Cloudflare Stream API:', error);
      return {
        success: false,
        error: 'Failed to contact Stream API'
      };
    }
  }

  private errorResponse(
    code: string,
    message: string,
    status: number,
    retryAfter?: number
  ): Response {
    const error: ErrorResponse = {
      error: {
        code,
        message
      }
    };

    if (retryAfter !== undefined) {
      error.error.retryAfter = retryAfter;
    }

    return new Response(JSON.stringify(error), {
      status,
      headers: {
        'Content-Type': 'application/json',
        'Cache-Control': 'no-store'
      }
    });
  }
}