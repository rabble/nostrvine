// ABOUTME: Video metadata storage service using Cloudflare KV
// ABOUTME: Provides efficient video metadata management with batch operations and caching

export interface VideoRendition {
  url: string;
  size: number;
}

export interface VideoMetadata {
  videoId: string;
  duration: number;
  fileSize: number;
  renditions: {
    '480p': VideoRendition;
    '720p': VideoRendition;
  };
  poster: string;
  uploadTimestamp: number;
  originalEventId: string; // Nostr event ID
}

export interface VideoListResult {
  videos: VideoMetadata[];
  nextCursor?: string;
}

// In-memory cache for request lifecycle
const requestCache = new Map<string, VideoMetadata>();

export class MetadataStore {
  constructor(private kv: KVNamespace) {}

  /**
   * Get metadata for a single video
   */
  async getVideoMetadata(videoId: string): Promise<VideoMetadata | null> {
    // Check request cache first
    if (requestCache.has(videoId)) {
      return requestCache.get(videoId)!;
    }

    try {
      const key = `video:${videoId}`;
      const metadata = await this.kv.get<VideoMetadata>(key, 'json');
      
      if (metadata) {
        // Cache for request lifecycle
        requestCache.set(videoId, metadata);
      }
      
      return metadata;
    } catch (error) {
      console.error(`Failed to get metadata for video ${videoId}:`, error);
      return null;
    }
  }

  /**
   * Set metadata for a video
   */
  async setVideoMetadata(metadata: VideoMetadata): Promise<void> {
    try {
      const key = `video:${metadata.videoId}`;
      await this.kv.put(key, JSON.stringify(metadata), {
        expirationTtl: 60 * 60 * 24 * 30 // 30 days
      });
      
      // Update request cache
      requestCache.set(metadata.videoId, metadata);
      
      // Also maintain a list of recent videos
      await this.addToRecentVideos(metadata.videoId);
    } catch (error) {
      console.error(`Failed to set metadata for video ${metadata.videoId}:`, error);
      throw error;
    }
  }

  /**
   * Batch get metadata for multiple videos
   */
  async batchGetMetadata(videoIds: string[]): Promise<VideoMetadata[]> {
    const results: VideoMetadata[] = [];
    const uncachedIds: string[] = [];
    
    // Check request cache first
    for (const videoId of videoIds) {
      if (requestCache.has(videoId)) {
        results.push(requestCache.get(videoId)!);
      } else {
        uncachedIds.push(videoId);
      }
    }
    
    // Batch fetch uncached videos
    if (uncachedIds.length > 0) {
      const promises = uncachedIds.map(id => this.getVideoMetadata(id));
      const metadataResults = await Promise.all(promises);
      
      for (const metadata of metadataResults) {
        if (metadata) {
          results.push(metadata);
        }
      }
    }
    
    return results;
  }

  /**
   * List recent videos with cursor-based pagination
   */
  async listRecentVideos(limit: number = 20, cursor?: string): Promise<VideoListResult> {
    try {
      const recentKey = 'recent_videos';
      const recentList = await this.kv.get<string[]>(recentKey, 'json') || [];
      
      // Calculate start index from cursor
      let startIndex = 0;
      if (cursor) {
        startIndex = parseInt(cursor, 10) || 0;
      }
      
      // Get the requested page
      const pageIds = recentList.slice(startIndex, startIndex + limit);
      const videos = await this.batchGetMetadata(pageIds);
      
      // Calculate next cursor
      let nextCursor: string | undefined;
      if (startIndex + limit < recentList.length) {
        nextCursor = String(startIndex + limit);
      }
      
      return {
        videos,
        nextCursor
      };
    } catch (error) {
      console.error('Failed to list recent videos:', error);
      return { videos: [] };
    }
  }

  /**
   * Add video to recent videos list
   */
  private async addToRecentVideos(videoId: string): Promise<void> {
    try {
      const recentKey = 'recent_videos';
      const recentList = await this.kv.get<string[]>(recentKey, 'json') || [];
      
      // Remove if already exists and add to front
      const filtered = recentList.filter(id => id !== videoId);
      filtered.unshift(videoId);
      
      // Keep only last 1000 videos
      const trimmed = filtered.slice(0, 1000);
      
      await this.kv.put(recentKey, JSON.stringify(trimmed));
    } catch (error) {
      console.error('Failed to update recent videos list:', error);
    }
  }

  /**
   * Clear request cache (call at end of request)
   */
  static clearRequestCache(): void {
    requestCache.clear();
  }
}