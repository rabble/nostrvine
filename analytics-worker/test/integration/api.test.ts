// ABOUTME: Integration tests for analytics worker API endpoints with real request/response flows
// ABOUTME: Tests complete API workflows including routing, error handling, and data persistence

import { describe, it, expect, beforeEach } from 'vitest';
import worker from '../../src/index';

// Mock environment for integration tests
const env = {
  ANALYTICS_KV: {
    get: vi.fn(),
    put: vi.fn(),
    list: vi.fn(),
  },
  ENVIRONMENT: 'test',
  MIN_VIEWS_FOR_TRENDING: '10',
  TRENDING_UPDATE_INTERVAL: '300',
};

describe('Analytics API Integration', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('POST /analytics/view', () => {
    it('should handle complete view tracking workflow', async () => {
      // Arrange
      const request = new Request('https://analytics.openvine.co/analytics/view', {
        method: 'POST',
        headers: { 
          'Content-Type': 'application/json',
          'CF-Connecting-IP': '192.168.1.1'
        },
        body: JSON.stringify({
          eventId: '22e73ca1faedb07dd3e24c1dca52d849aa75c6e4090eb60c532820b782c93da3',
          source: 'web'
        })
      });

      env.ANALYTICS_KV.get.mockResolvedValue(null); // First view

      // Act
      const response = await worker.fetch(request, env);
      const result = await response.json();

      // Assert
      expect(response.status).toBe(200);
      expect(response.headers.get('Content-Type')).toBe('application/json');
      expect(result.success).toBe(true);
      expect(result.eventId).toBe('22e73ca1faedb07dd3e24c1dca52d849aa75c6e4090eb60c532820b782c93da3');
      expect(result.views).toBe(1);
      
      // Verify KV operations
      expect(env.ANALYTICS_KV.get).toHaveBeenCalledWith('view:22e73ca1faedb07dd3e24c1dca52d849aa75c6e4090eb60c532820b782c93da3');
      expect(env.ANALYTICS_KV.put).toHaveBeenCalledWith(
        'view:22e73ca1faedb07dd3e24c1dca52d849aa75c6e4090eb60c532820b782c93da3',
        expect.stringContaining('"count":1')
      );
    });

    it('should handle CORS preflight requests', async () => {
      // Arrange
      const request = new Request('https://analytics.openvine.co/analytics/view', {
        method: 'OPTIONS',
        headers: {
          'Origin': 'https://openvine.co',
          'Access-Control-Request-Method': 'POST'
        }
      });

      // Act
      const response = await worker.fetch(request, env);

      // Assert
      expect(response.status).toBe(200);
      expect(response.headers.get('Access-Control-Allow-Origin')).toBe('*');
      expect(response.headers.get('Access-Control-Allow-Methods')).toContain('POST');
      expect(response.headers.get('Access-Control-Allow-Headers')).toContain('Content-Type');
    });

    it('should return 405 for wrong HTTP method', async () => {
      // Arrange
      const request = new Request('https://analytics.openvine.co/analytics/view', {
        method: 'GET'
      });

      // Act
      const response = await worker.fetch(request, env);
      const result = await response.json();

      // Assert
      expect(response.status).toBe(405);
      expect(result.error).toContain('Method not allowed');
    });
  });

  describe('GET /analytics/trending/videos', () => {
    it('should return trending videos with proper structure', async () => {
      // Arrange
      const request = new Request('https://analytics.openvine.co/analytics/trending/videos?limit=5');

      env.ANALYTICS_KV.list.mockResolvedValue({
        keys: [
          { name: 'view:event1' },
          { name: 'view:event2' },
        ]
      });

      const now = Date.now();
      env.ANALYTICS_KV.get
        .mockResolvedValueOnce(JSON.stringify({ count: 50, lastUpdate: now - 3600000 }))  // 1 hour ago
        .mockResolvedValueOnce(JSON.stringify({ count: 30, lastUpdate: now - 1800000 })); // 30 min ago

      // Act
      const response = await worker.fetch(request, env);
      const result = await response.json();

      // Assert
      expect(response.status).toBe(200);
      expect(response.headers.get('Content-Type')).toBe('application/json');
      expect(result.videos).toBeInstanceOf(Array);
      expect(result.algorithm).toBe('global_popularity');
      expect(result.updatedAt).toBeTypeOf('number');
      expect(result.videos.length).toBeLessThanOrEqual(5);
      
      // Check structure of video entries
      if (result.videos.length > 0) {
        const video = result.videos[0];
        expect(video).toHaveProperty('eventId');
        expect(video).toHaveProperty('views');
        expect(video).toHaveProperty('score');
        expect(typeof video.eventId).toBe('string');
        expect(typeof video.views).toBe('number');
        expect(typeof video.score).toBe('number');
      }
    });

    it('should handle query parameters correctly', async () => {
      // Arrange
      const request = new Request('https://analytics.openvine.co/analytics/trending/videos?limit=2');

      env.ANALYTICS_KV.list.mockResolvedValue({
        keys: Array.from({ length: 5 }, (_, i) => ({ name: `view:event${i}` }))
      });

      env.ANALYTICS_KV.get.mockImplementation(() => 
        Promise.resolve(JSON.stringify({ count: 100, lastUpdate: Date.now() }))
      );

      // Act
      const response = await worker.fetch(request, env);
      const result = await response.json();

      // Assert
      expect(response.status).toBe(200);
      expect(result.videos).toHaveLength(2); // Respects limit parameter
    });
  });

  describe('GET /analytics/video/{eventId}/stats', () => {
    it('should return video statistics', async () => {
      // Arrange
      const eventId = '22e73ca1faedb07dd3e24c1dca52d849aa75c6e4090eb60c532820b782c93da3';
      const request = new Request(`https://analytics.openvine.co/analytics/video/${eventId}/stats`);

      const viewData = { count: 42, lastUpdate: Date.now() };
      env.ANALYTICS_KV.get.mockResolvedValue(JSON.stringify(viewData));

      // Act
      const response = await worker.fetch(request, env);
      const result = await response.json();

      // Assert
      expect(response.status).toBe(200);
      expect(result.eventId).toBe(eventId);
      expect(result.count).toBe(42);
      expect(result.lastUpdate).toBe(viewData.lastUpdate);
    });

    it('should handle video with no views', async () => {
      // Arrange
      const eventId = '22e73ca1faedb07dd3e24c1dca52d849aa75c6e4090eb60c532820b782c93da3';
      const request = new Request(`https://analytics.openvine.co/analytics/video/${eventId}/stats`);

      env.ANALYTICS_KV.get.mockResolvedValue(null); // No views recorded

      // Act
      const response = await worker.fetch(request, env);
      const result = await response.json();

      // Assert
      expect(response.status).toBe(200);
      expect(result.eventId).toBe(eventId);
      expect(result.count).toBe(0);
    });
  });

  describe('Error Handling', () => {
    it('should return 404 for unknown endpoints', async () => {
      // Arrange
      const request = new Request('https://analytics.openvine.co/unknown/endpoint');

      // Act
      const response = await worker.fetch(request, env);
      const result = await response.json();

      // Assert
      expect(response.status).toBe(404);
      expect(result.error).toContain('Not Found');
    });

    it('should handle KV storage errors gracefully', async () => {
      // Arrange
      const request = new Request('https://analytics.openvine.co/analytics/view', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          eventId: '22e73ca1faedb07dd3e24c1dca52d849aa75c6e4090eb60c532820b782c93da3',
          source: 'web'
        })
      });

      env.ANALYTICS_KV.get.mockRejectedValue(new Error('KV storage error'));

      // Act
      const response = await worker.fetch(request, env);
      const result = await response.json();

      // Assert
      expect(response.status).toBe(500);
      expect(result.error).toContain('Internal server error');
    });
  });

  describe('Security and Validation', () => {
    it('should validate event ID format', async () => {
      // Arrange
      const request = new Request('https://analytics.openvine.co/analytics/view', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          eventId: 'invalid-format',
          source: 'web'
        })
      });

      // Act
      const response = await worker.fetch(request, env);
      const result = await response.json();

      // Assert
      expect(response.status).toBe(400);
      expect(result.error).toContain('Invalid event ID format');
    });

    it('should handle malicious input safely', async () => {
      // Arrange
      const request = new Request('https://analytics.openvine.co/analytics/view', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          eventId: '<script>alert("xss")</script>',
          source: 'web'
        })
      });

      // Act
      const response = await worker.fetch(request, env);
      const result = await response.json();

      // Assert
      expect(response.status).toBe(400);
      expect(result.error).toContain('Invalid event ID format');
    });
  });
});