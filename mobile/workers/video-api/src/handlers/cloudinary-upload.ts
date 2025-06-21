// ABOUTME: Handles Cloudinary signed upload requests with NIP-98 authentication
// ABOUTME: Generates secure upload signatures and stores upload status

import { Env, ExecutionContext } from '../types';
import { validateNIP98Event, NIP98AuthError } from '../lib/auth';
import { CloudinarySignerService } from '../services/cloudinary-signer';
import { UploadRequestBody, SignedUploadResponse } from '../types/cloudinary';

interface ErrorResponse {
  error: {
    code: string;
    message: string;
    retryAfter?: number;
  };
}

interface CloudinaryUploadStatus {
  videoId: string;
  nostrPubkey: string;
  status: 'pending_upload' | 'uploading' | 'processing' | 'completed' | 'failed';
  createdAt: string;
  updatedAt: string;
  cloudinary: {
    public_id: string | null;
    secure_url: string | null;
    eager_urls: Record<string, string>;
    upload_preset: string;
  };
  source: {
    uploadedAt: string | null;
    error: string | null;
    file_size: number;
    file_type: string;
  };
  moderation: {
    status: 'pending' | 'approved' | 'rejected';
    flaggedCategories: string[];
    checkedAt: string | null;
  };
}

export class CloudinaryUploadHandler {
  private env: Env;
  private signerService: CloudinarySignerService;
  private readonly RATE_LIMIT_PER_HOUR = 30;
  private readonly RATE_LIMIT_WINDOW = 3600; // 1 hour in seconds
  private readonly MAX_FILE_SIZE = 500 * 1024 * 1024; // 500MB

  constructor(env: Env) {
    this.env = env;
    
    // Initialize Cloudinary signer service
    this.signerService = new CloudinarySignerService({
      cloud_name: env.CLOUDINARY_CLOUD_NAME || '',
      api_key: env.CLOUDINARY_API_KEY || '',
      api_secret: env.CLOUDINARY_API_SECRET || ''
    }, env.WORKER_URL);
  }

  async handleRequest(request: Request, ctx: ExecutionContext): Promise<Response> {
    try {
      // Validate Cloudinary configuration
      const configValidation = this.signerService.validateConfig();
      if (!configValidation.valid) {
        console.error('Cloudinary configuration invalid:', configValidation.errors);
        return this.errorResponse(
          'service_unavailable',
          'Upload service is not configured',
          503
        );
      }

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
      const validation = this.validateUploadRequest(body);
      if (!validation.valid) {
        return this.errorResponse('invalid_request', validation.error!, 400);
      }

      // Check rate limit
      const rateLimitResult = await this.checkRateLimit(pubkey);
      if (!rateLimitResult.allowed) {
        return this.errorResponse(
          'rate_limit_exceeded',
          'Upload limit of 30 per hour exceeded',
          429,
          rateLimitResult.retryAfter
        );
      }

      // Generate Cloudinary signed upload parameters
      const signedParams = await this.signerService.generateSignedUploadParams(pubkey, {
        fileType: body.file_type,
        maxFileSize: body.byte_size,
        resourceType: this.getResourceType(body.file_type)
      });

      // Generate video ID and store initial status
      const videoId = crypto.randomUUID();
      const uploadStatus: CloudinaryUploadStatus = {
        videoId,
        nostrPubkey: pubkey,
        status: 'pending_upload',
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
        cloudinary: {
          public_id: null,
          secure_url: null,
          eager_urls: {},
          upload_preset: signedParams.upload_preset
        },
        source: {
          uploadedAt: null,
          error: null,
          file_size: body.byte_size || 0,
          file_type: body.file_type
        },
        moderation: {
          status: 'pending',
          flaggedCategories: [],
          checkedAt: null
        }
      };

      // Store upload status and increment rate limit counter
      await Promise.all([
        this.env.VIDEO_STATUS.put(
          `v1:video:${videoId}`,
          JSON.stringify(uploadStatus),
          { expirationTtl: 86400 * 7 } // 7 days TTL
        ),
        this.incrementRateLimit(pubkey)
      ]);

      // Build response with Cloudinary upload URL and parameters
      const response = {
        videoId,
        uploadURL: `https://api.cloudinary.com/v1_1/${signedParams.cloud_name}/video/upload`,
        uploadParams: {
          api_key: signedParams.api_key,
          timestamp: signedParams.timestamp,
          signature: signedParams.signature,
          upload_preset: signedParams.upload_preset,
          context: signedParams.context
        },
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
      console.error('Error handling Cloudinary upload request:', error);
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

  private validateUploadRequest(body: UploadRequestBody): { valid: boolean; error?: string } {
    if (!body.file_type || typeof body.file_type !== 'string') {
      return { valid: false, error: 'file_type is required' };
    }

    if (body.byte_size !== undefined) {
      if (typeof body.byte_size !== 'number' || body.byte_size <= 0) {
        return { valid: false, error: 'byte_size must be a positive number' };
      }

      if (body.byte_size > this.MAX_FILE_SIZE) {
        return {
          valid: false,
          error: `File size exceeds maximum of ${this.MAX_FILE_SIZE / 1024 / 1024}MB`
        };
      }
    }

    // Validate file type
    const allowedTypes = [
      'video/mp4', 'video/mov', 'video/avi', 'video/webm', 'video/mkv',
      'image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/webp'
    ];

    if (!allowedTypes.includes(body.file_type.toLowerCase())) {
      return {
        valid: false,
        error: `Unsupported file type: ${body.file_type}`
      };
    }

    return { valid: true };
  }

  private getResourceType(fileType: string): 'video' | 'image' | 'auto' {
    if (fileType.startsWith('video/')) {
      return 'video';
    } else if (fileType.startsWith('image/')) {
      return 'image';
    } else {
      return 'auto';
    }
  }

  private async checkRateLimit(pubkey: string): Promise<{ allowed: boolean; retryAfter?: number }> {
    const rateLimitKey = `ratelimit:upload:${pubkey}`;
    const count = await this.env.VIDEO_STATUS.get(rateLimitKey);
    const currentCount = count ? parseInt(count, 10) : 0;

    if (currentCount >= this.RATE_LIMIT_PER_HOUR) {
      return {
        allowed: false,
        retryAfter: this.RATE_LIMIT_WINDOW
      };
    }

    return { allowed: true };
  }

  private async incrementRateLimit(pubkey: string): Promise<void> {
    const rateLimitKey = `ratelimit:upload:${pubkey}`;
    const count = await this.env.VIDEO_STATUS.get(rateLimitKey);
    const currentCount = count ? parseInt(count, 10) : 0;
    
    await this.env.VIDEO_STATUS.put(
      rateLimitKey,
      (currentCount + 1).toString(),
      { expirationTtl: this.RATE_LIMIT_WINDOW }
    );
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