// ABOUTME: Tests for the batch video lookup API endpoint
// ABOUTME: Verifies bulk metadata retrieval and partial results handling

import { describe, it, expect, beforeAll } from 'vitest';

// Generate test video IDs using Web Crypto API
async function generateTestVideoId(url: string): Promise<string> {
  const encoder = new TextEncoder();
  const data = encoder.encode(url);
  const hashBuffer = await crypto.subtle.digest('SHA-256', data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
}

describe('Batch Video API', () => {
  const baseUrl = 'http://localhost:8787';
  let testVideoIds: string[];

  beforeAll(async () => {
    testVideoIds = await Promise.all([
      generateTestVideoId('https://example.com/video1.mp4'),
      generateTestVideoId('https://example.com/video2.mp4'),
      generateTestVideoId('https://example.com/video3.mp4'),
    ]);
  });

  describe('POST /api/videos/batch', () => {
    it('should return 400 for invalid request body', async () => {
      const response = await fetch(`${baseUrl}/api/videos/batch`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: 'invalid json',
      });
      
      expect(response.status).toBe(400);
      const data = await response.json();
      expect(data.error).toBe('Invalid request body');
    });

    it('should return 400 for missing videoIds', async () => {
      const response = await fetch(`${baseUrl}/api/videos/batch`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ quality: 'auto' }),
      });
      
      expect(response.status).toBe(400);
      const data = await response.json();
      expect(data.error).toBe('videoIds must be an array');
    });

    it('should return 400 for too many video IDs', async () => {
      const tooManyIds = Array(51).fill('a'.repeat(64));
      const response = await fetch(`${baseUrl}/api/videos/batch`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ videoIds: tooManyIds }),
      });
      
      expect(response.status).toBe(400);
      const data = await response.json();
      expect(data.error).toBe('Maximum 50 video IDs per request');
    });

    it('should handle CORS preflight requests', async () => {
      const response = await fetch(`${baseUrl}/api/videos/batch`, {
        method: 'OPTIONS',
      });
      
      expect(response.status).toBe(204);
      expect(response.headers.get('Access-Control-Allow-Origin')).toBe('*');
      expect(response.headers.get('Access-Control-Allow-Methods')).toContain('POST');
    });

    it('should handle mix of valid and invalid video IDs', async () => {
      const mixedIds = [
        testVideoIds[0], // might exist
        'invalid-format', // invalid format
        'a'.repeat(64), // valid format but doesn't exist
      ];

      const response = await fetch(`${baseUrl}/api/videos/batch`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ videoIds: mixedIds }),
      });
      
      expect(response.status).toBe(200);
      const data = await response.json();
      
      // Verify response structure
      expect(data).toHaveProperty('videos');
      expect(data).toHaveProperty('found');
      expect(data).toHaveProperty('missing');
      
      // Check individual video responses
      expect(data.videos['invalid-format']).toEqual({
        videoId: 'invalid-format',
        available: false,
        reason: 'invalid_format',
      });
      
      expect(data.videos['a'.repeat(64)]).toEqual({
        videoId: 'a'.repeat(64),
        available: false,
        reason: 'not_found',
      });
    });

    it('should respect quality parameter', async () => {
      const response480p = await fetch(`${baseUrl}/api/videos/batch`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ 
          videoIds: [testVideoIds[0]],
          quality: '480p',
        }),
      });
      
      expect(response480p.status).toBe(200);
      const data480p = await response480p.json();
      
      if (data480p.found > 0) {
        const video = data480p.videos[testVideoIds[0]];
        expect(video.renditions['480p']).toBeTruthy();
        // When specific quality requested, other might be empty
      }
    });

    it('should handle duplicate video IDs', async () => {
      const duplicateIds = [testVideoIds[0], testVideoIds[0], testVideoIds[0]];
      
      const response = await fetch(`${baseUrl}/api/videos/batch`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ videoIds: duplicateIds }),
      });
      
      expect(response.status).toBe(200);
      const data = await response.json();
      
      // Should only process unique IDs
      const videoCount = Object.keys(data.videos).length;
      expect(videoCount).toBe(1);
    });

    it('should set appropriate cache headers', async () => {
      const response = await fetch(`${baseUrl}/api/videos/batch`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ videoIds: testVideoIds }),
      });
      
      expect(response.status).toBe(200);
      expect(response.headers.get('Cache-Control')).toBe('public, max-age=300');
    });
  });
});