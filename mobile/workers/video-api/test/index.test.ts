import { describe, it, expect } from 'vitest';
import worker from '../src/index';

describe('Video API Worker', () => {
  it('should return 404 for non-existent video', async () => {
    const request = new Request('http://localhost/api/video/0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef');
    const env = {
      VIDEO_METADATA: {
        get: async () => null,
        put: async () => {},
        list: async () => ({ keys: [], list_complete: true })
      },
      VIDEO_BUCKET: {
        head: async () => {}
      },
      ENVIRONMENT: 'development',
      ENABLE_ANALYTICS: true
    };
    const ctx = {
      waitUntil: () => {},
      passThroughOnException: () => {}
    };

    const response = await worker.fetch(request, env, ctx);
    expect(response.status).toBe(404);
    
    const json = await response.json();
    expect(json).toHaveProperty('error', 'Video not found');
  });

  it('should return 404 for invalid video ID format', async () => {
    const request = new Request('http://localhost/api/video/invalid-id');
    const env = {
      VIDEO_METADATA: {
        get: async () => null,
        put: async () => {},
        list: async () => ({ keys: [], list_complete: true })
      },
      VIDEO_BUCKET: {
        head: async () => {}
      },
      ENVIRONMENT: 'development',
      ENABLE_ANALYTICS: true
    };
    const ctx = {
      waitUntil: () => {},
      passThroughOnException: () => {}
    };

    const response = await worker.fetch(request, env, ctx);
    expect(response.status).toBe(404);
    
    const json = await response.json();
    expect(json).toHaveProperty('error', 'Not found');
  });

  it('should handle CORS preflight requests', async () => {
    const request = new Request('http://localhost/api/video/test', {
      method: 'OPTIONS'
    });
    const env = {
      VIDEO_METADATA: {
        get: async () => null,
        put: async () => {},
        list: async () => ({ keys: [], list_complete: true })
      },
      VIDEO_BUCKET: {
        head: async () => {}
      },
      ENVIRONMENT: 'development',
      ENABLE_ANALYTICS: true
    };
    const ctx = {
      waitUntil: () => {},
      passThroughOnException: () => {}
    };

    const response = await worker.fetch(request, env, ctx);
    expect(response.status).toBe(200);
    expect(response.headers.get('Access-Control-Allow-Origin')).toBe('*');
    expect(response.headers.get('Access-Control-Allow-Methods')).toContain('GET');
  });

  it('should return health check', async () => {
    const request = new Request('http://localhost/health');
    const env = {
      VIDEO_METADATA: {
        get: async () => null,
        put: async () => {},
        list: async () => ({ keys: [], list_complete: true })
      },
      VIDEO_BUCKET: {
        head: async () => {}
      },
      ENVIRONMENT: 'development',
      ENABLE_ANALYTICS: true
    };
    const ctx = {
      waitUntil: () => {},
      passThroughOnException: () => {}
    };

    const response = await worker.fetch(request, env, ctx);
    expect(response.status).toBe(200);
    
    const json = await response.json();
    expect(['healthy', 'degraded']).toContain(json.status);
    expect(json).toHaveProperty('timestamp');
    expect(json).toHaveProperty('environment', 'development');
  });
});