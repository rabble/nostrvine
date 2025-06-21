// ABOUTME: Tests for Cloudinary signed upload integration
// ABOUTME: Validates signature generation, NIP-98 auth, and security

import { describe, it, expect, beforeEach, vi } from 'vitest';
import { generateSecretKey, getPublicKey, finalizeEvent } from 'nostr-tools';
import { CloudinarySignerService } from '../src/services/cloudinary-signer';
import worker from '../src/index';

describe('Cloudinary Upload Integration', () => {
  const mockEnv = {
    VIDEO_METADATA: {
      get: async () => null,
      put: async () => {},
      list: async () => ({ keys: [], list_complete: true })
    },
    VIDEO_STATUS: {
      get: async (key: string) => {
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
    CLOUDINARY_CLOUD_NAME: 'test-cloud',
    CLOUDINARY_API_KEY: 'test-api-key',
    CLOUDINARY_API_SECRET: 'test-api-secret'
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

  describe('Cloudinary Signer Service', () => {
    let signerService: CloudinarySignerService;

    beforeEach(() => {
      signerService = new CloudinarySignerService({
        cloud_name: 'test-cloud',
        api_key: 'test-api-key',
        api_secret: 'test-api-secret'
      });
    });

    it('should validate configuration', () => {
      const validation = signerService.validateConfig();
      expect(validation.valid).toBe(true);
      expect(validation.errors).toHaveLength(0);
    });

    it('should fail validation with missing config', () => {
      const invalidSigner = new CloudinarySignerService({
        cloud_name: '',
        api_key: 'test-api-key',
        api_secret: ''
      });

      const validation = invalidSigner.validateConfig();
      expect(validation.valid).toBe(false);
      expect(validation.errors).toContain('Missing cloud_name');
      expect(validation.errors).toContain('Missing api_secret');
    });

    it('should generate signed upload parameters', async () => {
      const pubkey = 'a'.repeat(64);
      const params = await signerService.generateSignedUploadParams(pubkey);

      expect(params).toHaveProperty('signature');
      expect(params).toHaveProperty('timestamp');
      expect(params).toHaveProperty('api_key', 'test-api-key');
      expect(params).toHaveProperty('cloud_name', 'test-cloud');
      expect(params).toHaveProperty('upload_preset', 'nostrvine_video_uploads');
      expect(params.context).toBe(`pubkey=${pubkey}`);
    });

    it('should extract pubkey from context', () => {
      const pubkey = 'a'.repeat(64);
      const context = `pubkey=${pubkey}`;
      
      const extracted = CloudinarySignerService.extractPubkeyFromContext(context);
      expect(extracted).toBe(pubkey);
    });

    it('should validate webhook signatures', async () => {
      const body = '{"test": "data"}';
      const timestamp = '1234567890';
      
      // Generate a valid signature
      const stringToSign = `${body}${timestamp}test-api-secret`;
      const encoder = new TextEncoder();
      const data = encoder.encode(stringToSign);
      const hashBuffer = await crypto.subtle.digest('SHA-1', data);
      const hashArray = Array.from(new Uint8Array(hashBuffer));
      const validSignature = hashArray.map(b => b.toString(16).padStart(2, '0')).join('');

      const isValid = await signerService.validateWebhookSignature(body, validSignature, timestamp);
      expect(isValid).toBe(true);

      // Test invalid signature
      const isInvalid = await signerService.validateWebhookSignature(body, 'invalid-signature', timestamp);
      expect(isInvalid).toBe(false);
    });
  });

  describe('Cloudinary Upload Endpoint', () => {
    it('should reject requests without authorization', async () => {
      const request = new Request('http://localhost/v1/media/cloudinary/request-upload', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ file_type: 'video/mp4', byte_size: 1024 })
      });

      const response = await worker.fetch(request, mockEnv, ctx);
      expect(response.status).toBe(401);
      
      const json = await response.json();
      expect(json.error.code).toBe('auth_failed');
      expect(json.error.message).toBe('Missing Authorization header');
    });

    it('should validate file type', async () => {
      const url = 'http://localhost/v1/media/cloudinary/request-upload';
      const event = createNIP98Event(url);

      const request = new Request(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': createAuthHeader(event)
        },
        body: JSON.stringify({ file_type: 'application/exe', byte_size: 1024 })
      });

      const response = await worker.fetch(request, mockEnv, ctx);
      expect(response.status).toBe(400);
      
      const json = await response.json();
      expect(json.error.code).toBe('invalid_request');
      expect(json.error.message).toContain('Unsupported file type');
    });

    it('should enforce file size limits', async () => {
      const url = 'http://localhost/v1/media/cloudinary/request-upload';
      const event = createNIP98Event(url);

      const request = new Request(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': createAuthHeader(event)
        },
        body: JSON.stringify({ 
          file_type: 'video/mp4', 
          byte_size: 600 * 1024 * 1024 // 600MB
        })
      });

      const response = await worker.fetch(request, mockEnv, ctx);
      expect(response.status).toBe(400);
      
      const json = await response.json();
      expect(json.error.code).toBe('invalid_request');
      expect(json.error.message).toContain('exceeds maximum of 500MB');
    });

    it('should return Cloudinary upload parameters for valid request', async () => {
      const url = 'http://localhost/v1/media/cloudinary/request-upload';
      const event = createNIP98Event(url);

      const request = new Request(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': createAuthHeader(event)
        },
        body: JSON.stringify({ file_type: 'video/mp4', byte_size: 1024 * 1024 })
      });

      const response = await worker.fetch(request, mockEnv, ctx);
      expect(response.status).toBe(200);
      
      const json = await response.json();
      expect(json).toHaveProperty('videoId');
      expect(json).toHaveProperty('uploadURL');
      expect(json.uploadURL).toContain('api.cloudinary.com');
      expect(json).toHaveProperty('uploadParams');
      expect(json.uploadParams).toHaveProperty('api_key');
      expect(json.uploadParams).toHaveProperty('timestamp');
      expect(json.uploadParams).toHaveProperty('signature');
      expect(json.uploadParams).toHaveProperty('upload_preset');
      expect(json.uploadParams).toHaveProperty('context');
      expect(json.uploadParams.context).toContain(`pubkey=${event.pubkey}`);
      expect(json).toHaveProperty('expiresAt');
    });

    it('should handle missing Cloudinary credentials', async () => {
      const url = 'http://localhost/v1/media/cloudinary/request-upload';
      const event = createNIP98Event(url);

      // Mock environment without Cloudinary credentials
      const mockEnvNoCloudinary = {
        ...mockEnv,
        CLOUDINARY_API_SECRET: undefined
      };

      const request = new Request(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': createAuthHeader(event)
        },
        body: JSON.stringify({ file_type: 'video/mp4', byte_size: 1024 })
      });

      const response = await worker.fetch(request, mockEnvNoCloudinary, ctx);
      expect(response.status).toBe(503);
      
      const json = await response.json();
      expect(json.error.code).toBe('service_unavailable');
      expect(json.error.message).toBe('Upload service is not configured');
    });

    it('should enforce rate limiting', async () => {
      const url = 'http://localhost/v1/media/cloudinary/request-upload';
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
        body: JSON.stringify({ file_type: 'video/mp4', byte_size: 1024 })
      });

      const response = await worker.fetch(request, mockEnvWithRateLimit, ctx);
      expect(response.status).toBe(429);
      
      const json = await response.json();
      expect(json.error.code).toBe('rate_limit_exceeded');
      expect(json.error.message).toBe('Upload limit of 30 per hour exceeded');
      expect(json.error.retryAfter).toBeDefined();
    });

    it('should support different file types', async () => {
      const url = 'http://localhost/v1/media/cloudinary/request-upload';
      const event = createNIP98Event(url);

      const fileTypes = [
        'video/mp4',
        'video/mov',
        'video/webm',
        'image/jpeg',
        'image/png',
        'image/gif'
      ];

      for (const fileType of fileTypes) {
        const request = new Request(url, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': createAuthHeader(event)
          },
          body: JSON.stringify({ file_type: fileType, byte_size: 1024 })
        });

        const response = await worker.fetch(request, mockEnv, ctx);
        expect(response.status).toBe(200);
        
        const json = await response.json();
        expect(json.uploadURL).toContain(fileType.startsWith('video/') ? '/video/upload' : '/upload');
      }
    });

    it('should include CORS headers', async () => {
      const url = 'http://localhost/v1/media/cloudinary/request-upload';
      const event = createNIP98Event(url);

      const request = new Request(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': createAuthHeader(event),
          'Origin': 'https://nostrvine.com'
        },
        body: JSON.stringify({ file_type: 'video/mp4', byte_size: 1024 })
      });

      const response = await worker.fetch(request, mockEnv, ctx);
      
      expect(response.headers.get('Access-Control-Allow-Origin')).toBe('*');
      expect(response.headers.get('Access-Control-Allow-Methods')).toBe('GET, POST, OPTIONS');
      expect(response.headers.get('Access-Control-Allow-Headers')).toBe('Content-Type, Authorization');
    });
  });
});