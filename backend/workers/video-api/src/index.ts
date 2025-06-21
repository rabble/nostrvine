// ABOUTME: Main Worker router for NostrVine video caching API
// ABOUTME: Routes requests to appropriate handlers with CORS and error handling

import { VideoMetadataApi } from './video-metadata-api';
import { BatchVideoApi } from './batch-video-api';

export interface Env {
  VIDEO_METADATA: KVNamespace;
  VIDEO_STORAGE: R2Bucket;
  R2_PUBLIC_URL: string;
}

export default {
  async fetch(
    request: Request,
    env: Env,
    ctx: ExecutionContext
  ): Promise<Response> {
    const url = new URL(request.url);
    const pathname = url.pathname;
    const method = request.method;

    // Log incoming requests
    console.log(`${method} ${pathname}`);

    // Initialize API handlers
    const videoMetadataApi = new VideoMetadataApi(
      env.VIDEO_METADATA,
      env.VIDEO_STORAGE,
      env.R2_PUBLIC_URL || 'https://videos.nostrvine.com'
    );

    const batchVideoApi = new BatchVideoApi(
      env.VIDEO_METADATA,
      env.VIDEO_STORAGE,
      env.R2_PUBLIC_URL || 'https://videos.nostrvine.com'
    );

    try {
      // Health check endpoint
      if (pathname === '/health' && method === 'GET') {
        return new Response(JSON.stringify({
          status: 'healthy',
          service: 'nostrvine-video-api',
          timestamp: new Date().toISOString()
        }), {
          status: 200,
          headers: {
            'Content-Type': 'application/json',
            'Cache-Control': 'no-cache'
          }
        });
      }

      // Single video metadata endpoint
      if (pathname.startsWith('/api/video/') && method === 'GET') {
        const videoId = pathname.split('/api/video/')[1];
        if (!videoId) {
          return new Response(JSON.stringify({
            error: 'Video ID required'
          }), {
            status: 400,
            headers: {
              'Content-Type': 'application/json'
            }
          });
        }
        return videoMetadataApi.handleGetVideoMetadata(videoId);
      }

      // Single video OPTIONS
      if (pathname.startsWith('/api/video/') && method === 'OPTIONS') {
        return videoMetadataApi.handleOptions();
      }

      // Batch video lookup endpoint
      if (pathname === '/api/videos/batch' && method === 'POST') {
        return batchVideoApi.handleBatchVideoLookup(request);
      }

      // Batch video OPTIONS
      if (pathname === '/api/videos/batch' && method === 'OPTIONS') {
        return batchVideoApi.handleOptions();
      }

      // 404 for unmatched routes
      return new Response(JSON.stringify({
        error: 'Not found',
        message: `Endpoint ${pathname} not found`,
        availableEndpoints: [
          'GET /health',
          'GET /api/video/{videoId}',
          'POST /api/videos/batch'
        ]
      }), {
        status: 404,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        }
      });

    } catch (error) {
      console.error('Worker error:', error);
      
      return new Response(JSON.stringify({
        error: 'Internal server error',
        message: error instanceof Error ? error.message : 'Unknown error'
      }), {
        status: 500,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        }
      });
    }
  }
};

// Export for testing
export { VideoMetadataApi, BatchVideoApi };