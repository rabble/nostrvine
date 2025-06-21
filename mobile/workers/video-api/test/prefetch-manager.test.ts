import { describe, it, expect } from 'vitest';
import worker from '../src/index';

describe('Prefetch Manager', () => {
  const mockEnv = {
    VIDEO_METADATA: {
      get: async (key: string) => {
        // Mock video metadata for any video request
        if (key.startsWith('video:')) {
          const videoId = key.substring(6);
          return {
            videoId,
            duration: 6.0,
            fileSize: 2097152,
            renditions: {
              '480p': { key: `videos/${videoId}/480p.mp4`, size: 1048576 },
              '720p': { key: `videos/${videoId}/720p.mp4`, size: 2097152 }
            },
            poster: `videos/${videoId}/poster.jpg`,
            uploadTimestamp: Date.now() - Math.random() * 86400000
          };
        }
        return null;
      },
      list: async (options: any) => {
        // Mock KV list response for feed videos
        if (options.prefix === 'video:') {
          const videoKeys = [];
          for (let i = 0; i < 15; i++) {
            const id = i.toString().padStart(64, '0');
            videoKeys.push({ name: `video:${id}` });
          }
          return {
            keys: videoKeys,
            list_complete: true
          };
        }
        // Mock analytics list
        return { keys: [], list_complete: true };
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

  it('should return prefetch recommendations with default parameters', async () => {
    const request = new Request('http://localhost/api/prefetch?sessionId=test123');

    const response = await worker.fetch(request, mockEnv, ctx);
    expect(response.status).toBe(200);
    
    const json = await response.json();
    expect(json).toHaveProperty('prefetch');
    expect(json).toHaveProperty('strategy');
    expect(json).toHaveProperty('meta');
    
    // Check prefetch recommendations
    const prefetch = json.prefetch;
    expect(prefetch).toHaveProperty('videoIds');
    expect(prefetch).toHaveProperty('qualityMap');
    expect(prefetch).toHaveProperty('priorityOrder');
    expect(prefetch).toHaveProperty('estimatedSize');
    expect(prefetch).toHaveProperty('reasoning');
    
    expect(Array.isArray(prefetch.videoIds)).toBe(true);
    expect(typeof prefetch.estimatedSize).toBe('number');
  });

  it('should adapt strategy based on network conditions', async () => {
    // Test slow network
    const slowRequest = new Request('http://localhost/api/prefetch?sessionId=test123&bandwidth=0.5&connectionType=2g');

    const slowResponse = await worker.fetch(slowRequest, mockEnv, ctx);
    expect(slowResponse.status).toBe(200);
    
    const slowJson = await slowResponse.json();
    expect(slowJson.strategy.networkCondition).toBe('slow');
    expect(slowJson.prefetch.videoIds.length).toBeLessThanOrEqual(3); // Reduced prefetch for slow network

    // Test fast network
    const fastRequest = new Request('http://localhost/api/prefetch?sessionId=test123&bandwidth=15&connectionType=4g');

    const fastResponse = await worker.fetch(fastRequest, mockEnv, ctx);
    expect(fastResponse.status).toBe(200);
    
    const fastJson = await fastResponse.json();
    expect(fastJson.strategy.networkCondition).toBe('fast');
    expect(fastJson.prefetch.videoIds.length).toBeGreaterThan(4); // Increased prefetch for fast network
  });

  it('should handle POST requests with body parameters', async () => {
    const requestBody = {
      sessionId: 'test123',
      userId: 'user456',
      networkHints: {
        bandwidth: 8.0,
        latency: 50,
        connectionType: '4g'
      },
      userHints: {
        averageViewTime: 5000,
        scrollVelocity: 1.5,
        qualityPreference: '720p'
      }
    };

    const request = new Request('http://localhost/api/prefetch', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(requestBody)
    });

    const response = await worker.fetch(request, mockEnv, ctx);
    expect(response.status).toBe(200);
    
    const json = await response.json();
    expect(json.strategy.networkCondition).toBe('fast');
    expect(json.prefetch.videoIds.length).toBeGreaterThan(3);
  });

  it('should include CORS headers', async () => {
    const request = new Request('http://localhost/api/prefetch?sessionId=test123');

    const response = await worker.fetch(request, mockEnv, ctx);
    expect(response.headers.get('Access-Control-Allow-Origin')).toBe('*');
    expect(response.headers.get('Access-Control-Allow-Methods')).toContain('GET');
    expect(response.headers.get('Access-Control-Allow-Methods')).toContain('POST');
  });

  it('should handle prefetch analytics requests', async () => {
    const request = new Request('http://localhost/api/prefetch/analytics?sessionId=test123&hours=24');

    const response = await worker.fetch(request, mockEnv, ctx);
    expect(response.status).toBe(200);
    
    const json = await response.json();
    expect(json).toHaveProperty('sessionId', 'test123');
    expect(json).toHaveProperty('period');
    expect(json).toHaveProperty('analytics');
    expect(json).toHaveProperty('timestamp');
    
    expect(json.period).toHaveProperty('hours', 24);
  });

  it('should reject analytics request without sessionId', async () => {
    const request = new Request('http://localhost/api/prefetch/analytics?hours=24');

    const response = await worker.fetch(request, mockEnv, ctx);
    expect(response.status).toBe(400);
    
    const json = await response.json();
    expect(json).toHaveProperty('error', 'sessionId parameter required');
  });

  it('should provide quality recommendations based on network type', async () => {
    // Test medium network - should prefer 480p first
    const mediumRequest = new Request('http://localhost/api/prefetch?sessionId=test123&bandwidth=3.0');

    const mediumResponse = await worker.fetch(mediumRequest, mockEnv, ctx);
    const mediumJson = await mediumResponse.json();
    
    expect(mediumJson.strategy.networkCondition).toBe('medium');
    expect(mediumJson.strategy.qualityPriority).toEqual(['480p', '720p']);

    // Test fast network - should prefer 720p first
    const fastRequest = new Request('http://localhost/api/prefetch?sessionId=test123&bandwidth=12.0');

    const fastResponse = await worker.fetch(fastRequest, mockEnv, ctx);
    const fastJson = await fastResponse.json();
    
    expect(fastJson.strategy.networkCondition).toBe('fast');
    expect(fastJson.strategy.qualityPriority).toEqual(['720p', '480p']);
  });

  it('should adjust prefetch count based on scroll velocity', async () => {
    // Test fast scrolling - should increase prefetch
    const fastScrollRequest = new Request('http://localhost/api/prefetch?sessionId=test123&scrollVelocity=3.0&bandwidth=10');

    const fastScrollResponse = await worker.fetch(fastScrollRequest, mockEnv, ctx);
    const fastScrollJson = await fastScrollResponse.json();
    
    const fastScrollCount = fastScrollJson.prefetch.videoIds.length;

    // Test slow scrolling - should decrease prefetch
    const slowScrollRequest = new Request('http://localhost/api/prefetch?sessionId=test123&scrollVelocity=0.3&bandwidth=10');

    const slowScrollResponse = await worker.fetch(slowScrollRequest, mockEnv, ctx);
    const slowScrollJson = await slowScrollResponse.json();
    
    const slowScrollCount = slowScrollJson.prefetch.videoIds.length;

    expect(fastScrollCount).toBeGreaterThan(slowScrollCount);
  });
});