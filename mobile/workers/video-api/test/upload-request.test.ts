// ABOUTME: Comprehensive tests for the video upload request endpoint with NIP-98 authentication
// ABOUTME: Tests authentication, rate limiting, error handling, and Cloudflare Stream integration

import { describe, it, expect, beforeEach, vi } from 'vitest';
import { generateSecretKey, getPublicKey, finalizeEvent, getEventHash } from 'nostr-tools';
import worker from '../src/index';

describe('Upload Request Endpoint', () => {
  const mockEnv = {
    VIDEO_METADATA: {
      get: async () => null,
      put: async () => {},
      list: async () => ({ keys: [], list_complete: true })
    },
    VIDEO_STATUS: {
      get: async (key: string) => {
        // Return rate limit count for testing
        if (key.startsWith('ratelimit:')) {
          return null; // No previous uploads
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
    CLOUDFLARE_API_TOKEN: 'test-token',
    STREAM_ACCOUNT_ID: 'test-account-id'
  };

  const ctx = {
    waitUntil: () => {},
    passThroughOnException: () => {}
  };

  // Helper to create a valid NIP-98 event
  function createNIP98Event(url: string, method: string = 'POST') {
    const privateKey = generateSecretKey();
    const pubkey = getPublicKey(privateKey);
    
    const event = {
      kind: 27235,
      pubkey,
      created_at: Math.floor(Date.now() / 1000),
      tags: [
        ['u', url],
        ['method', method]
      ],
      content: ''
    };

    return finalizeEvent(event, privateKey);
  }

  // Helper to create Authorization header
  function createAuthHeader(event: any): string {
    return `Nostr ${btoa(JSON.stringify(event))}`;
  }

  beforeEach(() => {
    // Reset mocks
    vi.clearAllMocks();
  });

  describe('Authentication', () => {
    it('should reject requests without Authorization header', async () => {
      const request = new Request('http://localhost/v1/media/request-upload', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ fileName: 'test.mp4', fileSize: 1024 })
      });

      const response = await worker.fetch(request, mockEnv, ctx);
      expect(response.status).toBe(401);
      
      const json = await response.json();
      expect(json.error.code).toBe('auth_failed');
      expect(json.error.message).toBe('Missing Authorization header');
    });

    it('should reject invalid Authorization scheme', async () => {
      const request = new Request('http://localhost/v1/media/request-upload', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer invalid-token'
        },
        body: JSON.stringify({ fileName: 'test.mp4', fileSize: 1024 })
      });

      const response = await worker.fetch(request, mockEnv, ctx);
      expect(response.status).toBe(401);
      
      const json = await response.json();
      expect(json.error.code).toBe('auth_failed');
    });

    it('should reject invalid NIP-98 event', async () => {
      const request = new Request('http://localhost/v1/media/request-upload', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Nostr ' + btoa(JSON.stringify({ invalid: 'event' }))
        },
        body: JSON.stringify({ fileName: 'test.mp4', fileSize: 1024 })
      });

      const response = await worker.fetch(request, mockEnv, ctx);
      expect(response.status).toBe(401);
    });

    it('should reject expired NIP-98 event', async () => {
      const url = 'http://localhost/v1/media/request-upload';
      const event = createNIP98Event(url);
      event.created_at = Math.floor(Date.now() / 1000) - 120; // 2 minutes ago

      const request = new Request(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': createAuthHeader(event)
        },
        body: JSON.stringify({ fileName: 'test.mp4', fileSize: 1024 })
      });

      const response = await worker.fetch(request, mockEnv, ctx);
      expect(response.status).toBe(401);
      
      const json = await response.json();
      expect(json.error.message).toContain('timestamp out of range');
    });

    it('should reject NIP-98 event with wrong URL', async () => {
      const event = createNIP98Event('http://wrong-url.com/upload');

      const request = new Request('http://localhost/v1/media/request-upload', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': createAuthHeader(event)
        },
        body: JSON.stringify({ fileName: 'test.mp4', fileSize: 1024 })
      });

      const response = await worker.fetch(request, mockEnv, ctx);
      expect(response.status).toBe(401);
      
      const json = await response.json();
      expect(json.error.message).toContain('URL mismatch');
    });

    it('should reject NIP-98 event with wrong method', async () => {
      const url = 'http://localhost/v1/media/request-upload';
      const event = createNIP98Event(url, 'GET'); // Wrong method

      const request = new Request(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': createAuthHeader(event)
        },
        body: JSON.stringify({ fileName: 'test.mp4', fileSize: 1024 })
      });

      const response = await worker.fetch(request, mockEnv, ctx);
      expect(response.status).toBe(401);
      
      const json = await response.json();
      expect(json.error.message).toContain('Method mismatch');
    });
  });

  describe('Request Validation', () => {
    it('should reject requests without fileName', async () => {
      const url = 'http://localhost/v1/media/request-upload';
      const event = createNIP98Event(url);

      const request = new Request(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': createAuthHeader(event)
        },
        body: JSON.stringify({ fileSize: 1024 })
      });

      const response = await worker.fetch(request, mockEnv, ctx);
      expect(response.status).toBe(400);
      
      const json = await response.json();
      expect(json.error.code).toBe('invalid_request');
      expect(json.error.message).toBe('fileName is required');
    });

    it('should reject requests without fileSize', async () => {
      const url = 'http://localhost/v1/media/request-upload';
      const event = createNIP98Event(url);

      const request = new Request(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': createAuthHeader(event)
        },
        body: JSON.stringify({ fileName: 'test.mp4' })
      });

      const response = await worker.fetch(request, mockEnv, ctx);
      expect(response.status).toBe(400);
      
      const json = await response.json();
      expect(json.error.code).toBe('invalid_request');
      expect(json.error.message).toBe('fileSize must be a positive number');
    });

    it('should reject files larger than 500MB', async () => {
      const url = 'http://localhost/v1/media/request-upload';
      const event = createNIP98Event(url);

      const request = new Request(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': createAuthHeader(event)
        },
        body: JSON.stringify({ 
          fileName: 'test.mp4', 
          fileSize: 600 * 1024 * 1024 // 600MB
        })
      });

      const response = await worker.fetch(request, mockEnv, ctx);
      expect(response.status).toBe(400);
      
      const json = await response.json();
      expect(json.error.code).toBe('file_too_large');
      expect(json.error.message).toContain('exceeds maximum of 500MB');
    });
  });

  describe('Rate Limiting', () => {
    it('should enforce 30 uploads per hour limit', async () => {
      const url = 'http://localhost/v1/media/request-upload';
      const event = createNIP98Event(url);
      const pubkey = event.pubkey;

      // Mock rate limit at maximum
      const mockEnvWithRateLimit = {
        ...mockEnv,
        VIDEO_STATUS: {
          get: async (key: string) => {
            if (key === `ratelimit:upload:${pubkey}`) {
              return '30'; // At limit
            }
            return null;
          },
          put: async () => {},
          list: async () => ({ keys: [], list_complete: true })
        }
      };

      const request = new Request(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': createAuthHeader(event)
        },
        body: JSON.stringify({ fileName: 'test.mp4', fileSize: 1024 })
      });

      const response = await worker.fetch(request, mockEnvWithRateLimit, ctx);
      expect(response.status).toBe(429);
      
      const json = await response.json();
      expect(json.error.code).toBe('rate_limit_exceeded');
      expect(json.error.message).toBe('Upload limit of 30 per hour exceeded');
      expect(json.error.retryAfter).toBeDefined();
    });
  });

  describe('Successful Upload Request', () => {
    it('should return upload URL with valid request', async () => {
      const url = 'http://localhost/v1/media/request-upload';
      const event = createNIP98Event(url);

      // Mock successful Cloudflare Stream response
      global.fetch = vi.fn().mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          success: true,
          result: {
            uid: 'test-stream-uid',
            uploadURL: 'https://upload.videodelivery.net/test-stream-uid'
          }
        })
      });

      const request = new Request(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': createAuthHeader(event)
        },
        body: JSON.stringify({ fileName: 'test.mp4', fileSize: 1024 })
      });

      const response = await worker.fetch(request, mockEnv, ctx);
      expect(response.status).toBe(200);
      
      const json = await response.json();
      expect(json.videoId).toBeDefined();
      expect(json.uploadURL).toBe('https://upload.videodelivery.net/test-stream-uid');
      expect(json.expiresAt).toBeDefined();

      // Verify fetch was called correctly
      expect(global.fetch).toHaveBeenCalledWith(
        expect.stringContaining('api.cloudflare.com'),
        expect.objectContaining({
          method: 'POST',
          headers: expect.objectContaining({
            'Authorization': 'Bearer test-token'
          })
        })
      );
    });
  });

  describe('Error Handling', () => {
    it('should handle Cloudflare Stream API errors', async () => {
      const url = 'http://localhost/v1/media/request-upload';
      const event = createNIP98Event(url);

      // Mock Cloudflare Stream error
      global.fetch = vi.fn().mockResolvedValueOnce({
        ok: false,
        status: 500,
        text: async () => 'Internal Server Error'
      });

      const request = new Request(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': createAuthHeader(event)
        },
        body: JSON.stringify({ fileName: 'test.mp4', fileSize: 1024 })
      });

      const response = await worker.fetch(request, mockEnv, ctx);
      expect(response.status).toBe(503);
      
      const json = await response.json();
      expect(json.error.code).toBe('service_unavailable');
      expect(json.error.message).toContain('Stream API');
    });

    it('should handle missing Cloudflare credentials', async () => {
      const url = 'http://localhost/v1/media/request-upload';
      const event = createNIP98Event(url);

      // Mock environment without Stream credentials
      const mockEnvNoStream = {
        ...mockEnv,
        CLOUDFLARE_API_TOKEN: undefined,
        STREAM_ACCOUNT_ID: undefined
      };

      const request = new Request(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': createAuthHeader(event)
        },
        body: JSON.stringify({ fileName: 'test.mp4', fileSize: 1024 })
      });

      const response = await worker.fetch(request, mockEnvNoStream, ctx);
      expect(response.status).toBe(503);
      
      const json = await response.json();
      expect(json.error.code).toBe('service_unavailable');
      expect(json.error.message).toBe('Video upload service is not configured');
    });
  });

  describe('CORS Headers', () => {
    it('should include CORS headers in response', async () => {
      const url = 'http://localhost/v1/media/request-upload';
      const event = createNIP98Event(url);

      const request = new Request(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': createAuthHeader(event)
        },
        body: JSON.stringify({ fileName: 'test.mp4', fileSize: 1024 })
      });

      const response = await worker.fetch(request, mockEnv, ctx);
      
      expect(response.headers.get('Access-Control-Allow-Origin')).toBe('*');
      expect(response.headers.get('Access-Control-Allow-Methods')).toBe('GET, POST, OPTIONS');
      expect(response.headers.get('Access-Control-Allow-Headers')).toBe('Content-Type, Authorization');
    });
  });
});