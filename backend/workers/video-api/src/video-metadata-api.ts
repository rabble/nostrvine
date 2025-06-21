// ABOUTME: Video metadata API handler that serves video information with signed R2 URLs
// ABOUTME: Provides single video metadata lookup with quality renditions and poster images

import { MetadataStore } from './metadata-store';
import { R2UrlSigner } from './r2-url-signer';

export interface VideoMetadataResponse {
  videoId: string;
  duration: number;
  renditions: {
    '480p': string;
    '720p': string;
  };
  poster: string;
}

export class VideoMetadataApi {
  private metadataStore: MetadataStore;
  private urlSigner: R2UrlSigner;

  constructor(
    kvNamespace: KVNamespace,
    r2Bucket: R2Bucket,
    baseUrl: string
  ) {
    this.metadataStore = new MetadataStore(kvNamespace);
    this.urlSigner = new R2UrlSigner(r2Bucket, baseUrl);
  }

  /**
   * Handle GET /api/video/{video_id}
   */
  async handleGetVideoMetadata(videoId: string): Promise<Response> {
    try {
      // Validate video ID format
      if (!videoId || videoId.length === 0) {
        return new Response(JSON.stringify({
          error: 'Invalid video ID'
        }), {
          status: 400,
          headers: {
            'Content-Type': 'application/json',
            ...this.getCorsHeaders()
          }
        });
      }

      // Get metadata from KV store
      const metadata = await this.metadataStore.getVideoMetadata(videoId);

      if (!metadata) {
        return new Response(JSON.stringify({
          error: 'Video not found',
          videoId
        }), {
          status: 404,
          headers: {
            'Content-Type': 'application/json',
            ...this.getCorsHeaders()
          }
        });
      }

      // Generate signed URLs for each rendition and poster
      const [url480p, url720p, posterUrl] = await Promise.all([
        this.urlSigner.getSignedUrl(`videos/${videoId}/480p.mp4`, { expiresIn: 300 }),
        this.urlSigner.getSignedUrl(`videos/${videoId}/720p.mp4`, { expiresIn: 300 }),
        this.urlSigner.getSignedUrl(`videos/${videoId}/poster.jpg`, { expiresIn: 300 })
      ]);

      // Build response
      const response: VideoMetadataResponse = {
        videoId: metadata.videoId,
        duration: metadata.duration,
        renditions: {
          '480p': url480p,
          '720p': url720p
        },
        poster: posterUrl
      };

      // Return with caching headers
      return new Response(JSON.stringify(response), {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
          'Cache-Control': 'public, max-age=60, s-maxage=300', // 1 min browser, 5 min CDN
          'CDN-Cache-Control': 'max-age=300', // Cloudflare CDN cache
          ...this.getCorsHeaders()
        }
      });

    } catch (error) {
      console.error('Error handling video metadata request:', error);
      
      return new Response(JSON.stringify({
        error: 'Internal server error'
      }), {
        status: 500,
        headers: {
          'Content-Type': 'application/json',
          ...this.getCorsHeaders()
        }
      });
    } finally {
      // Clear request cache
      MetadataStore.clearRequestCache();
    }
  }

  /**
   * Handle OPTIONS requests for CORS preflight
   */
  handleOptions(): Response {
    return new Response(null, {
      status: 204,
      headers: this.getCorsHeaders()
    });
  }

  /**
   * Get CORS headers for responses
   */
  private getCorsHeaders(): Record<string, string> {
    return {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
      'Access-Control-Max-Age': '86400'
    };
  }
}