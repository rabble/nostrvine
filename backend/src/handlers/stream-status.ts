// ABOUTME: Video status polling endpoint with UUID validation and caching optimization
// ABOUTME: Returns conditional responses based on video processing state

/**
 * Handle GET /v1/media/status/:videoId - Video status check
 */
export async function handleVideoStatus(videoId: string, request: Request, env: Env): Promise<Response> {
  try {
    // Validate UUID format (security against enumeration)
    if (!isValidUUID(videoId)) {
      return errorResponse('invalid_video_id', 'Video ID must be a valid UUID', 400);
    }

    // Fetch video status from KV
    const statusData = await env.METADATA_CACHE.get(`v1:video:${videoId}`);
    
    if (!statusData) {
      return errorResponse('video_not_found', 'Video not found', 404);
    }

    const videoStatus = JSON.parse(statusData);
    
    // Build conditional response based on status
    const response = buildStatusResponse(videoStatus, env);
    const cacheHeaders = getCacheHeaders(videoStatus.status);
    
    return new Response(JSON.stringify(response), {
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        ...cacheHeaders
      }
    });
    
  } catch (error) {
    console.error('Status check error:', error);
    return errorResponse('internal_error', 'Internal server error', 500);
  }
}

/**
 * Handle OPTIONS /v1/media/status/:videoId
 */
export function handleVideoStatusOptions(): Response {
  return new Response(null, {
    status: 204,
    headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
      'Access-Control-Max-Age': '86400'
    }
  });
}

/**
 * Build status response based on video state
 */
function buildStatusResponse(videoStatus: any, env: Env): any {
  const baseResponse = {
    status: videoStatus.status
  };
  
  // Only include URLs and metadata for published videos
  if (videoStatus.status === 'published') {
    return {
      ...baseResponse,
      hlsUrl: videoStatus.stream.hlsUrl,
      dashUrl: videoStatus.stream.dashUrl,
      thumbnailUrl: transformToCloudflareImagesUrl(
        videoStatus.stream.thumbnailUrl, 
        env.CLOUDFLARE_IMAGES_ACCOUNT_HASH
      ),
      createdAt: videoStatus.createdAt
    };
  }
  
  // For failed videos, include user-friendly error message
  if (videoStatus.status === 'failed' && videoStatus.source.error) {
    return {
      ...baseResponse,
      error: getUserFriendlyError(videoStatus.source.error)
    };
  }
  
  // For all other statuses, return minimal information
  return baseResponse;
}

/**
 * Transform Stream thumbnail URL to optimized Cloudflare Images URL
 */
function transformToCloudflareImagesUrl(streamThumbnailUrl: string | null, accountHash: string): string | null {
  if (!streamThumbnailUrl || !accountHash) {
    return streamThumbnailUrl;
  }

  // Transform Stream thumbnail to optimized Cloudflare Images URL
  // Input: https://videodelivery.net/uid/thumbnails/thumbnail.jpg
  // Output: https://imagedelivery.net/account-hash/uid/w=400,h=300
  
  const streamUidMatch = streamThumbnailUrl.match(/videodelivery\.net\/([^\/]+)/);
  if (!streamUidMatch) {
    console.warn('Could not extract UID from thumbnail URL:', streamThumbnailUrl);
    return streamThumbnailUrl; // Fallback to original
  }
  
  const uid = streamUidMatch[1];
  
  // Return optimized thumbnail (400x300 for mobile feeds)
  return `https://imagedelivery.net/${accountHash}/${uid}/w=400,h=300`;
}

/**
 * Get appropriate cache headers based on video status
 */
function getCacheHeaders(status: string): Record<string, string> {
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

/**
 * Validate UUID v4 format
 */
function isValidUUID(uuid: string): boolean {
  const uuidV4Regex = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  return uuidV4Regex.test(uuid);
}

/**
 * Map internal errors to user-friendly messages
 */
function getUserFriendlyError(internalError: string): string {
  if (internalError.includes('timeout')) {
    return 'Processing timeout - please try uploading again';
  }
  if (internalError.includes('moderation')) {
    return 'Video processing failed - please contact support';
  }
  if (internalError.includes('Stream processing failed')) {
    return 'Video processing failed - please try again';
  }
  return 'Processing failed - please try again';
}

/**
 * Create standardized error response
 */
function errorResponse(code: string, message: string, status: number): Response {
  return new Response(JSON.stringify({
    error: { code, message }
  }), { 
    status,
    headers: { 
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*'
    }
  });
}