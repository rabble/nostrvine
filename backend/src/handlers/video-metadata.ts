// ABOUTME: Video metadata retrieval API for processed Cloudinary videos
// ABOUTME: Allows clients to fetch processing status and URLs for uploaded videos

import { validateNIP98Auth, createAuthErrorResponse } from '../utils/nip98-auth';

export interface VideoMetadataResponse {
  public_id: string;
  secure_url?: string;
  format: string;
  width: number;
  height: number;
  bytes: number;
  duration?: number;
  resource_type: string;
  created_at: string;
  processing_status: 'pending_moderation' | 'approved' | 'rejected' | 'failed' | 'transferring' | 'ready' | 'completed' | 'processing';
  // R2 storage information
  r2_url?: string;
  r2_key?: string;
  transferred_at?: string;
  cdn_url?: string;
  eager_transformations?: Array<{
    transformation: string;
    url: string;
    format: string;
    bytes: number;
  }>;
  nip94_metadata?: {
    url: string;
    m: string;
    x: string;
    size: string;
    dim?: string;
    alt?: string;
    magnet?: string;
    blurhash?: string;
  };
}

/**
 * Get video metadata by public_id
 * GET /v1/media/metadata/{public_id}
 */
export async function handleVideoMetadata(
  publicId: string,
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
    console.log(`🔍 Metadata request for ${publicId} by user ${userPubkey.substring(0, 8)}...`);

    // Get metadata from KV store
    const metadataKey = `video_metadata:${publicId}`;
    const metadataJson = await env.METADATA_CACHE.get(metadataKey);

    if (!metadataJson) {
      return new Response(JSON.stringify({
        status: 'error',
        message: `Video metadata not found for public_id: ${publicId}`,
        error_code: 'not_found'
      }), {
        status: 404,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        }
      });
    }

    let metadata;
    try {
      metadata = JSON.parse(metadataJson);
    } catch (e) {
      console.error('Failed to parse stored metadata:', e);
      return new Response(JSON.stringify({
        status: 'error',
        message: 'Invalid metadata format',
        error_code: 'invalid_data'
      }), {
        status: 500,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        }
      });
    }

    // Verify user owns this video
    if (metadata.user_pubkey !== userPubkey) {
      return new Response(JSON.stringify({
        status: 'error',
        message: 'Access denied: video belongs to another user',
        error_code: 'forbidden'
      }), {
        status: 403,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        }
      });
    }

    // Prepare response with NIP-94 metadata if available
    const response: VideoMetadataResponse = {
      ...metadata
    };

    // Generate NIP-94 metadata for completed videos
    if ((metadata.processing_status === 'completed' || metadata.processing_status === 'approved' || metadata.processing_status === 'ready') && (metadata.secure_url || metadata.cdn_url)) {
      response.nip94_metadata = generateNIP94Metadata(metadata);
    }

    console.log(`✅ Returning metadata for ${publicId}, status: ${metadata.processing_status}`);

    return new Response(JSON.stringify({
      status: 'success',
      data: response
    }), {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      }
    });

  } catch (error) {
    console.error('❌ Video metadata retrieval error:', error);
    
    return new Response(JSON.stringify({
      status: 'error',
      message: 'Failed to retrieve video metadata',
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
 * List user's uploaded videos
 * GET /v1/media/list
 */
export async function handleVideoList(
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
    console.log(`📋 Video list request by user ${userPubkey.substring(0, 8)}...`);

    // Get user's video list from KV store
    const userVideosKey = `user_videos:${userPubkey}`;
    const videosListJson = await env.METADATA_CACHE.get(userVideosKey);

    let videosList: string[] = [];
    if (videosListJson) {
      try {
        videosList = JSON.parse(videosListJson);
      } catch (e) {
        console.warn('Failed to parse videos list, returning empty');
      }
    }

    // Get metadata for each video (up to 20 most recent)
    const recentVideos = videosList.slice(0, 20);
    const videosWithMetadata = [];

    for (const publicId of recentVideos) {
      const metadataKey = `video_metadata:${publicId}`;
      const metadataJson = await env.METADATA_CACHE.get(metadataKey);
      
      if (metadataJson) {
        try {
          const metadata = JSON.parse(metadataJson);
          
          // Create summary metadata (excluding large fields)
          const summary = {
            public_id: metadata.public_id,
            processing_status: metadata.processing_status,
            created_at: metadata.created_at,
            format: metadata.format,
            width: metadata.width,
            height: metadata.height,
            bytes: metadata.bytes,
            secure_url: metadata.processing_status === 'completed' ? metadata.secure_url : undefined
          };

          videosWithMetadata.push(summary);
        } catch (e) {
          console.warn(`Failed to parse metadata for ${publicId}`);
        }
      }
    }

    console.log(`✅ Returning ${videosWithMetadata.length} videos for user ${userPubkey.substring(0, 8)}...`);

    return new Response(JSON.stringify({
      status: 'success',
      data: {
        total: videosWithMetadata.length,
        videos: videosWithMetadata
      }
    }), {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      }
    });

  } catch (error) {
    console.error('❌ Video list retrieval error:', error);
    
    return new Response(JSON.stringify({
      status: 'error',
      message: 'Failed to retrieve video list',
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
 * Generate NIP-94 metadata for a processed video
 */
function generateNIP94Metadata(metadata: any): VideoMetadataResponse['nip94_metadata'] {
  // Create file hash from Cloudinary public_id + timestamp (deterministic)
  const hashInput = `${metadata.public_id}:${metadata.created_at}`;
  const hash = btoa(hashInput).substring(0, 32); // Simple hash for demo

  // Prefer CDN URL over Cloudinary URL
  const videoUrl = metadata.cdn_url || metadata.secure_url;

  const nip94: VideoMetadataResponse['nip94_metadata'] = {
    url: videoUrl,
    m: `video/${metadata.format}`,
    x: hash, // Should be actual file hash in production
    size: metadata.bytes.toString()
  };

  // Add dimensions if available
  if (metadata.width && metadata.height) {
    nip94.dim = `${metadata.width}x${metadata.height}`;
  }

  // Add duration if available (would need to be added by webhook)
  if (metadata.duration) {
    nip94.alt = `Video duration: ${metadata.duration}s`;
  }

  return nip94;
}

/**
 * Handle OPTIONS preflight for CORS
 */
export function handleVideoMetadataOptions(): Response {
  return new Response(null, {
    status: 204,
    headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
      'Access-Control-Max-Age': '86400'
    }
  });
}