import { describe, it, expect } from 'vitest';
import worker from '../src/index';

describe('Batch Video API', () => {
  const mockEnv = {
    VIDEO_METADATA: {
      get: async (key: string) => {
        // Mock some test videos
        if (key === 'video:1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef') {
          return {
            videoId: '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
            duration: 6.0,
            fileSize: 2097152
          };
        }
        if (key === 'video:abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890') {
          return {
            videoId: 'abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890',
            duration: 5.5,
            fileSize: 1572864
          };
        }
        return null;
      },
      put: async () => {}
    },
    VIDEO_BUCKET: {},
    ENVIRONMENT: 'development',
    ENABLE_ANALYTICS: true
  };

  const ctx = {
    waitUntil: () => {},
    passThroughOnException: () => {}
  };

  it('should handle batch request with multiple videos', async () => {
    const request = new Request('http://localhost/api/videos/batch', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        videoIds: [
          '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
          'abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890',
          '0000000000000000000000000000000000000000000000000000000000000000'
        ]
      })
    });

    const response = await worker.fetch(request, mockEnv, ctx);
    expect(response.status).toBe(200);
    
    const json = await response.json();
    expect(json).toHaveProperty('videos');
    expect(json).toHaveProperty('found', 2);
    expect(json).toHaveProperty('missing', 1);
    
    // Check found video
    const video1 = json.videos['1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef'];
    expect(video1).toHaveProperty('available', true);
    expect(video1).toHaveProperty('duration', 6.0);
    expect(video1).toHaveProperty('renditions');
    
    // Check missing video
    const video3 = json.videos['0000000000000000000000000000000000000000000000000000000000000000'];
    expect(video3).toHaveProperty('available', false);
    expect(video3).toHaveProperty('reason', 'not_found');
  });

  it('should reject empty video ID array', async () => {
    const request = new Request('http://localhost/api/videos/batch', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ videoIds: [] })
    });

    const response = await worker.fetch(request, mockEnv, ctx);
    expect(response.status).toBe(400);
    
    const json = await response.json();
    expect(json).toHaveProperty('error', 'No video IDs provided');
  });

  it('should reject batch size over 50', async () => {
    const videoIds = Array(51).fill('').map((_, i) => 
      i.toString().padStart(64, '0')
    );

    const request = new Request('http://localhost/api/videos/batch', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ videoIds })
    });

    const response = await worker.fetch(request, mockEnv, ctx);
    expect(response.status).toBe(400);
    
    const json = await response.json();
    expect(json.error).toContain('Batch size exceeds maximum');
  });

  it('should handle invalid request body', async () => {
    const request = new Request('http://localhost/api/videos/batch', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: 'invalid json'
    });

    const response = await worker.fetch(request, mockEnv, ctx);
    expect(response.status).toBe(400);
  });

  it('should handle request with quality parameter', async () => {
    const request = new Request('http://localhost/api/videos/batch', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        videoIds: ['1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef'],
        quality: '480p'
      })
    });

    const response = await worker.fetch(request, mockEnv, ctx);
    expect(response.status).toBe(200);
  });

  it('should include CORS headers', async () => {
    const request = new Request('http://localhost/api/videos/batch', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        videoIds: ['1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef']
      })
    });

    const response = await worker.fetch(request, mockEnv, ctx);
    expect(response.headers.get('Access-Control-Allow-Origin')).toBe('*');
    expect(response.headers.get('Access-Control-Allow-Methods')).toContain('POST');
  });
});