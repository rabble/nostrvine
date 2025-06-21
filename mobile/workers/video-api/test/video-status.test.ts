// ABOUTME: Test suite for video status polling endpoint
// ABOUTME: Tests UUID validation, status responses, caching, and rate limiting

import { describe, it, expect, beforeEach, vi } from 'vitest';
import { VideoStatusHandler } from '../src/handlers/video-status';
import { Env, ExecutionContext } from '../src/types';

// Mock KV namespace
const mockKV = {
  put: vi.fn(),
  get: vi.fn(),
  delete: vi.fn(),
  list: vi.fn()
};

// Mock execution context
const mockCtx: ExecutionContext = {
  waitUntil: vi.fn(),
  passThroughOnException: vi.fn()
};

// Mock environment
const mockEnv: Env = {
  VIDEO_STATUS: mockKV as any,
  VIDEO_METADATA: mockKV as any,
  VIDEO_BUCKET: {} as any,
  ENVIRONMENT: 'development',
  CLOUDFLARE_IMAGES_ACCOUNT_HASH: 'test-account-hash'
};

describe('VideoStatusHandler', () => {
  let handler: VideoStatusHandler;

  beforeEach(() => {
    handler = new VideoStatusHandler(mockEnv);
    vi.clearAllMocks();
  });

  describe('UUID validation', () => {
    it('should reject invalid UUID format', async () => {
      const request = new Request('http://localhost:8787/v1/media/status/invalid-id');
      const response = await handler.handleStatusCheck(request, 'invalid-id', mockCtx);
      
      expect(response.status).toBe(400);
      const body = await response.json();
      expect(body.error.code).toBe('invalid_video_id');
      expect(body.error.message).toBe('Video ID must be a valid UUID');
    });

    it('should accept valid UUID v4', async () => {
      const validUuid = '550e8400-e29b-41d4-a716-446655440000';
      mockKV.get.mockResolvedValue(null); // Video not found
      
      const request = new Request(`http://localhost:8787/v1/media/status/${validUuid}`);
      const response = await handler.handleStatusCheck(request, validUuid, mockCtx);
      
      expect(response.status).toBe(404); // Not 400, so UUID was valid
    });

    it('should reject UUID v1 format', async () => {
      const uuidV1 = '550e8400-e29b-11d4-a716-446655440000'; // Note: 11d4 instead of 41d4
      const request = new Request(`http://localhost:8787/v1/media/status/${uuidV1}`);
      const response = await handler.handleStatusCheck(request, uuidV1, mockCtx);
      
      expect(response.status).toBe(400);
    });
  });

  describe('Status responses', () => {
    const validUuid = '550e8400-e29b-41d4-a716-446655440000';

    it('should return 404 for non-existent video', async () => {
      mockKV.get.mockResolvedValue(null);
      
      const request = new Request(`http://localhost:8787/v1/media/status/${validUuid}`);
      const response = await handler.handleStatusCheck(request, validUuid, mockCtx);
      
      expect(response.status).toBe(404);
      const body = await response.json();
      expect(body.error.code).toBe('video_not_found');
    });

    it('should return minimal data for pending_upload status', async () => {
      const videoData = {
        status: 'pending_upload',
        createdAt: '2024-01-01T00:00:00Z',
        updatedAt: '2024-01-01T00:00:00Z'
      };
      mockKV.get.mockResolvedValue(JSON.stringify(videoData));
      
      const request = new Request(`http://localhost:8787/v1/media/status/${validUuid}`);
      const response = await handler.handleStatusCheck(request, validUuid, mockCtx);
      
      expect(response.status).toBe(200);
      const body = await response.json();
      expect(body).toEqual({ status: 'pending_upload' });
      expect(body.hlsUrl).toBeUndefined();
    });

    it('should return minimal data for processing status', async () => {
      const videoData = {
        status: 'processing',
        createdAt: '2024-01-01T00:00:00Z',
        updatedAt: '2024-01-01T00:01:00Z'
      };
      mockKV.get.mockResolvedValue(JSON.stringify(videoData));
      
      const request = new Request(`http://localhost:8787/v1/media/status/${validUuid}`);
      const response = await handler.handleStatusCheck(request, validUuid, mockCtx);
      
      expect(response.status).toBe(200);
      const body = await response.json();
      expect(body).toEqual({ status: 'processing' });
    });

    it('should return full data for published status', async () => {
      const videoData = {
        status: 'published',
        createdAt: '2024-01-01T00:00:00Z',
        updatedAt: '2024-01-01T00:02:00Z',
        stream: {
          hlsUrl: 'https://videodelivery.net/abc123/manifest/video.m3u8',
          dashUrl: 'https://videodelivery.net/abc123/manifest/video.mpd',
          thumbnailUrl: 'https://videodelivery.net/abc123/thumbnails/thumbnail.jpg'
        }
      };
      mockKV.get.mockResolvedValue(JSON.stringify(videoData));
      
      const request = new Request(`http://localhost:8787/v1/media/status/${validUuid}`);
      const response = await handler.handleStatusCheck(request, validUuid, mockCtx);
      
      expect(response.status).toBe(200);
      const body = await response.json();
      expect(body).toEqual({
        status: 'published',
        hlsUrl: 'https://videodelivery.net/abc123/manifest/video.m3u8',
        dashUrl: 'https://videodelivery.net/abc123/manifest/video.mpd',
        thumbnailUrl: 'https://videodelivery.net/abc123/thumbnails/thumbnail.jpg',
        createdAt: '2024-01-01T00:00:00Z'
      });
    });

    it('should return user-friendly error for failed status', async () => {
      const videoData = {
        status: 'failed',
        createdAt: '2024-01-01T00:00:00Z',
        updatedAt: '2024-01-01T00:10:00Z',
        source: {
          error: 'Processing timeout after 10 minutes'
        }
      };
      mockKV.get.mockResolvedValue(JSON.stringify(videoData));
      
      const request = new Request(`http://localhost:8787/v1/media/status/${validUuid}`);
      const response = await handler.handleStatusCheck(request, validUuid, mockCtx);
      
      expect(response.status).toBe(200);
      const body = await response.json();
      expect(body).toEqual({
        status: 'failed',
        error: 'Processing timeout - please try uploading again'
      });
    });

    it('should handle quarantined status', async () => {
      const videoData = {
        status: 'quarantined',
        createdAt: '2024-01-01T00:00:00Z',
        updatedAt: '2024-01-01T00:05:00Z'
      };
      mockKV.get.mockResolvedValue(JSON.stringify(videoData));
      
      const request = new Request(`http://localhost:8787/v1/media/status/${validUuid}`);
      const response = await handler.handleStatusCheck(request, validUuid, mockCtx);
      
      expect(response.status).toBe(200);
      const body = await response.json();
      expect(body).toEqual({ status: 'quarantined' });
    });
  });

  describe('Cache headers', () => {
    const validUuid = '550e8400-e29b-41d4-a716-446655440000';

    it('should set long cache for published videos', async () => {
      const videoData = {
        status: 'published',
        stream: {
          hlsUrl: 'https://example.com/video.m3u8',
          dashUrl: 'https://example.com/video.mpd',
          thumbnailUrl: 'https://videodelivery.net/abc123/thumbnails/thumbnail.jpg'
        }
      };
      mockKV.get.mockResolvedValue(JSON.stringify(videoData));
      
      const request = new Request(`http://localhost:8787/v1/media/status/${validUuid}`);
      const response = await handler.handleStatusCheck(request, validUuid, mockCtx);
      
      expect(response.headers.get('Cache-Control')).toBe('public, max-age=3600');
      expect(response.headers.get('CDN-Cache-Control')).toBe('max-age=86400');
    });

    it('should set no cache for processing videos', async () => {
      const videoData = { status: 'processing' };
      mockKV.get.mockResolvedValue(JSON.stringify(videoData));
      
      const request = new Request(`http://localhost:8787/v1/media/status/${validUuid}`);
      const response = await handler.handleStatusCheck(request, validUuid, mockCtx);
      
      expect(response.headers.get('Cache-Control')).toBe('no-cache');
      expect(response.headers.get('CDN-Cache-Control')).toBe('no-cache');
    });

    it('should set short cache for pending uploads', async () => {
      const videoData = { status: 'pending_upload' };
      mockKV.get.mockResolvedValue(JSON.stringify(videoData));
      
      const request = new Request(`http://localhost:8787/v1/media/status/${validUuid}`);
      const response = await handler.handleStatusCheck(request, validUuid, mockCtx);
      
      expect(response.headers.get('Cache-Control')).toBe('public, max-age=30');
    });

    it('should set medium cache for terminal states', async () => {
      const videoData = { status: 'failed', source: { error: 'Some error' } };
      mockKV.get.mockResolvedValue(JSON.stringify(videoData));
      
      const request = new Request(`http://localhost:8787/v1/media/status/${validUuid}`);
      const response = await handler.handleStatusCheck(request, validUuid, mockCtx);
      
      expect(response.headers.get('Cache-Control')).toBe('public, max-age=1800');
    });
  });

  describe('Cloudflare Images URL transformation', () => {
    const validUuid = '550e8400-e29b-41d4-a716-446655440000';

    it('should return thumbnail URL as-is (transformation removed)', async () => {
      const videoData = {
        status: 'published',
        stream: {
          hlsUrl: 'https://example.com/video.m3u8',
          dashUrl: 'https://example.com/video.mpd',
          thumbnailUrl: 'https://videodelivery.net/abc123def456/thumbnails/thumbnail.jpg'
        }
      };
      mockKV.get.mockResolvedValue(JSON.stringify(videoData));
      
      const request = new Request(`http://localhost:8787/v1/media/status/${validUuid}`);
      const response = await handler.handleStatusCheck(request, validUuid, mockCtx);
      
      const body = await response.json();
      expect(body.thumbnailUrl).toBe('https://videodelivery.net/abc123def456/thumbnails/thumbnail.jpg');
    });

    it('should fallback to original URL if transformation fails', async () => {
      const videoData = {
        status: 'published',
        stream: {
          hlsUrl: 'https://example.com/video.m3u8',
          dashUrl: 'https://example.com/video.mpd',
          thumbnailUrl: 'https://example.com/thumbnail.jpg' // Not a videodelivery URL
        }
      };
      mockKV.get.mockResolvedValue(JSON.stringify(videoData));
      
      const request = new Request(`http://localhost:8787/v1/media/status/${validUuid}`);
      const response = await handler.handleStatusCheck(request, validUuid, mockCtx);
      
      const body = await response.json();
      expect(body.thumbnailUrl).toBe('https://example.com/thumbnail.jpg');
    });
  });

  describe('Rate limiting', () => {
    const validUuid = '550e8400-e29b-41d4-a716-446655440000';

    it('should allow requests under rate limit', async () => {
      mockKV.get
        .mockResolvedValueOnce('50') // Rate limit counter
        .mockResolvedValueOnce(JSON.stringify({ status: 'processing' })); // Video data
      
      const request = new Request(`http://localhost:8787/v1/media/status/${validUuid}`, {
        headers: { 'CF-Connecting-IP': '1.2.3.4' }
      });
      const response = await handler.handleStatusCheck(request, validUuid, mockCtx);
      
      expect(response.status).toBe(200);
      expect(mockKV.put).toHaveBeenCalledWith('ratelimit:status:1.2.3.4', '51', { expirationTtl: 60 });
    });

    it('should reject requests over rate limit', async () => {
      mockKV.get.mockResolvedValueOnce('181'); // Over limit
      
      const request = new Request(`http://localhost:8787/v1/media/status/${validUuid}`, {
        headers: { 'CF-Connecting-IP': '1.2.3.4' }
      });
      const response = await handler.handleStatusCheck(request, validUuid, mockCtx);
      
      expect(response.status).toBe(429);
      const body = await response.json();
      expect(body.error.code).toBe('rate_limit_exceeded');
    });

    it('should handle missing IP header', async () => {
      mockKV.get
        .mockResolvedValueOnce(null) // No rate limit data
        .mockResolvedValueOnce(JSON.stringify({ status: 'processing' }));
      
      const request = new Request(`http://localhost:8787/v1/media/status/${validUuid}`);
      const response = await handler.handleStatusCheck(request, validUuid, mockCtx);
      
      expect(response.status).toBe(200);
      expect(mockKV.put).toHaveBeenCalledWith('ratelimit:status:unknown', '1', { expirationTtl: 60 });
    });
  });

  describe('Error handling', () => {
    const validUuid = '550e8400-e29b-41d4-a716-446655440000';

    it('should handle KV errors gracefully', async () => {
      mockKV.get.mockRejectedValue(new Error('KV connection failed'));
      
      const request = new Request(`http://localhost:8787/v1/media/status/${validUuid}`);
      const response = await handler.handleStatusCheck(request, validUuid, mockCtx);
      
      expect(response.status).toBe(500);
      const body = await response.json();
      expect(body.error.code).toBe('internal_error');
    });

    it('should handle malformed JSON in KV', async () => {
      mockKV.get.mockResolvedValue('invalid json');
      
      const request = new Request(`http://localhost:8787/v1/media/status/${validUuid}`);
      const response = await handler.handleStatusCheck(request, validUuid, mockCtx);
      
      expect(response.status).toBe(500);
    });
  });

  describe('User-friendly error messages', () => {
    const validUuid = '550e8400-e29b-41d4-a716-446655440000';

    const errorCases = [
      { internal: 'timeout after 300s', expected: 'Processing timeout - please try uploading again' },
      { internal: 'moderation violation detected', expected: 'Video processing failed - please contact support' },
      { internal: 'unsupported format: avi', expected: 'Unsupported video format - please try a different file' },
      { internal: 'file size exceeds limit', expected: 'Video file too large - please reduce file size' },
      { internal: 'unknown error xyz', expected: 'Processing failed - please try again' }
    ];

    errorCases.forEach(({ internal, expected }) => {
      it(`should map "${internal}" to user-friendly message`, async () => {
        const videoData = {
          status: 'failed',
          source: { error: internal }
        };
        mockKV.get.mockResolvedValue(JSON.stringify(videoData));
        
        const request = new Request(`http://localhost:8787/v1/media/status/${validUuid}`);
        const response = await handler.handleStatusCheck(request, validUuid, mockCtx);
        
        const body = await response.json();
        expect(body.error).toBe(expected);
      });
    });
  });
});