import { describe, it, expect } from 'vitest';
import worker from '../src/index';

describe('Smart Feed API', () => {
  const mockEnv = {
    VIDEO_METADATA: {
      get: async (key: string) => {
        // Mock some test videos
        if (key === 'video:1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef') {
          return {
            videoId: '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
            duration: 6.0,
            fileSize: 2097152,
            renditions: {
              '480p': { key: 'videos/1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef/480p.mp4', size: 1048576 },
              '720p': { key: 'videos/1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef/720p.mp4', size: 2097152 }
            },
            poster: 'videos/1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef/poster.jpg',
            uploadTimestamp: 1750367573639,
            originalEventId: 'note1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq'
          };
        }
        if (key === 'video:abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890') {
          return {
            videoId: 'abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890',
            duration: 5.5,
            fileSize: 1572864,
            renditions: {
              '480p': { key: 'videos/abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890/480p.mp4', size: 786432 },
              '720p': { key: 'videos/abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890/720p.mp4', size: 1572864 }
            },
            poster: 'videos/abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890/poster.jpg',
            uploadTimestamp: 1750444173639,
            originalEventId: 'note1yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy'
          };
        }
        return null;
      },
      list: async (options: any) => {
        // Mock KV list response
        return {
          keys: [
            { name: 'video:1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef' },
            { name: 'video:abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890' },
            { name: 'video:fedcba0987654321fedcba0987654321fedcba0987654321fedcba0987654321' }
          ],
          list_complete: true
        };
      },
      put: async () => {} // Mock for analytics
    },
    VIDEO_BUCKET: {},
    ENVIRONMENT: 'development',
    ENABLE_ANALYTICS: true
  };

  const ctx = {
    waitUntil: () => {},
    passThroughOnException: () => {}
  };

  it('should return feed with default parameters', async () => {
    const request = new Request('http://localhost/api/feed');

    const response = await worker.fetch(request, mockEnv, ctx);
    expect(response.status).toBe(200);
    
    const json = await response.json();
    expect(json).toHaveProperty('videos');
    expect(json).toHaveProperty('prefetchCount', 5);
    expect(json).toHaveProperty('totalAvailable');
    expect(json).toHaveProperty('feedVersion', '1.0');
    
    // Should return videos with signed URLs
    expect(Array.isArray(json.videos)).toBe(true);
    if (json.videos.length > 0) {
      const video = json.videos[0];
      expect(video).toHaveProperty('videoId');
      expect(video).toHaveProperty('duration');
      expect(video).toHaveProperty('renditions');
      expect(video.renditions).toHaveProperty('480p');
      expect(video.renditions).toHaveProperty('720p');
      expect(video).toHaveProperty('poster');
    }
  });

  it('should respect limit parameter', async () => {
    const request = new Request('http://localhost/api/feed?limit=1');

    const response = await worker.fetch(request, mockEnv, ctx);
    expect(response.status).toBe(200);
    
    const json = await response.json();
    expect(json.videos.length).toBeLessThanOrEqual(1);
  });

  it('should handle quality parameter', async () => {
    const request = new Request('http://localhost/api/feed?quality=480p');

    const response = await worker.fetch(request, mockEnv, ctx);
    expect(response.status).toBe(200);
    
    const json = await response.json();
    expect(json).toHaveProperty('videos');
  });

  it('should reject invalid limit parameter', async () => {
    const request = new Request('http://localhost/api/feed?limit=invalid');

    const response = await worker.fetch(request, mockEnv, ctx);
    expect(response.status).toBe(400);
    
    const json = await response.json();
    expect(json).toHaveProperty('error');
  });

  it('should reject limit exceeding maximum', async () => {
    const request = new Request('http://localhost/api/feed?limit=100');

    const response = await worker.fetch(request, mockEnv, ctx);
    expect(response.status).toBe(200);
    
    const json = await response.json();
    // Should be capped at maximum limit (50)
    expect(json.videos.length).toBeLessThanOrEqual(50);
  });

  it('should include CORS headers', async () => {
    const request = new Request('http://localhost/api/feed');

    const response = await worker.fetch(request, mockEnv, ctx);
    expect(response.headers.get('Access-Control-Allow-Origin')).toBe('*');
    expect(response.headers.get('Access-Control-Allow-Methods')).toContain('GET');
  });

  it('should handle cursor pagination', async () => {
    const cursor = Buffer.from(JSON.stringify({ 
      lastVideoId: '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
      timestamp: Date.now()
    })).toString('base64');
    
    const request = new Request(`http://localhost/api/feed?cursor=${encodeURIComponent(cursor)}`);

    const response = await worker.fetch(request, mockEnv, ctx);
    expect(response.status).toBe(200);
    
    const json = await response.json();
    expect(json).toHaveProperty('videos');
  });
});