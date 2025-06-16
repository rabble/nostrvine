// ABOUTME: Tests for NIP-96 HTTP file storage implementation
// ABOUTME: Validates server info endpoint, upload handling, and NIP-94 generation

import { describe, it, expect, beforeAll } from 'vitest';
import { handleNIP96Info } from '../handlers/nip96-info';
import { generateNIP94Event, validateNIP94Event, calculateSHA256 } from '../utils/nip94-generator';
import { FileMetadata } from '../types/nip96';

// Mock environment for testing
const mockEnv = {
  CLOUDFLARE_ACCOUNT_ID: 'test-account',
  CLOUDFLARE_STREAM_TOKEN: 'test-token',
  FRAMES_BUCKET: null,
  MEDIA_BUCKET: null,
  CACHE_BUCKET: null
} as unknown as Env;

describe('NIP-96 Server Information', () => {
  it('should return valid server capabilities', async () => {
    const request = new Request('https://nostrvine.com/.well-known/nostr/nip96.json');
    const response = await handleNIP96Info(request, mockEnv);
    
    expect(response.status).toBe(200);
    expect(response.headers.get('Content-Type')).toBe('application/json');
    
    const serverInfo = await response.json();
    
    // Validate required fields
    expect(serverInfo.api_url).toBe('https://nostrvine.com/api/upload');
    expect(serverInfo.download_url).toBe('https://nostrvine.com/media');
    expect(serverInfo.supported_nips).toContain(94);
    expect(serverInfo.supported_nips).toContain(96);
    expect(serverInfo.supported_nips).toContain(98);
    
    // Validate content types
    expect(serverInfo.content_types).toContain('video/mp4');
    expect(serverInfo.content_types).toContain('image/gif');
    
    // Validate plans
    expect(serverInfo.plans.free).toBeDefined();
    expect(serverInfo.plans.free.max_byte_size).toBe(104857600);
    expect(serverInfo.plans.free.media_transformations).toBeDefined();
  });

  it('should include proper CORS headers', async () => {
    const request = new Request('https://nostrvine.com/.well-known/nostr/nip96.json');
    const response = await handleNIP96Info(request, mockEnv);
    
    expect(response.headers.get('Access-Control-Allow-Origin')).toBe('*');
    expect(response.headers.get('Cache-Control')).toContain('max-age=3600');
  });
});

describe('NIP-94 Event Generation', () => {
  const mockMetadata: FileMetadata = {
    id: 'test-123',
    filename: 'test-video.mp4',
    content_type: 'video/mp4',
    size: 1024576,
    sha256: 'a1b2c3d4e5f67890123456789012345678901234567890123456789012345678',
    uploaded_at: Date.now(),
    url: 'https://stream.cloudflare.com/test-123/manifest/video.m3u8',
    thumbnail_url: 'https://videodelivery.net/test-123/thumbnails/thumbnail.jpg',
    dimensions: '640x640',
    duration: 6.5
  };

  it('should generate valid NIP-94 event data', () => {
    const { tags, content } = generateNIP94Event(
      mockMetadata,
      'Test vine video',
      'A short test video'
    );

    // Validate required tags
    const urlTag = tags.find(tag => tag[0] === 'url');
    expect(urlTag).toBeDefined();
    expect(urlTag![1]).toBe(mockMetadata.url);

    const mimeTag = tags.find(tag => tag[0] === 'm');
    expect(mimeTag).toBeDefined();
    expect(mimeTag![1]).toBe('video/mp4');

    const hashTag = tags.find(tag => tag[0] === 'x');
    expect(hashTag).toBeDefined();
    expect(hashTag![1]).toBe(mockMetadata.sha256);

    const sizeTag = tags.find(tag => tag[0] === 'size');
    expect(sizeTag).toBeDefined();
    expect(sizeTag![1]).toBe('1024576');

    // Validate optional tags
    const dimTag = tags.find(tag => tag[0] === 'dim');
    expect(dimTag![1]).toBe('640x640');

    const thumbTag = tags.find(tag => tag[0] === 'thumb');
    expect(thumbTag![1]).toBe(mockMetadata.thumbnail_url);

    const durationTag = tags.find(tag => tag[0] === 'duration');
    expect(durationTag![1]).toBe('6.5');

    const altTag = tags.find(tag => tag[0] === 'alt');
    expect(altTag![1]).toBe('A short test video');

    // Validate vine-specific tags
    const vineTags = tags.filter(tag => tag[0] === 't' && tag[1] === 'vine');
    expect(vineTags.length).toBeGreaterThan(0);

    expect(content).toBe('Test vine video');
  });

  it('should validate NIP-94 event data correctly', () => {
    const { tags, content } = generateNIP94Event(mockMetadata);
    const { valid, errors } = validateNIP94Event(tags, content);

    expect(valid).toBe(true);
    expect(errors).toHaveLength(0);
  });

  it('should detect invalid NIP-94 event data', () => {
    const invalidTags: Array<[string, string, ...string[]]> = [
      ['url', 'not-a-valid-url'],
      ['m', 'video/mp4'],
      ['x', 'invalid-hash'],
      ['size', 'not-a-number']
    ];

    const { valid, errors } = validateNIP94Event(invalidTags, 'test');

    expect(valid).toBe(false);
    expect(errors).toContain('Invalid URL format');
    expect(errors).toContain('Invalid SHA-256 hash format');
    expect(errors).toContain('Invalid size value');
  });
});

describe('Hash Calculation', () => {
  it('should calculate SHA-256 hash correctly', async () => {
    const testData = new TextEncoder().encode('Hello, NostrVine!');
    const hash = await calculateSHA256(testData.buffer);

    expect(hash).toHaveLength(64);
    expect(hash).toMatch(/^[a-f0-9]{64}$/);
    
    // Verify with known value
    const expectedHash = await crypto.subtle.digest('SHA-256', testData);
    const expectedHex = Array.from(new Uint8Array(expectedHash))
      .map(b => b.toString(16).padStart(2, '0'))
      .join('');
    
    expect(hash).toBe(expectedHex);
  });
});

describe('Content Type Validation', () => {
  it('should validate supported content types', async () => {
    const { isSupportedContentType } = await import('../handlers/nip96-info');
    
    expect(isSupportedContentType('video/mp4')).toBe(true);
    expect(isSupportedContentType('image/jpeg')).toBe(true);
    expect(isSupportedContentType('audio/mpeg')).toBe(true);
    expect(isSupportedContentType('text/plain')).toBe(false);
    expect(isSupportedContentType('application/pdf')).toBe(false);
  });

  it('should identify content requiring Stream processing', async () => {
    const { requiresStreamProcessing } = await import('../handlers/nip96-info');
    
    expect(requiresStreamProcessing('video/mp4')).toBe(true);
    expect(requiresStreamProcessing('video/webm')).toBe(true);
    expect(requiresStreamProcessing('image/jpeg')).toBe(false);
    expect(requiresStreamProcessing('audio/mpeg')).toBe(false);
  });

  it('should return correct size limits for plans', async () => {
    const { getMaxFileSize } = await import('../handlers/nip96-info');
    
    expect(getMaxFileSize('free')).toBe(104857600); // 100MB
    expect(getMaxFileSize('pro')).toBe(1073741824); // 1GB
    expect(getMaxFileSize('unknown')).toBe(104857600); // Default to free
  });
});