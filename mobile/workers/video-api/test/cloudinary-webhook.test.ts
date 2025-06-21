// ABOUTME: Comprehensive test suite for Cloudinary webhook processing
// ABOUTME: Tests signature verification, NIP-94 generation, and ready events

import { describe, it, expect, beforeEach, vi } from 'vitest';
import { CloudinaryWebhookHandler } from '../src/handlers/cloudinary-webhook';
import { CloudinarySignerService } from '../src/services/cloudinary-signer';
import { NIP94Generator } from '../src/services/nip94-generator';
import { Env, ExecutionContext } from '../src/types';
import { CloudinaryWebhookPayload } from '../src/types/cloudinary';

// Mock KV namespace
const mockKV = {
  put: vi.fn(),
  get: vi.fn(),
  delete: vi.fn(),
  list: vi.fn().mockResolvedValue({ keys: [] })
};

// Mock execution context
const mockCtx: ExecutionContext = {
  waitUntil: vi.fn(),
  passThroughOnException: vi.fn()
};

// Mock environment
const mockEnv: Env = {
  VIDEO_STATUS: mockKV as any,
  CLOUDINARY_CLOUD_NAME: 'test-cloud',
  CLOUDINARY_API_KEY: 'test-api-key',
  CLOUDINARY_API_SECRET: 'test-secret',
  STREAM_CUSTOMER_ID: '',
  STREAM_API_TOKEN: '',
  CLOUDFLARE_ACCOUNT_ID: '',
  CF_STREAM_BASE_URL: '',
  ENABLE_PERFORMANCE_MODE: false
};

describe('CloudinaryWebhookHandler', () => {
  let handler: CloudinaryWebhookHandler;

  beforeEach(() => {
    handler = new CloudinaryWebhookHandler(mockEnv);
    vi.clearAllMocks();
  });

  describe('handleWebhook', () => {
    it('should reject requests without signature headers', async () => {
      const request = new Request('http://localhost:8787/v1/media/webhook', {
        method: 'POST',
        body: JSON.stringify({})
      });

      const response = await handler.handleWebhook(request, mockCtx);
      
      expect(response.status).toBe(401);
      expect(await response.text()).toBe('Unauthorized');
    });

    it('should reject requests with invalid signature', async () => {
      const payload: CloudinaryWebhookPayload = {
        notification_type: 'upload',
        public_id: 'test-video-123',
        version: 1234567890,
        width: 1920,
        height: 1080,
        format: 'mp4',
        resource_type: 'video',
        created_at: '2024-01-01T00:00:00Z',
        bytes: 10485760,
        etag: 'abc123',
        secure_url: 'https://res.cloudinary.com/your-cloud-name/video/upload/test-video-123.mp4',
        signature: 'invalid-sig',
        context: 'pubkey=1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef'
      };

      const request = new Request('http://localhost:8787/v1/media/webhook', {
        method: 'POST',
        headers: {
          'X-Cld-Signature': 'invalid-signature',
          'X-Cld-Timestamp': '1234567890'
        },
        body: JSON.stringify(payload)
      });

      const response = await handler.handleWebhook(request, mockCtx);
      
      expect(response.status).toBe(401);
      expect(await response.text()).toBe('Unauthorized');
    });

    it('should process valid upload webhook', async () => {
      const payload: CloudinaryWebhookPayload = {
        notification_type: 'upload',
        public_id: 'test-video-123',
        version: 1234567890,
        width: 1920,
        height: 1080,
        format: 'mp4',
        resource_type: 'video',
        created_at: '2024-01-01T00:00:00Z',
        bytes: 10485760,
        etag: 'abc123',
        secure_url: 'https://res.cloudinary.com/your-cloud-name/video/upload/test-video-123.mp4',
        signature: 'webhook-sig',
        context: {
          custom: {
            pubkey: '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef'
          }
        },
        eager: [
          {
            width: 640,
            height: 360,
            secure_url: 'https://res.cloudinary.com/your-cloud-name/video/upload/f_mp4/test-video-123.mp4',
            format: 'mp4',
            bytes: 5242880,
            transformation: 'f_mp4,vc_h264,q_auto'
          },
          {
            width: 640,
            height: 360,
            secure_url: 'https://res.cloudinary.com/your-cloud-name/video/upload/f_webp/test-video-123.webp',
            format: 'webp',
            bytes: 2097152,
            transformation: 'f_webp,q_auto:good'
          }
        ]
      };

      // Mock signature validation to return true
      vi.spyOn(CloudinarySignerService.prototype, 'validateWebhookSignature')
        .mockResolvedValue(true);

      const body = JSON.stringify(payload);
      const request = new Request('http://localhost:8787/v1/media/webhook', {
        method: 'POST',
        headers: {
          'X-Cld-Signature': 'valid-signature',
          'X-Cld-Timestamp': '1234567890'
        },
        body
      });

      const response = await handler.handleWebhook(request, mockCtx);
      
      expect(response.status).toBe(200);
      expect(await response.text()).toBe('OK');
      
      // Verify ready event was stored
      expect(mockKV.put).toHaveBeenCalledWith(
        'ready:1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef:test-video-123',
        expect.stringContaining('test-video-123'),
        expect.objectContaining({ expirationTtl: 86400 })
      );
      
      // Verify waitUntil was called
      expect(mockCtx.waitUntil).toHaveBeenCalled();
    });

    it('should handle webhook with string context', async () => {
      const payload: CloudinaryWebhookPayload = {
        notification_type: 'upload',
        public_id: 'test-video-456',
        version: 1234567890,
        width: 1280,
        height: 720,
        format: 'mp4',
        resource_type: 'video',
        created_at: '2024-01-01T00:00:00Z',
        bytes: 8388608,
        etag: 'def456',
        secure_url: 'https://res.cloudinary.com/your-cloud-name/video/upload/test-video-456.mp4',
        signature: 'webhook-sig',
        context: 'pubkey=abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890'
      };

      vi.spyOn(CloudinarySignerService.prototype, 'validateWebhookSignature')
        .mockResolvedValue(true);

      const request = new Request('http://localhost:8787/v1/media/webhook', {
        method: 'POST',
        headers: {
          'X-Cld-Signature': 'valid-signature',
          'X-Cld-Timestamp': '1234567890'
        },
        body: JSON.stringify(payload)
      });

      const response = await handler.handleWebhook(request, mockCtx);
      
      expect(response.status).toBe(200);
      expect(mockKV.put).toHaveBeenCalledWith(
        'ready:abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890:test-video-456',
        expect.any(String),
        expect.any(Object)
      );
    });
  });
});

