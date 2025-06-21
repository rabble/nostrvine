// ABOUTME: Optimized Batch Video API with performance enhancements
// ABOUTME: Uses parallel processing, request coalescing, and circuit breakers for maximum performance

import { Env, ExecutionContext } from './types';
import { VideoAPI } from './video-api';
import { VideoAnalyticsService } from './video-analytics-service';
import { PerformanceOptimizer, ParallelProcessor, Task } from './performance-optimizer';

interface BatchRequest {
  videoIds: string[];
  quality?: 'auto' | '480p' | '720p';
}

interface VideoResult {
  videoId: string;
  duration?: number;
  renditions?: {
    '480p': string;
    '720p': string;
  };
  poster?: string;
  available: boolean;
  reason?: string;
}

interface BatchResponse {
  videos: Record<string, VideoResult>;
  found: number;
  missing: number;
  performance?: {
    parallelOperations: number;
    coalescedRequests: number;
    processingTimeMs: number;
  };
}

export class OptimizedBatchVideoAPI {
  private env: Env;
  private videoAPI: VideoAPI;
  private analytics: VideoAnalyticsService;
  private performanceOptimizer: PerformanceOptimizer;
  private parallelProcessor: ParallelProcessor;
  private readonly MAX_BATCH_SIZE = 50;
  private readonly PARALLEL_CONCURRENCY = 10; // Process 10 videos concurrently

  constructor(env: Env) {
    this.env = env;
    this.videoAPI = new VideoAPI(env);
    this.analytics = new VideoAnalyticsService(env);
    this.performanceOptimizer = new PerformanceOptimizer(env);
    this.parallelProcessor = new ParallelProcessor(this.PARALLEL_CONCURRENCY);
  }

