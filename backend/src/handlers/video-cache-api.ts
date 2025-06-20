// ABOUTME: Video caching API that serves video metadata with signed R2 URLs
// ABOUTME: Core endpoint for NostrVine's instant video playback system

import { checkSecurity, applySecurityHeaders } from '../services/security';

interface VideoMetadata {
  videoId: string;
  duration: number;
  renditions: {
    '480p': string;
    '720p': string;
  };
  poster: string;
  createdAt?: string;
  size?: number;
}

interface StoredVideoMetadata extends VideoMetadata {
  videoUrl: string;
  posterUrl: string;
  renditions: {
    '480p': { path: string; size: number };
    '720p': { path: string; size: number };
  };
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
    // Get a signed URL from R2
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
 * Generate video ID from URL (SHA256 hash)
 */
async function generateVideoId(url: string): Promise<string> {
  const encoder = new TextEncoder();
  const data = encoder.encode(url);
  const hashBuffer = await crypto.subtle.digest('SHA-256', data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
}

/**
 * Handle GET /api/video/{video_id}
 * Returns video metadata with signed R2 URLs
 */
export async function handleVideoMetadata(
  videoId: string,
  request: Request,
  env: Env
): Promise<Response> {
  try {
    // Check security (API key and rate limiting)
    const securityCheck = await checkSecurity(request, env);
    if (!securityCheck.allowed) {
      return applySecurityHeaders(securityCheck.response!);
    }

    console.log(`📹 Video metadata request for ID: ${videoId} (API key: ${securityCheck.apiKey})`);

    // Validate video ID format (should be 64 char hex)
    if (!/^[a-f0-9]{64}$/.test(videoId)) {
      return applySecurityHeaders(new Response(
        JSON.stringify({
          error: 'Invalid video ID format',
        }),
        {
          status: 400,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type, Authorization',
            'Cache-Control': 'no-cache',
          },
        }
      ));
    }

    // Check KV for video metadata
    const metadataKey = `video:${videoId}`;
    const storedData = await env.METADATA_CACHE.get(metadataKey);

    if (!storedData) {
      console.log(`❌ Video not found: ${videoId}`);
      return applySecurityHeaders(new Response(
        JSON.stringify({
          error: 'Video not found',
        }),
        {
          status: 404,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type, Authorization',
            'Cache-Control': 'no-cache',
          },
        }
      ));
    }

    // Parse stored metadata
    const metadata: StoredVideoMetadata = JSON.parse(storedData);

    // Generate signed URLs for all assets
    const [url480p, url720p, posterUrl] = await Promise.all([
      generateSignedUrl(env.MEDIA_BUCKET, metadata.renditions['480p'].path),
      generateSignedUrl(env.MEDIA_BUCKET, metadata.renditions['720p'].path),
      generateSignedUrl(env.MEDIA_BUCKET, metadata.posterUrl),
    ]);

    // Prepare response
    const response: VideoMetadata = {
      videoId: metadata.videoId,
      duration: metadata.duration,
      renditions: {
        '480p': url480p,
        '720p': url720p,
      },
      poster: posterUrl,
      createdAt: metadata.createdAt,
      size: metadata.size,
    };

    console.log(`✅ Returning metadata for video ${videoId}`);

    return applySecurityHeaders(new Response(JSON.stringify(response), {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization',
        'Cache-Control': 'public, max-age=300', // Cache for 5 minutes
      },
    }));
  } catch (error) {
    console.error('❌ Error handling video metadata request:', error);
    
    return applySecurityHeaders(new Response(
      JSON.stringify({
        error: 'Internal server error',
      }),
      {
        status: 500,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type, Authorization',
          'Cache-Control': 'no-cache',
        },
      }
    ));
  }
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
      'Access-Control-Max-Age': '86400',
    },
  });
}

/**
 * Populate test data in KV (for development)
 */
export async function populateTestData(env: Env): Promise<void> {
  const testVideos = [
    {
      url: 'https://example.com/video1.mp4',
      duration: 6.0,
      posterPath: 'posters/video1.jpg',
      renditions: {
        '480p': { path: 'videos/video1_480p.mp4', size: 2097152 }, // 2MB
        '720p': { path: 'videos/video1_720p.mp4', size: 5242880 }, // 5MB
      },
    },
    {
      url: 'https://example.com/video2.mp4',
      duration: 5.8,
      posterPath: 'posters/video2.jpg',
      renditions: {
        '480p': { path: 'videos/video2_480p.mp4', size: 1572864 }, // 1.5MB
        '720p': { path: 'videos/video2_720p.mp4', size: 4194304 }, // 4MB
      },
    },
  ];

  for (const video of testVideos) {
    const videoId = await generateVideoId(video.url);
    const metadata: StoredVideoMetadata = {
      videoId,
      videoUrl: video.url,
      duration: video.duration,
      posterUrl: video.posterPath,
      renditions: video.renditions,
      createdAt: new Date().toISOString(),
      size: video.renditions['720p'].size,
    };

    await env.METADATA_CACHE.put(
      `video:${videoId}`,
      JSON.stringify(metadata),
      {
        expirationTtl: 86400 * 30, // 30 days
      }
    );

    console.log(`Test data populated for video: ${videoId}`);
  }
}