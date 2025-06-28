// ABOUTME: Cloudinary signed upload endpoint for secure video processing
// ABOUTME: Generates signed upload URLs while keeping API secrets secure in Workers

import { validateNIP98Auth, createAuthErrorResponse } from '../utils/nip98-auth';

export interface CloudinaryUploadRequest {
  filename?: string;
  contentType?: string;
  fileSize?: number;
}

export interface CloudinarySignedResponse {
  signature: string;
  timestamp: number;
  api_key: string;
  cloud_name: string;
  upload_preset: string;
  public_id: string;
  context: string;
  folder: string;
}

/**
 * Handle Cloudinary signed upload request
 * POST /v1/media/request-upload
 */
export async function handleCloudinarySignedUpload(
  request: Request,
  env: Env
): Promise<Response> {
  try {
    // Validate NIP-98 authentication
    const authResult = await validateNIP98Auth(request);
    if (!authResult.valid) {
      return createAuthErrorResponse(
        authResult.error || 'Authentication failed',
        authResult.errorCode
      );
    }

    const userPubkey = authResult.pubkey!;
    console.log(`🔐 Authenticated upload request from pubkey: ${userPubkey.substring(0, 8)}...`);

    // Parse request body for upload parameters
    let uploadParams: CloudinaryUploadRequest = {};
    if (request.headers.get('content-type')?.includes('application/json')) {
      try {
        uploadParams = await request.json();
      } catch (e) {
        // Ignore JSON parsing errors, use defaults
      }
    }

    // Validate file constraints
    const maxFileSize = 50 * 1024 * 1024; // 50MB limit
    if (uploadParams.fileSize && uploadParams.fileSize > maxFileSize) {
      return new Response(JSON.stringify({
        status: 'error',
        message: `File size ${uploadParams.fileSize} exceeds maximum allowed size of ${maxFileSize} bytes`,
        error_code: 'file_too_large'
      }), {
        status: 400,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        }
      });
    }

    // Validate content type
    const allowedTypes = ['video/mp4', 'video/quicktime', 'video/webm', 'image/gif'];
    if (uploadParams.contentType && !allowedTypes.includes(uploadParams.contentType)) {
      return new Response(JSON.stringify({
        status: 'error',
        message: `Content type ${uploadParams.contentType} not supported. Allowed types: ${allowedTypes.join(', ')}`,
        error_code: 'invalid_file_type'
      }), {
        status: 400,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        }
      });
    }

    // Generate unique public_id for this upload
    const timestamp = Math.floor(Date.now() / 1000);
    const randomSuffix = Math.random().toString(36).substring(2, 15);
    const publicId = `nostrvine/${userPubkey.substring(0, 16)}/${timestamp}_${randomSuffix}`;

    // Prepare upload parameters with user context
    const uploadOptions = {
      timestamp: timestamp,
      public_id: publicId,
      folder: 'nostrvine',
      upload_preset: 'nostrvine_videos', // This must be configured in Cloudinary dashboard
      context: `pubkey=${userPubkey}|app=nostrvine|version=1.0`,
      // Notification URL for webhook
      notification_url: `${new URL(request.url).origin}/v1/media/webhook`,
      // Resource type
      resource_type: 'auto',
      // Enable Google AI video moderation for adult content detection
      moderation: 'google_video_moderation'
    };

    // Generate signature using Web Crypto API
    const signature = await generateCloudinarySignature(uploadOptions, env.CLOUDINARY_API_SECRET);

    // Prepare response with signed upload parameters
    const response: CloudinarySignedResponse = {
      signature: signature,
      timestamp: timestamp,
      api_key: env.CLOUDINARY_API_KEY,
      cloud_name: env.CLOUDINARY_CLOUD_NAME,
      upload_preset: 'nostrvine_videos',
      public_id: publicId,
      context: uploadOptions.context,
      folder: 'nostrvine'
    };

    console.log(`✅ Generated signed upload for user ${userPubkey.substring(0, 8)}... with public_id: ${publicId}`);

    return new Response(JSON.stringify({
      status: 'success',
      data: response,
      upload_url: `https://api.cloudinary.com/v1_1/${env.CLOUDINARY_CLOUD_NAME}/auto/upload`,
      expires_in: 600 // 10 minutes
    }), {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      }
    });

  } catch (error) {
    console.error('❌ Cloudinary signed upload error:', error);
    
    return new Response(JSON.stringify({
      status: 'error',
      message: 'Failed to generate signed upload URL',
      error_code: 'server_error'
    }), {
      status: 500,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      }
    });
  }
}

/**
 * Handle OPTIONS preflight for CORS
 */
export function handleCloudinaryUploadOptions(): Response {
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
 * Generate Cloudinary signature using Web Crypto API
 * Based on Cloudinary's signature algorithm: SHA-1 hash of parameters + API secret
 */
async function generateCloudinarySignature(
  params: Record<string, any>,
  apiSecret: string
): Promise<string> {
  // Sort parameters alphabetically and create query string (excluding signature)
  const sortedParams = Object.keys(params)
    .filter(key => key !== 'signature' && params[key] !== undefined && params[key] !== '')
    .sort()
    .map(key => `${key}=${params[key]}`)
    .join('&');

  // Create string to sign: sorted_params + api_secret
  const stringToSign = sortedParams + apiSecret;

  // Generate SHA-1 hash
  const encoder = new TextEncoder();
  const data = encoder.encode(stringToSign);
  const hashBuffer = await crypto.subtle.digest('SHA-1', data);
  const hashArray = new Uint8Array(hashBuffer);
  
  // Convert to hex string
  return Array.from(hashArray)
    .map(b => b.toString(16).padStart(2, '0'))
    .join('');
}