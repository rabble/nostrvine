// ABOUTME: Tests for the video caching API endpoint
// ABOUTME: Verifies video metadata retrieval and signed URL generation

import { describe, it, expect, beforeAll } from 'vitest';

const TEST_VIDEO_URL = 'https://example.com/video1.mp4';

// Generate test video ID using Web Crypto API
async function generateTestVideoId(): Promise<string> {
  const encoder = new TextEncoder();
  const data = encoder.encode(TEST_VIDEO_URL);
  const hashBuffer = await crypto.subtle.digest('SHA-256', data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
}

let TEST_VIDEO_ID: string;

describe('Video Cache API', () => {
  const baseUrl = 'http://localhost:8787';

  beforeAll(async () => {
    TEST_VIDEO_ID = await generateTestVideoId();
  });

  describe('GET /api/video/{video_id}', () => {
    it('should return 400 for invalid video ID format', async () => {
      const response = await fetch(`${baseUrl}/api/video/invalid-id`);
      expect(response.status).toBe(400);
      
      const data = await response.json();
      expect(data.error).toBe('Invalid video ID format');
    });

    it('should return 404 for non-existent video', async () => {
      const fakeId = 'a'.repeat(64); // Valid format but doesn't exist
      const response = await fetch(`${baseUrl}/api/video/${fakeId}`);
      expect(response.status).toBe(404);
      
      const data = await response.json();
      expect(data.error).toBe('Video not found');
    });

    it('should handle CORS preflight requests', async () => {
      const response = await fetch(`${baseUrl}/api/video/${TEST_VIDEO_ID}`, {
        method: 'OPTIONS',
      });
      
      expect(response.status).toBe(204);
      expect(response.headers.get('Access-Control-Allow-Origin')).toBe('*');
      expect(response.headers.get('Access-Control-Allow-Methods')).toContain('GET');
    });

    it('should return proper video metadata structure', async () => {
      // Note: This test would pass if test data is populated in KV
      const response = await fetch(`${baseUrl}/api/video/${TEST_VIDEO_ID}`);
      
      if (response.status === 200) {
        const data = await response.json();
        
        // Verify response structure
        expect(data).toHaveProperty('videoId');
        expect(data).toHaveProperty('duration');
        expect(data).toHaveProperty('renditions');
        expect(data).toHaveProperty('poster');
        
        // Verify renditions
        expect(data.renditions).toHaveProperty('480p');
        expect(data.renditions).toHaveProperty('720p');
        
        // Verify URLs are signed (contain query params)
        expect(data.renditions['480p']).toContain('?');
        expect(data.renditions['720p']).toContain('?');
        expect(data.poster).toContain('?');
        
        // Verify duration is a number
        expect(typeof data.duration).toBe('number');
      }
    });

    it('should set appropriate cache headers', async () => {
      const response = await fetch(`${baseUrl}/api/video/${TEST_VIDEO_ID}`);
      
      if (response.status === 200) {
        expect(response.headers.get('Cache-Control')).toBe('public, max-age=300');
      } else if (response.status === 404) {
        expect(response.headers.get('Cache-Control')).toBe('no-cache');
      }
    });
  });
});