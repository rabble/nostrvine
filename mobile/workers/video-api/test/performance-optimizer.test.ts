import { describe, it, expect } from 'vitest';
import worker from '../src/index';

describe('Performance Optimizer', () => {
  const mockEnv = {
    VIDEO_METADATA: {
      get: async (key: string) => {
        // Simulate some delay for testing
        await new Promise(resolve => setTimeout(resolve, 10));
        
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
            uploadTimestamp: Date.now()
          };
        }
        return null;
      },
      put: async () => {},
      list: async () => ({ keys: [], list_complete: true })
    },
    VIDEO_BUCKET: {
      head: async () => ({ size: 1024 })
    },
    ENVIRONMENT: 'development',
    ENABLE_ANALYTICS: true,
    ENABLE_PERFORMANCE_MODE: true
  };

  const ctx = {
    waitUntil: () => {},
    passThroughOnException: () => {}
  };

  it('should return performance statistics', async () => {
    const request = new Request('http://localhost/api/performance');

    const response = await worker.fetch(request, mockEnv, ctx);
    expect(response.status).toBe(200);
    
    const json = await response.json();
    expect(json).toHaveProperty('status');
    expect(json).toHaveProperty('performance');
    expect(json).toHaveProperty('recommendations');
    expect(json).toHaveProperty('timestamp');
    
    // Check performance structure
    const perf = json.performance;
    expect(perf).toHaveProperty('requestCoalescing');
    expect(perf).toHaveProperty('circuitBreakers');
    expect(perf).toHaveProperty('parallelProcessing');
    expect(perf).toHaveProperty('connectionPool');
    expect(perf).toHaveProperty('memory');
  });

  it('should use optimized batch API when performance mode is enabled', async () => {
    const requestBody = {
      videoIds: [
        '0000000000000000000000000000000000000000000000000000000000000001',
        '0000000000000000000000000000000000000000000000000000000000000002',
        '0000000000000000000000000000000000000000000000000000000000000003'
      ]
    };

    const request = new Request('http://localhost/api/videos/batch?optimize=true', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(requestBody)
    });

    const response = await worker.fetch(request, mockEnv, ctx);
    expect(response.status).toBe(200);
    
    const json = await response.json();
    expect(json).toHaveProperty('videos');
    expect(json).toHaveProperty('performance'); // Optimized API includes performance metrics
    
    const perf = json.performance;
    expect(perf).toHaveProperty('parallelOperations');
    expect(perf).toHaveProperty('coalescedRequests');
    expect(perf).toHaveProperty('processingTimeMs');
    expect(typeof perf.processingTimeMs).toBe('number');
  });

  it('should use optimized API with X-Performance-Mode header', async () => {
    const request = new Request('http://localhost/api/videos/batch', {
      method: 'POST',
      headers: { 
        'Content-Type': 'application/json',
        'X-Performance-Mode': 'optimized'
      },
      body: JSON.stringify({
        videoIds: ['0000000000000000000000000000000000000000000000000000000000000001']
      })
    });

    const response = await worker.fetch(request, mockEnv, ctx);
    expect(response.status).toBe(200);
    expect(response.headers.get('X-Performance-Mode')).toBe('optimized');
    
    const json = await response.json();
    expect(json).toHaveProperty('performance');
  });

  it('should handle duplicate video IDs efficiently', async () => {
    const videoId = '0000000000000000000000000000000000000000000000000000000000000001';
    const request = new Request('http://localhost/api/videos/batch?optimize=true', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        videoIds: [videoId, videoId, videoId] // Same ID 3 times
      })
    });

    const response = await worker.fetch(request, mockEnv, ctx);
    expect(response.status).toBe(200);
    
    const json = await response.json();
    expect(json.performance.coalescedRequests).toBe(2); // 2 duplicates coalesced
    expect(Object.keys(json.videos).length).toBe(1); // Only 1 unique video
  });

  it('should provide circuit breaker information in performance stats', async () => {
    const request = new Request('http://localhost/api/performance');

    const response = await worker.fetch(request, mockEnv, ctx);
    const json = await response.json();
    
    expect(json.performance.circuitBreakers).toHaveProperty('kv');
    expect(json.performance.circuitBreakers).toHaveProperty('r2');
    
    const kvCircuit = json.performance.circuitBreakers.kv;
    expect(kvCircuit).toHaveProperty('state');
    expect(['CLOSED', 'OPEN', 'HALF_OPEN']).toContain(kvCircuit.state);
  });

  it('should include memory statistics', async () => {
    const request = new Request('http://localhost/api/performance');

    const response = await worker.fetch(request, mockEnv, ctx);
    const json = await response.json();
    
    const memory = json.performance.memory;
    expect(memory).toHaveProperty('used');
    expect(memory).toHaveProperty('limit');
    expect(memory).toHaveProperty('percentage');
    expect(memory.percentage).toBeGreaterThanOrEqual(0);
    expect(memory.percentage).toBeLessThanOrEqual(1);
  });

  it('should provide recommendations when issues detected', async () => {
    const request = new Request('http://localhost/api/performance');

    const response = await worker.fetch(request, mockEnv, ctx);
    const json = await response.json();
    
    expect(Array.isArray(json.recommendations)).toBe(true);
    // Recommendations depend on current system state
  });

  it('should fall back to standard batch API when optimize is false', async () => {
    const mockEnvNoPerf = { ...mockEnv, ENABLE_PERFORMANCE_MODE: false };
    
    const request = new Request('http://localhost/api/videos/batch', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        videoIds: ['0000000000000000000000000000000000000000000000000000000000000001']
      })
    });

    const response = await worker.fetch(request, mockEnvNoPerf, ctx);
    expect(response.status).toBe(200);
    
    const json = await response.json();
    expect(json).not.toHaveProperty('performance'); // Standard API doesn't include performance metrics
  });
});