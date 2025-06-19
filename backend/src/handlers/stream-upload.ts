// ABOUTME: Cloudflare Stream upload request handler with NIP-98 authentication
// ABOUTME: Generates secure upload URLs and manages video status with rate limiting

import { validateNIP98Auth, createAuthErrorResponse } from '../utils/nip98-auth';

/**
 * Handle POST /v1/media/request-upload - Cloudflare Stream upload request
 */
export async function handleStreamUploadRequest(request: Request, env: Env): Promise<Response> {
  try {
    // Validate NIP-98 authentication
    const authResult = await validateNIP98Auth(request);
    if (!authResult.valid) {
      return createAuthErrorResponse(authResult.error || 'Authentication failed', authResult.errorCode);
    }

    const { pubkey } = authResult;

    // Parse request body
    let requestData: any = {};
    try {
      const body = await request.text();
      if (body.trim()) {
        requestData = JSON.parse(body);
      }
    } catch (e) {
      return new Response(JSON.stringify({
        error: {
          code: 'invalid_request',
          message: 'Invalid JSON in request body'
        }
      }), { 
        status: 400,
        headers: { 'Content-Type': 'application/json' }
      });
    }

    // Validate optional request fields
    const fileName = requestData.fileName || 'video.mp4';
    const fileSize = requestData.fileSize || 0;

    // Check rate limiting (30 uploads per hour per pubkey)
    const rateLimitResult = await checkRateLimit(pubkey!, env);
    if (!rateLimitResult.allowed) {
      return new Response(JSON.stringify({
        error: {
          code: 'rate_limit_exceeded',
          message: `Upload limit of 30 per hour exceeded. ${rateLimitResult.remaining} uploads remaining.`,
          retryAfter: rateLimitResult.retryAfter
        }
      }), {
        status: 429,
        headers: { 'Content-Type': 'application/json' }
      });
    }

    // Generate unique video ID
    const videoId = crypto.randomUUID();

    // Call Cloudflare Stream API to get upload URL
    const streamResponse = await createStreamUpload(fileName, env);
    if (!streamResponse.success) {
      return new Response(JSON.stringify({
        error: {
          code: 'service_unavailable',
          message: 'Cloudflare Stream API temporarily unavailable'
        }
      }), {
        status: 503,
        headers: { 'Content-Type': 'application/json' }
      });
    }

    // Store initial video status in KV
    const videoStatus = {
      videoId,
      nostrPubkey: pubkey,
      status: 'pending_upload',
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
      source: {
        uploadedAt: null,
        error: null,
        fileName,
        fileSize
      },
      stream: {
        uid: streamResponse.result.uid,
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

    // Store video status and increment rate limit in parallel
    await Promise.all([
      env.METADATA_CACHE.put(`v1:video:${videoId}`, JSON.stringify(videoStatus)),
      incrementRateLimit(pubkey!, env)
    ]);

    // Return success response
    return new Response(JSON.stringify({
      videoId,
      uploadURL: streamResponse.result.uploadURL,
      expiresAt: new Date(Date.now() + 3600000).toISOString() // 1 hour from now
    }), {
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      }
    });

  } catch (error) {
    console.error('Stream upload request error:', error);
    return new Response(JSON.stringify({
      error: {
        code: 'internal_error',
        message: 'Internal server error'
      }
    }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' }
    });
  }
}

/**
 * Handle OPTIONS /v1/media/request-upload
 */
export function handleStreamUploadOptions(): Response {
  return new Response(null, {
    status: 204,
    headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
      'Access-Control-Max-Age': '86400'
    }
  });
}

/**
 * Call Cloudflare Stream API to create upload URL with security constraints
 */
async function createStreamUpload(fileName: string, env: Env): Promise<StreamAPIResponse> {
  try {
    const accountId = env.CLOUDFLARE_ACCOUNT_ID;
    const token = env.CLOUDFLARE_STREAM_TOKEN;
    
    const url = `https://api.cloudflare.com/client/v4/accounts/${accountId}/stream/direct_upload`;

    const requestBody = {
      maxDurationSeconds: 300,
      meta: {
        name: fileName
      }
    };

    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(requestBody)
    });

    const data = await response.json();
    
    if (!response.ok) {
      console.error('Cloudflare Stream API error:', data);
      return { success: false, errors: data.errors || [] };
    }
    return {
      success: true,
      result: {
        uid: data.result.uid,
        uploadURL: data.result.uploadURL
      }
    };

  } catch (error) {
    console.error('Stream API call failed:', error);
    return { success: false, errors: [{ message: 'Network error' }] };
  }
}

/**
 * Check rate limiting for a user (30 uploads per hour)
 */
async function checkRateLimit(pubkey: string, env: Env): Promise<RateLimitResult> {
  const rateLimitKey = `ratelimit:upload:${pubkey}`;
  const current = await env.METADATA_CACHE.get(rateLimitKey);
  const count = current ? parseInt(current) : 0;

  const allowed = count < 30;
  const remaining = Math.max(0, 30 - count);
  const retryAfter = allowed ? 0 : 3600; // 1 hour

  return {
    allowed,
    count,
    remaining,
    retryAfter
  };
}

/**
 * Increment rate limit counter
 */
async function incrementRateLimit(pubkey: string, env: Env): Promise<void> {
  const rateLimitKey = `ratelimit:upload:${pubkey}`;
  const current = await env.METADATA_CACHE.get(rateLimitKey);
  const count = current ? parseInt(current) : 0;

  await env.METADATA_CACHE.put(
    rateLimitKey, 
    (count + 1).toString(), 
    { expirationTtl: 3600 } // 1 hour TTL
  );
}

// Type definitions
interface StreamAPIResponse {
  success: boolean;
  result?: {
    uid: string;
    uploadURL: string;
  };
  errors?: Array<{ message: string }>;
}

interface RateLimitResult {
  allowed: boolean;
  count: number;
  remaining: number;
  retryAfter: number;
}