describe('NIP94Generator', () => {
  describe('generateTags', () => {
    it('should generate valid NIP-94 tags for video', () => {
      const payload: CloudinaryWebhookPayload = {
        notification_type: 'upload',
        public_id: 'test-video',
        version: 1234567890,
        width: 1920,
        height: 1080,
        format: 'mp4',
        resource_type: 'video',
        created_at: '2024-01-01T00:00:00Z',
        bytes: 10485760,
        etag: 'abc123',
        secure_url: 'https://res.cloudinary.com/your-cloud-name/video/upload/test-video.mp4',
        signature: 'sig',
        eager: [
          {
            width: 640,
            height: 360,
            secure_url: 'https://res.cloudinary.com/your-cloud-name/video/upload/f_webp/test-video.webp',
            format: 'webp',
            bytes: 2097152,
            transformation: 'f_webp'
          }
        ]
      };

      const tags = NIP94Generator.generateTags(payload);
      
      // Verify required tags
      expect(tags).toContainEqual(['url', 'https://res.cloudinary.com/your-cloud-name/video/upload/test-video.mp4']);
      expect(tags).toContainEqual(['m', 'video/mp4']);
      expect(tags).toContainEqual(['size', '10485760']);
      expect(tags).toContainEqual(['dim', '1920x1080']);
      expect(tags).toContainEqual(['x', 'abc123']);
      
      // Verify alternative format tags
      expect(tags).toContainEqual([
        'alt',
        'https://res.cloudinary.com/your-cloud-name/video/upload/f_webp/test-video.webp',
        'video/webp',  // Since the original resource is video, alt formats inherit the resource type
        '2097152',
        '640x360'
      ]);
      
      // Verify custom tags
      expect(tags).toContainEqual(['client', 'nostrvine']);
      expect(tags).toContainEqual(['processing', 'cloudinary']);
    });

    it('should generate thumbnail URL for video', () => {
      const payload: CloudinaryWebhookPayload = {
        notification_type: 'upload',
        public_id: 'test-video',
        version: 1234567890,
        width: 1920,
        height: 1080,
        format: 'mp4',
        resource_type: 'video',
        created_at: '2024-01-01T00:00:00Z',
        bytes: 10485760,
        etag: 'abc123',
        secure_url: 'https://res.cloudinary.com/your-cloud-name/video/upload/test-video.mp4',
        signature: 'sig'
      };

      const tags = NIP94Generator.generateTags(payload);
      
      // Should generate a thumbnail URL for video
      expect(tags).toContainEqual(['thumb', 'https://res.cloudinary.com/your-cloud-name/video/upload/test-video.jpg']);
    });

    it('should validate generated tags', () => {
      const validTags = [
        ['url', 'https://example.com/video.mp4'],
        ['m', 'video/mp4'],
        ['size', '1234567'],
        ['dim', '1920x1080']
      ];

      const validation = NIP94Generator.validateTags(validTags);
      expect(validation.valid).toBe(true);
      expect(validation.errors).toHaveLength(0);

      const invalidTags = [
        ['url'], // Missing value
        ['size', 'not-a-number'],
        ['dim', '1920:1080'] // Wrong format
      ];

      const invalidValidation = NIP94Generator.validateTags(invalidTags);
      expect(invalidValidation.valid).toBe(false);
      expect(invalidValidation.errors).toContain('Missing required "m" (MIME type) tag');
    });
  });

  describe('generateContent', () => {
    it('should generate video content text', () => {
      const payload: CloudinaryWebhookPayload = {
        notification_type: 'upload',
        public_id: 'test-video',
        version: 1234567890,
        width: 1920,
        height: 1080,
        format: 'mp4',
        resource_type: 'video',
        created_at: '2024-01-01T00:00:00Z',
        bytes: 10485760, // 10MB
        etag: 'abc123',
        secure_url: 'https://example.com/video.mp4',
        signature: 'sig'
      };

      const content = NIP94Generator.generateContent(payload);
      
      expect(content).toContain('🎬 Shared a video');
      expect(content).toContain('MP4');
      expect(content).toContain('10.0MB');
      expect(content).toContain('1920x1080');
      expect(content).toContain('#nostrvine');
    });

    it('should use custom text if provided', () => {
      const payload: CloudinaryWebhookPayload = {
        notification_type: 'upload',
        public_id: 'test-video',
        version: 1234567890,
        width: 1920,
        height: 1080,
        format: 'mp4',
        resource_type: 'video',
        created_at: '2024-01-01T00:00:00Z',
        bytes: 10485760,
        etag: 'abc123',
        secure_url: 'https://example.com/video.mp4',
        signature: 'sig'
      };

      const customText = 'Check out my awesome video!';
      const content = NIP94Generator.generateContent(payload, customText);
      
      expect(content).toBe(customText);
    });
  });
});