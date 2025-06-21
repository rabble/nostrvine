// ABOUTME: Batch video lookup API for efficient bulk metadata retrieval
// ABOUTME: Supports up to 50 videos per request with partial results for missing items

import { MetadataStore, VideoMetadata } from './metadata-store';
import { R2UrlSigner } from './r2-url-signer';

export interface BatchVideoRequest {
  videoIds: string[];
  quality?: 'auto' | '480p' | '720p';
}

export interface VideoDetails {
  videoId: string;
  duration?: number;
  renditions?: {
    '480p'?: string;
    '720p'?: string;
  };
  poster?: string;
  available: boolean;
  reason?: string;
}

export interface BatchVideoResponse {
  videos: Record<string, VideoDetails>;
  found: number;
  missing: number;
}

export class BatchVideoApi {
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
   * Handle POST /api/videos/batch
   */
  async handleBatchVideoLookup(request: Request): Promise<Response> {
    try {
      // Parse request body
      let body: BatchVideoRequest;
      try {
        body = await request.json();
      } catch (error) {
        return new Response(JSON.stringify({
          error: 'Invalid request body'
        }), {
          status: 400,
          headers: {
            'Content-Type': 'application/json',
            ...this.getCorsHeaders()
          }
        });
      }

      // Validate request
      if (!body.videoIds || !Array.isArray(body.videoIds)) {
        return new Response(JSON.stringify({
          error: 'videoIds must be an array'
        }), {
          status: 400,
          headers: {
            'Content-Type': 'application/json',
            ...this.getCorsHeaders()
          }
        });
      }

      if (body.videoIds.length === 0) {
        return new Response(JSON.stringify({
          error: 'videoIds array cannot be empty'
        }), {
          status: 400,
          headers: {
            'Content-Type': 'application/json',
            ...this.getCorsHeaders()
          }
        });
      }

      if (body.videoIds.length > 50) {
        return new Response(JSON.stringify({
          error: 'Maximum 50 video IDs allowed per request'
        }), {
          status: 400,
          headers: {
            'Content-Type': 'application/json',
            ...this.getCorsHeaders()
          }
        });
      }

      // Determine quality preference
      const quality = body.quality || 'auto';

      // Fetch metadata for all videos
      const metadataList = await this.metadataStore.batchGetMetadata(body.videoIds);
      
      // Create a map for quick lookup
      const metadataMap = new Map<string, VideoMetadata>();
      for (const metadata of metadataList) {
        metadataMap.set(metadata.videoId, metadata);
      }

      // Process each video ID
      const videos: Record<string, VideoDetails> = {};
      const signUrlPromises: Promise<void>[] = [];
      let found = 0;
      let missing = 0;

      for (const videoId of body.videoIds) {
        const metadata = metadataMap.get(videoId);
        
        if (!metadata) {
          videos[videoId] = {
            videoId,
            available: false,
            reason: 'not_found'
          };
          missing++;
        } else {
          found++;
          videos[videoId] = {
            videoId,
            duration: metadata.duration,
            available: true,
            renditions: {}
          };

          // Sign URLs in parallel
          signUrlPromises.push(this.signUrlsForVideo(videoId, quality, videos[videoId]));
        }
      }

      // Wait for all URL signing to complete
      await Promise.all(signUrlPromises);

      // Build response
      const response: BatchVideoResponse = {
        videos,
        found,
        missing
      };

      // Return with appropriate caching
      return new Response(JSON.stringify(response), {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
          'Cache-Control': 'public, max-age=30, s-maxage=120', // Shorter cache for batch requests
          'CDN-Cache-Control': 'max-age=120',
          ...this.getCorsHeaders()
        }
      });

    } catch (error) {
      console.error('Error handling batch video request:', error);
      
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
   * Sign URLs for a specific video based on quality preference
   */
  private async signUrlsForVideo(
    videoId: string, 
    quality: string, 
    videoDetails: VideoDetails
  ): Promise<void> {
    const promises: Promise<string>[] = [];
    const keys: string[] = [];

    // Determine which renditions to sign based on quality
    if (quality === 'auto' || quality === '480p') {
      keys.push('480p');
      promises.push(this.urlSigner.getSignedUrl(`videos/${videoId}/480p.mp4`, { expiresIn: 300 }));
    }
    
    if (quality === 'auto' || quality === '720p') {
      keys.push('720p');
      promises.push(this.urlSigner.getSignedUrl(`videos/${videoId}/720p.mp4`, { expiresIn: 300 }));
    }

    // Always include poster
    promises.push(this.urlSigner.getSignedUrl(`videos/${videoId}/poster.jpg`, { expiresIn: 300 }));

    try {
      const results = await Promise.all(promises);
      
      // Map results back to video details
      let index = 0;
      if (keys.includes('480p')) {
        videoDetails.renditions!['480p'] = results[index++];
      }
      if (keys.includes('720p')) {
        videoDetails.renditions!['720p'] = results[index++];
      }
      videoDetails.poster = results[results.length - 1]; // Poster is always last
    } catch (error) {
      console.error(`Failed to sign URLs for video ${videoId}:`, error);
      // Mark as unavailable if URL signing fails
      videoDetails.available = false;
      videoDetails.reason = 'url_signing_failed';
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
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
      'Access-Control-Max-Age': '86400'
    };
  }
}