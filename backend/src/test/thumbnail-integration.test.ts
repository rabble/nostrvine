// ABOUTME: Integration test for thumbnail service with realistic video metadata
// ABOUTME: Tests the full workflow including Stream video processing

import { describe, it, expect, beforeEach } from 'vitest';
import { ThumbnailService } from '../services/ThumbnailService';

// Mock complete environment
const mockEnv = {
  MEDIA_BUCKET: {
    get: async (key: string) => {
      // Simulate that no thumbnails exist yet
      return null;
    },
    put: async (key: string, value: any, options?: any) => {
      console.log(`[TEST] Storing thumbnail: ${key}`);
    },
    delete: async (key: string) => {},
  } as any,
  METADATA_CACHE: {
    get: async (key: string, type?: string) => {
      if (key === 'video:stream-video-123') {
        // Mock a video processed by Cloudflare Stream
        return {
          videoId: 'stream-video-123',
          status: 'published',
          stream: {
            uid: 'cf-stream-uid-456',
            thumbnailUrl: 'https://customer-test.cloudflarestream.com/cf-stream-uid-456/thumbnails/thumbnail.jpg',
            hlsUrl: 'https://customer-test.cloudflarestream.com/cf-stream-uid-456/manifest/video.m3u8'
          }
        };
      }
      if (key === 'video:r2-video-789') {
        // Mock a direct R2 upload
        return {
          videoId: 'r2-video-789',
          status: 'published',
          r2Key: 'videos/r2-video-789.mp4'
        };
      }
      return null;
    },
    put: async (key: string, value: string, options?: any) => {
      console.log(`[TEST] Caching metadata: ${key}`);
    },
    delete: async (key: string) => {},
    list: async (options?: any) => ({ keys: [] }),
  } as any,
  NIP05_STORE: {} as any,
  ENVIRONMENT: 'development' as const,
  BASE_URL: 'http://localhost:8787' as const,
  MAX_FILE_SIZE_FREE: '104857600',
  MAX_FILE_SIZE_PRO: '1073741824',
  WEBHOOK_SECRET: 'test-secret',
  CLOUDINARY_CLOUD_NAME: 'test-cloud',
  CLOUDFLARE_IMAGES_ACCOUNT_HASH: 'test-hash',
  UPLOAD_JOBS: {} as any,
  UPLOAD_ANALYTICS: {} as any,
} as Env;

// Mock fetch for Stream thumbnail requests
global.fetch = async (url: string | URL) => {
  const urlStr = url.toString();
  console.log(`[TEST] Fetching: ${urlStr}`);
  
  if (urlStr.includes('cloudflarestream.com') && urlStr.includes('thumbnail')) {
    // Mock successful Stream thumbnail response
    const mockImageData = new Uint8Array([0xFF, 0xD8, 0xFF, 0xE0]); // JPEG header
    return new Response(mockImageData, {
      status: 200,
      headers: { 'Content-Type': 'image/jpeg' }
    });
  }
  
  return new Response('Not found', { status: 404 });
};

describe('Thumbnail Service Integration', () => {
  let thumbnailService: ThumbnailService;

  beforeEach(() => {
    thumbnailService = new ThumbnailService(mockEnv);
  });

  it('should generate thumbnail for Stream video', async () => {
    const response = await thumbnailService.getThumbnail('stream-video-123', {
      size: 'medium',
      timestamp: 2.5
    });
    
    expect(response.status).toBe(200);
    expect(response.headers.get('Content-Type')).toBe('image/jpeg');
    expect(response.headers.get('X-Thumbnail-Generated')).toBe('true');
    
    console.log('[TEST] ✅ Stream video thumbnail generated successfully');
  });

  it('should return placeholder for R2 video (unsupported)', async () => {
    const response = await thumbnailService.getThumbnail('r2-video-789');
    
    expect(response.status).toBe(200);
    expect(response.headers.get('Content-Type')).toBe('image/svg+xml');
    
    console.log('[TEST] ✅ R2 video returns placeholder as expected');
  });

  it('should handle different sizes for Stream video', async () => {
    const sizes: Array<'small' | 'medium' | 'large'> = ['small', 'medium', 'large'];
    
    for (const size of sizes) {
      const response = await thumbnailService.getThumbnail('stream-video-123', { size });
      expect(response.status).toBe(200);
      console.log(`[TEST] ✅ ${size} thumbnail generated`);
    }
  });

  it('should handle WebP format for Stream video', async () => {
    const response = await thumbnailService.getThumbnail('stream-video-123', {
      format: 'webp'
    });
    
    expect(response.status).toBe(200);
    expect(response.headers.get('Content-Type')).toBe('image/jpeg');
    
    console.log('[TEST] ✅ WebP format handled (fallback to JPEG)');
  });

  it('should list thumbnails for a video', async () => {
    const thumbnails = await thumbnailService.listThumbnails('stream-video-123');
    
    expect(Array.isArray(thumbnails)).toBe(true);
    console.log(`[TEST] ✅ Listed ${thumbnails.length} thumbnails`);
  });
});