  async handleBatchRequest(request: Request, ctx: ExecutionContext): Promise<Response> {
    const startTime = Date.now();
    const perfStats = {
      coalescedRequests: 0,
      parallelOperations: 0
    };
    
    try {
      // Parse request body
      const body = await this.parseRequestBody(request);
      
      if (!body) {
        return new Response(
          JSON.stringify({ error: 'Invalid request body' }),
          { 
            status: 400,
            headers: { 'Content-Type': 'application/json' }
          }
        );
      }

      // Validate batch size
      if (body.videoIds.length === 0) {
        return new Response(
          JSON.stringify({ error: 'No video IDs provided' }),
          { 
            status: 400,
            headers: { 'Content-Type': 'application/json' }
          }
        );
      }

      if (body.videoIds.length > this.MAX_BATCH_SIZE) {
        return new Response(
          JSON.stringify({ 
            error: `Batch size exceeds maximum of ${this.MAX_BATCH_SIZE} videos` 
          }),
          { 
            status: 400,
            headers: { 'Content-Type': 'application/json' }
          }
        );
      }

      // Remove duplicates and track for coalescing
      const uniqueVideoIds = [...new Set(body.videoIds)];
      perfStats.coalescedRequests = body.videoIds.length - uniqueVideoIds.length;

      // Process videos with optimized parallel processing
      const results = await this.processVideoBatchOptimized(uniqueVideoIds, body.quality);
      perfStats.parallelOperations = uniqueVideoIds.length;

      // Build response
      const response = this.buildBatchResponse(results);

      // Add performance metrics to response
      const enrichedResponse = {
        ...response,
        performance: {
          parallelOperations: perfStats.parallelOperations,
          coalescedRequests: perfStats.coalescedRequests,
          processingTimeMs: Date.now() - startTime
        }
      };

      // Track batch request analytics
      if (this.env.ENABLE_ANALYTICS !== false) {
        this.analytics.trackBatchVideoRequest(ctx, {
          requestedCount: uniqueVideoIds.length,
          foundCount: response.found,
          missingCount: response.missing,
          quality: body.quality,
          responseTime: Date.now() - startTime,
          timestamp: Date.now()
        });
      }

      return new Response(JSON.stringify(enrichedResponse), {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
          'Cache-Control': 'public, max-age=180', // Cache for 3 minutes
          'X-Performance-Mode': 'optimized'
        }
      });

    } catch (error) {
      console.error('Error handling batch request:', error);
      
      // Track error analytics
      if (this.env.ENABLE_ANALYTICS !== false) {
        this.analytics.trackAPIError(ctx, {
          endpoint: 'batch_video_optimized',
          error: error instanceof Error ? error.message : 'Unknown error',
          statusCode: 500,
          timestamp: Date.now()
        });
      }
      
      return new Response(
        JSON.stringify({ error: 'Internal server error' }),
        { 
          status: 500,
          headers: { 'Content-Type': 'application/json' }
        }
      );
    }
  }

  private async parseRequestBody(request: Request): Promise<BatchRequest | null> {
    try {
      const contentType = request.headers.get('content-type');
      if (!contentType?.includes('application/json')) {
        return null;
      }

      const body = await request.json() as BatchRequest;
      
      // Validate structure
      if (!Array.isArray(body.videoIds)) {
        return null;
      }

      // Validate each video ID
      for (const videoId of body.videoIds) {
        if (typeof videoId !== 'string' || !this.isValidVideoId(videoId)) {
          return null;
        }
      }

      return body;
    } catch {
      return null;
    }
  }

  private async processVideoBatchOptimized(
    videoIds: string[], 
    quality?: 'auto' | '480p' | '720p'
  ): Promise<VideoResult[]> {
    // Create tasks for parallel metadata fetching with request coalescing
    const metadataTasks: Task<any>[] = videoIds.map(videoId => ({
      id: videoId,
      execute: () => this.performanceOptimizer.getFromKV(`video:${videoId}`),
      priority: 1 // All metadata fetches have same priority
    }));

    // Fetch all metadata in parallel with optimized performance
    const metadataResults = await this.parallelProcessor.processParallel(metadataTasks);

    // Create tasks for parallel URL generation
    const urlTasks: Task<VideoResult>[] = metadataResults.map((metadata, index) => ({
      id: videoIds[index],
      execute: async () => {
        const videoId = videoIds[index];
        
        if (!metadata) {
          return {
            videoId,
            available: false,
            reason: 'not_found'
          };
        }

        try {
          // Generate signed URLs
          const signedUrls = await this.generateSignedUrlsOptimized(metadata, quality);
          
          return {
            videoId,
            duration: metadata.duration,
            renditions: signedUrls.renditions,
            poster: signedUrls.poster,
            available: true
          };
        } catch (error) {
          console.error(`Error processing video ${videoId}:`, error);
          return {
            videoId,
            available: false,
            reason: 'processing_error'
          };
        }
      },
      priority: metadata ? 2 : 0 // Prioritize videos with metadata
    }));

    // Process URL generation in parallel
    return this.parallelProcessor.processParallel(urlTasks);
  }

  private async generateSignedUrlsOptimized(
    metadata: any, 
    quality?: 'auto' | '480p' | '720p'
  ): Promise<{
    renditions: { '480p': string; '720p': string };
    poster: string;
  }> {
    const baseUrl = this.getR2BaseUrl();
    const expiryTime = new Date(Date.now() + 5 * 60 * 1000);

    // Generate URLs in parallel
    const urlPromises = [];
    
    // Always generate poster URL
    urlPromises.push(
      this.createSignedUrl(
        `${baseUrl}/videos/${metadata.videoId}/poster.jpg`,
        expiryTime
      )
    );

    // Generate video URLs based on quality preference
    if (!quality || quality === 'auto' || quality === '480p') {
      urlPromises.push(
        this.createSignedUrl(
          `${baseUrl}/videos/${metadata.videoId}/480p.mp4`,
          expiryTime
        )
      );
    }
    
    if (!quality || quality === 'auto' || quality === '720p') {
      urlPromises.push(
        this.createSignedUrl(
          `${baseUrl}/videos/${metadata.videoId}/720p.mp4`,
          expiryTime
        )
      );
    }

    const [posterUrl, ...videoUrls] = await Promise.all(urlPromises);
    
    // Build URLs object
    const urls = {
      renditions: {
        '480p': '',
        '720p': ''
      },
      poster: posterUrl
    };

    // Assign video URLs based on what was generated
    let urlIndex = 0;
    if (!quality || quality === 'auto' || quality === '480p') {
      urls.renditions['480p'] = videoUrls[urlIndex++];
    }
    if (!quality || quality === 'auto' || quality === '720p') {
      urls.renditions['720p'] = videoUrls[urlIndex];
    }

    return urls;
  }

  private buildBatchResponse(results: VideoResult[]): BatchResponse {
    const videos: Record<string, VideoResult> = {};
    let found = 0;
    let missing = 0;

    for (const result of results) {
      videos[result.videoId] = result;
      if (result.available) {
        found++;
      } else {
        missing++;
      }
    }

    return {
      videos,
      found,
      missing
    };
  }

  private isValidVideoId(videoId: string): boolean {
    // Video IDs should be SHA256 hashes (64 hex characters)
    return /^[a-f0-9]{64}$/i.test(videoId);
  }

  private getR2BaseUrl(): string {
    switch (this.env.ENVIRONMENT) {
      case 'production':
        return 'https://videos.nostrvine.com';
      case 'staging':
        return 'https://staging-videos.nostrvine.com';
      default:
        return 'https://dev-videos.nostrvine.com';
    }
  }

  private async createSignedUrl(objectPath: string, expiryTime: Date): Promise<string> {
    const timestamp = expiryTime.getTime();
    const signature = await this.generateSignature(objectPath, timestamp);
    return `${objectPath}?expires=${timestamp}&signature=${signature}`;
  }

  private async generateSignature(path: string, timestamp: number): Promise<string> {
    const encoder = new TextEncoder();
    const data = encoder.encode(`${path}:${timestamp}:${this.env.ENVIRONMENT}`);
    const hashBuffer = await crypto.subtle.digest('SHA-256', data);
    const hashArray = Array.from(new Uint8Array(hashBuffer));
    return hashArray.map(b => b.toString(16).padStart(2, '0')).join('').substring(0, 16);
  }

  /**
   * Get current performance statistics
   */
  getPerformanceStats() {
    return this.performanceOptimizer.getPerformanceStats();
  }
}