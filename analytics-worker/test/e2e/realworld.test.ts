// ABOUTME: End-to-end tests against real deployed analytics worker with actual KV storage
// ABOUTME: Tests complete workflows including real network requests and data persistence

import { describe, it, expect, beforeAll } from 'vitest';

const WORKER_URL = 'https://openvine-analytics.protestnet.workers.dev';

describe('Analytics Worker E2E Tests', () => {
  let testEventId: string;

  beforeAll(() => {
    // Generate a unique test event ID for this test run
    testEventId = `test-${Date.now()}-${Math.random().toString(36).substring(7)}`;
  });

  describe('View Tracking E2E', () => {
    it('should track views for a new video', async () => {
      // Act - Track first view
      const response = await fetch(`${WORKER_URL}/analytics/view`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          eventId: testEventId,
          source: 'e2e-test'
        })
      });

      const result = await response.json();

      // Assert
      expect(response.status).toBe(200);
      expect(result.success).toBe(true);
      expect(result.eventId).toBe(testEventId);
      expect(result.views).toBe(1);
    });

    it('should increment views on subsequent tracking', async () => {
      // Act - Track second view
      const response = await fetch(`${WORKER_URL}/analytics/view`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          eventId: testEventId,
          source: 'e2e-test'
        })
      });

      const result = await response.json();

      // Assert
      expect(response.status).toBe(200);
      expect(result.success).toBe(true);
      expect(result.views).toBe(2);
    });

    it('should persist view data between requests', async () => {
      // Act - Get stats for the test video
      const response = await fetch(`${WORKER_URL}/analytics/video/${testEventId}/stats`);
      const result = await response.json();

      // Assert
      expect(response.status).toBe(200);
      expect(result.eventId).toBe(testEventId);
      expect(result.count).toBeGreaterThanOrEqual(2);
      expect(result.lastUpdate).toBeTypeOf('number');
    });
  });

  describe('Trending Videos E2E', () => {
    it('should return trending videos list', async () => {
      // Act
      const response = await fetch(`${WORKER_URL}/analytics/trending/videos?limit=10`);
      const result = await response.json();

      // Assert
      expect(response.status).toBe(200);
      expect(result.videos).toBeInstanceOf(Array);
      expect(result.algorithm).toBe('global_popularity');
      expect(result.updatedAt).toBeTypeOf('number');

      // If there are videos, check their structure
      if (result.videos.length > 0) {
        const video = result.videos[0];
        expect(video).toHaveProperty('eventId');
        expect(video).toHaveProperty('views');
        expect(video).toHaveProperty('score');
        expect(typeof video.eventId).toBe('string');
        expect(typeof video.views).toBe('number');
        expect(typeof video.score).toBe('number');
        expect(video.score).toBeGreaterThan(0);
      }
    });

    it('should handle limit parameter correctly', async () => {
      // Act
      const response = await fetch(`${WORKER_URL}/analytics/trending/videos?limit=3`);
      const result = await response.json();

      // Assert
      expect(response.status).toBe(200);
      expect(result.videos.length).toBeLessThanOrEqual(3);
    });
  });

  describe('CORS Support E2E', () => {
    it('should handle preflight OPTIONS requests', async () => {
      // Act
      const response = await fetch(`${WORKER_URL}/analytics/view`, {
        method: 'OPTIONS',
        headers: {
          'Origin': 'https://openvine.co',
          'Access-Control-Request-Method': 'POST',
          'Access-Control-Request-Headers': 'Content-Type'
        }
      });

      // Assert
      expect(response.status).toBe(200);
      expect(response.headers.get('Access-Control-Allow-Origin')).toBe('*');
      expect(response.headers.get('Access-Control-Allow-Methods')).toContain('POST');
      expect(response.headers.get('Access-Control-Allow-Headers')).toContain('Content-Type');
    });

    it('should include CORS headers in actual responses', async () => {
      // Act
      const response = await fetch(`${WORKER_URL}/analytics/view`, {
        method: 'POST',
        headers: { 
          'Content-Type': 'application/json',
          'Origin': 'https://openvine.co'
        },
        body: JSON.stringify({
          eventId: testEventId,
          source: 'cors-test'
        })
      });

      // Assert
      expect(response.status).toBe(200);
      expect(response.headers.get('Access-Control-Allow-Origin')).toBe('*');
    });
  });

  describe('Error Handling E2E', () => {
    it('should reject invalid event IDs', async () => {
      // Act
      const response = await fetch(`${WORKER_URL}/analytics/view`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          eventId: 'invalid-id-format',
          source: 'test'
        })
      });

      const result = await response.json();

      // Assert
      expect(response.status).toBe(400);
      expect(result.error).toContain('Invalid event ID format');
    });

    it('should handle missing request body', async () => {
      // Act
      const response = await fetch(`${WORKER_URL}/analytics/view`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' }
      });

      const result = await response.json();

      // Assert
      expect(response.status).toBe(400);
      expect(result.error).toBeDefined();
    });

    it('should return 404 for unknown endpoints', async () => {
      // Act
      const response = await fetch(`${WORKER_URL}/unknown/endpoint`);
      const result = await response.json();

      // Assert
      expect(response.status).toBe(404);
      expect(result.error).toContain('Not Found');
    });

    it('should return 405 for wrong HTTP methods', async () => {
      // Act
      const response = await fetch(`${WORKER_URL}/analytics/view`, {
        method: 'DELETE'
      });

      const result = await response.json();

      // Assert
      expect(response.status).toBe(405);
      expect(result.error).toContain('Method not allowed');
    });
  });

  describe('Performance and Reliability E2E', () => {
    it('should handle concurrent requests', async () => {
      // Arrange - Create multiple concurrent requests
      const concurrentRequests = Array.from({ length: 5 }, (_, i) => 
        fetch(`${WORKER_URL}/analytics/view`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            eventId: `concurrent-test-${i}-${Date.now()}`,
            source: 'concurrent-test'
          })
        })
      );

      // Act
      const responses = await Promise.all(concurrentRequests);
      const results = await Promise.all(responses.map(r => r.json()));

      // Assert
      responses.forEach(response => {
        expect(response.status).toBe(200);
      });

      results.forEach(result => {
        expect(result.success).toBe(true);
        expect(result.views).toBe(1); // Each should get first view
      });
    });

    it('should respond within acceptable time limits', async () => {
      const startTime = Date.now();

      // Act
      const response = await fetch(`${WORKER_URL}/analytics/trending/videos?limit=10`);
      
      const endTime = Date.now();
      const responseTime = endTime - startTime;

      // Assert
      expect(response.status).toBe(200);
      expect(responseTime).toBeLessThan(5000); // Should respond within 5 seconds
    });
  });

  describe('Data Consistency E2E', () => {
    it('should maintain view count accuracy across multiple operations', async () => {
      const consistencyTestId = `consistency-${Date.now()}`;
      
      // Track 3 views
      for (let i = 0; i < 3; i++) {
        const response = await fetch(`${WORKER_URL}/analytics/view`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            eventId: consistencyTestId,
            source: 'consistency-test'
          })
        });
        
        expect(response.status).toBe(200);
      }

      // Verify final count
      const statsResponse = await fetch(`${WORKER_URL}/analytics/video/${consistencyTestId}/stats`);
      const stats = await statsResponse.json();

      expect(statsResponse.status).toBe(200);
      expect(stats.count).toBe(3);
    });
  });
});