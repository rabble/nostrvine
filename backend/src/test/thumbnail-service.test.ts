// ABOUTME: Test script for thumbnail service functionality
// ABOUTME: Verifies thumbnail generation, caching, and storage

import { describe, it, expect, beforeEach } from 'vitest';
import { ThumbnailService } from '../services/ThumbnailService';

// Mock environment with all required Env properties
const mockEnv = {
  MEDIA_BUCKET: {
    get: async (key: string) => null,
    put: async (key: string, value: any, options?: any) => {},
    delete: async (key: string) => {},
  } as any,
  METADATA_CACHE: {
    get: async (key: string, type?: string) => null,
    put: async (key: string, value: string, options?: any) => {},
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

describe('ThumbnailService', () => {
  let thumbnailService: ThumbnailService;

  beforeEach(() => {
    thumbnailService = new ThumbnailService(mockEnv);
  });

  it('should return placeholder for non-existent video', async () => {
    const response = await thumbnailService.getThumbnail('non-existent-video');
    
    expect(response.status).toBe(200);
    expect(response.headers.get('Content-Type')).toBe('image/svg+xml');
  });

  it('should handle different thumbnail sizes', async () => {
    const sizes = ['small', 'medium', 'large'] as const;
    
    for (const size of sizes) {
      const response = await thumbnailService.getThumbnail('test-video', { size });
      expect(response).toBeDefined();
    }
  });

  it('should support custom timestamps', async () => {
    const response = await thumbnailService.getThumbnail('test-video', { 
      timestamp: 5 
    });
    
    expect(response).toBeDefined();
  });

  it('should support webp format', async () => {
    const response = await thumbnailService.getThumbnail('test-video', { 
      format: 'webp' 
    });
    
    expect(response).toBeDefined();
  });

  it('should list thumbnails for a video', async () => {
    const thumbnails = await thumbnailService.listThumbnails('test-video');
    
    expect(Array.isArray(thumbnails)).toBe(true);
  });

  it('should handle custom thumbnail upload', async () => {
    const mockImageData = new ArrayBuffer(100);
    
    // Mock the URL signer
    const originalSignUrl = (thumbnailService as any).urlSigner.signUrl;
    (thumbnailService as any).urlSigner.signUrl = async () => 'https://signed-url.example.com';
    
    const url = await thumbnailService.uploadCustomThumbnail('test-video', mockImageData);
    
    expect(url).toBe('https://signed-url.example.com');
    
    // Restore original method
    (thumbnailService as any).urlSigner.signUrl = originalSignUrl;
  });
});