// ABOUTME: Batch video lookup API for efficient bulk metadata retrieval
// ABOUTME: Enables clients to fetch metadata for multiple videos discovered via Nostr events

import { checkSecurity, applySecurityHeaders } from '../services/security';

interface BatchVideoRequest {
  videoIds: string[];
  quality?: 'auto' | '480p' | '720p';
}

interface VideoMetadataResponse {
  videoId: string;
  duration: number;
  renditions: {
    '480p': string;
    '720p': string;
  };
  poster: string;
  available: boolean;
  reason?: string;
}

interface BatchVideoResponse {
  videos: Record<string, VideoMetadataResponse>;
  found: number;
  missing: number;
}

interface StoredVideoMetadata {
  videoId: string;
  videoUrl: string;
  duration: number;
  posterUrl: string;
  renditions: {
    '480p': { path: string; size: number };
    '720p': { path: string; size: number };
  };
  createdAt?: string;
  size?: number;
}

/**
 * Generate a signed R2 URL with 5-minute expiry
 */
async function generateSignedUrl(
  bucket: R2Bucket,
  objectKey: string,
  expiresIn: number = 300 // 5 minutes
): Promise<string> {
  try {
    const signedUrl = await bucket.createSignedUrl(objectKey, {
      expiresIn,
    });
    return signedUrl;
  } catch (error) {
    console.error(`Failed to generate signed URL for ${objectKey}:`, error);
    throw new Error('Failed to generate signed URL');
  }
}

/**
 * Generate signed URLs for video renditions in parallel
 */
async function generateSignedUrls(
  metadata: StoredVideoMetadata,
  bucket: R2Bucket,
  quality: 'auto' | '480p' | '720p' | undefined
): Promise<{ '480p': string; '720p': string }> {
  // For auto quality, we'll return both and let client decide
  if (quality === '480p') {
    const url480p = await generateSignedUrl(bucket, metadata.renditions['480p'].path);
    return { '480p': url480p, '720p': '' };
  } else if (quality === '720p') {
    const url720p = await generateSignedUrl(bucket, metadata.renditions['720p'].path);
    return { '480p': '', '720p': url720p };
  } else {
    // Auto or undefined - return both
    const [url480p, url720p] = await Promise.all([
      generateSignedUrl(bucket, metadata.renditions['480p'].path),
      generateSignedUrl(bucket, metadata.renditions['720p'].path),
    ]);
    return { '480p': url480p, '720p': url720p };
  }
}

/**
 * Handle POST /api/videos/batch
 * Returns metadata for multiple videos with signed R2 URLs
 */
export async function handleBatchVideoLookup(
  request: Request,
  env: Env
): Promise<Response> {
  try {
    // Check security (API key and rate limiting)
    const securityCheck = await checkSecurity(request, env);
    if (!securityCheck.allowed) {
      return applySecurityHeaders(securityCheck.response!);
    }

    console.log(`📦 Batch video lookup request (API key: ${securityCheck.apiKey})`);

    // Parse request body
    let body: BatchVideoRequest;
    try {
      body = await request.json();
    } catch (e) {
      return applySecurityHeaders(new Response(
        JSON.stringify({
          error: 'Invalid request body',
        }),
        {
          status: 400,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'POST, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type, Authorization',
          },
        }
      ));
    }

    // Validate input
    if (!body.videoIds || !Array.isArray(body.videoIds)) {
      return applySecurityHeaders(new Response(
        JSON.stringify({
          error: 'videoIds must be an array',
        }),
        {
          status: 400,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'POST, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type, Authorization',
          },
        }
      ));
    }

    // Limit batch size
    if (body.videoIds.length > 50) {
      return applySecurityHeaders(new Response(
        JSON.stringify({
          error: 'Maximum 50 video IDs per request',
        }),
        {
          status: 400,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'POST, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type, Authorization',
          },
        }
      ));
    }

    // Remove duplicates
    const uniqueVideoIds = [...new Set(body.videoIds)];
    console.log(`📦 Batch lookup for ${uniqueVideoIds.length} videos`);

    // Parallel KV lookups
    const metadataPromises = uniqueVideoIds.map(async (videoId) => {
      // Validate video ID format
      if (!/^[a-f0-9]{64}$/.test(videoId)) {
        return { videoId, error: 'invalid_format' };
      }

      const metadataKey = `video:${videoId}`;
      const storedData = await env.METADATA_CACHE.get(metadataKey);
      
      if (!storedData) {
        return { videoId, error: 'not_found' };
      }

      try {
        const metadata: StoredVideoMetadata = JSON.parse(storedData);
        return { videoId, metadata };
      } catch (e) {
        return { videoId, error: 'parse_error' };
      }
    });

    // Wait for all lookups
    const lookupResults = await Promise.all(metadataPromises);

    // Process results and generate signed URLs in parallel
    const videoPromises = lookupResults.map(async (result) => {
      if ('error' in result) {
        return {
          videoId: result.videoId,
          response: {
            videoId: result.videoId,
            available: false,
            reason: result.error,
          } as VideoMetadataResponse,
        };
      }

      try {
        const metadata = result.metadata!;
        
        // Generate signed URLs
        const [renditions, posterUrl] = await Promise.all([
          generateSignedUrls(metadata, env.MEDIA_BUCKET, body.quality),
          generateSignedUrl(env.MEDIA_BUCKET, metadata.posterUrl),
        ]);

        return {
          videoId: result.videoId,
          response: {
            videoId: metadata.videoId,
            duration: metadata.duration,
            renditions,
            poster: posterUrl,
            available: true,
          } as VideoMetadataResponse,
        };
      } catch (error) {
        console.error(`Error processing video ${result.videoId}:`, error);
        return {
          videoId: result.videoId,
          response: {
            videoId: result.videoId,
            available: false,
            reason: 'processing_error',
          } as VideoMetadataResponse,
        };
      }
    });

    // Wait for all processing
    const videoResults = await Promise.all(videoPromises);

    // Build response
    const videos: Record<string, VideoMetadataResponse> = {};
    let found = 0;
    let missing = 0;

    for (const result of videoResults) {
      videos[result.videoId] = result.response;
      if (result.response.available) {
        found++;
      } else {
        missing++;
      }
    }

    const response: BatchVideoResponse = {
      videos,
      found,
      missing,
    };

    console.log(`✅ Batch lookup complete: ${found} found, ${missing} missing`);

    return applySecurityHeaders(new Response(JSON.stringify(response), {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization',
        'Cache-Control': 'public, max-age=300', // Cache for 5 minutes
      },
    }));
  } catch (error) {
    console.error('❌ Error handling batch video lookup:', error);
    
    return applySecurityHeaders(new Response(
      JSON.stringify({
        error: 'Internal server error',
      }),
      {
        status: 500,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'POST, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type, Authorization',
        },
      }
    ));
  }
}

/**
 * Handle OPTIONS preflight for CORS
 */
export function handleBatchVideoOptions(): Response {
  return new Response(null, {
    status: 204,
    headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
      'Access-Control-Max-Age': '86400',
    },
  });
}