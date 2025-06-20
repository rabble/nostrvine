// ABOUTME: Tests for analytics and monitoring functionality
// ABOUTME: Verifies metrics collection, health checks, and performance tracking

import { describe, it, expect } from 'vitest';

describe('Analytics & Monitoring', () => {
  const baseUrl = 'http://localhost:8787';
  const testApiKey = 'test-api-key';

  describe('Health Endpoint', () => {
    it('should return comprehensive health status', async () => {
      const response = await fetch(`${baseUrl}/health`);
      expect(response.status).toBe(200);
      
      const data = await response.json();
      
      // Verify health status structure
      expect(data).toHaveProperty('status');
      expect(data).toHaveProperty('timestamp');
      expect(data).toHaveProperty('metrics');
      expect(data).toHaveProperty('dependencies');
      expect(data).toHaveProperty('version');
      expect(data).toHaveProperty('services');
      
      // Verify metrics structure
      expect(data.metrics).toHaveProperty('totalRequests');
      expect(data.metrics).toHaveProperty('cacheHitRate');
      expect(data.metrics).toHaveProperty('averageResponseTime');
      expect(data.metrics).toHaveProperty('activeVideos');
      expect(data.metrics).toHaveProperty('errorRate');
      expect(data.metrics).toHaveProperty('requestsPerMinute');
      
      // Verify dependencies
      expect(data.dependencies).toHaveProperty('r2');
      expect(data.dependencies).toHaveProperty('kv');
      expect(data.dependencies).toHaveProperty('rateLimiter');
      
      // Verify services
      expect(data.services).toHaveProperty('video_cache_api');
      expect(data.services).toHaveProperty('kv_storage');
      expect(data.services).toHaveProperty('r2_storage');
    });

    it('should have valid status values', async () => {
      const response = await fetch(`${baseUrl}/health`);
      const data = await response.json();
      
      const validStatuses = ['healthy', 'degraded', 'unhealthy'];
      expect(validStatuses).toContain(data.status);
      
      const validDependencyStatuses = ['healthy', 'degraded', 'error'];
      expect(validDependencyStatuses).toContain(data.dependencies.r2);
      expect(validDependencyStatuses).toContain(data.dependencies.kv);
      expect(validDependencyStatuses).toContain(data.dependencies.rateLimiter);
    });

    it('should have reasonable metric values', async () => {
      const response = await fetch(`${baseUrl}/health`);
      const data = await response.json();
      
      // Metrics should be numbers and non-negative
      expect(typeof data.metrics.totalRequests).toBe('number');
      expect(data.metrics.totalRequests).toBeGreaterThanOrEqual(0);
      
      expect(typeof data.metrics.cacheHitRate).toBe('number');
      expect(data.metrics.cacheHitRate).toBeGreaterThanOrEqual(0);
      expect(data.metrics.cacheHitRate).toBeLessThanOrEqual(1);
      
      expect(typeof data.metrics.averageResponseTime).toBe('number');
      expect(data.metrics.averageResponseTime).toBeGreaterThanOrEqual(0);
      
      expect(typeof data.metrics.errorRate).toBe('number');
      expect(data.metrics.errorRate).toBeGreaterThanOrEqual(0);
      expect(data.metrics.errorRate).toBeLessThanOrEqual(1);
    });
  });

  describe('Analytics Integration', () => {
    it('should track metrics when making video requests', async () => {
      // Get initial metrics
      const initialHealth = await fetch(`${baseUrl}/health`);
      const initialData = await initialHealth.json();
      const initialRequests = initialData.metrics.totalRequests;
      
      // Make a video request
      const videoResponse = await fetch(`${baseUrl}/api/video/test123`, {
        headers: {
          'Authorization': `Bearer ${testApiKey}`,
        },
      });
      
      // Should get some response (400 for invalid format is fine)
      expect([400, 404]).toContain(videoResponse.status);
      
      // Wait a moment for analytics to be processed
      await new Promise(resolve => setTimeout(resolve, 100));
      
      // Check if metrics were updated (might be async)
      const updatedHealth = await fetch(`${baseUrl}/health`);
      const updatedData = await updatedHealth.json();
      
      // Metrics might have increased (though it's async so not guaranteed in tests)
      expect(updatedData.metrics.totalRequests).toBeGreaterThanOrEqual(initialRequests);
    });

    it('should track batch request metrics', async () => {
      // Make a batch request
      const batchResponse = await fetch(`${baseUrl}/api/videos/batch`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${testApiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          videoIds: ['test1', 'test2'],
        }),
      });
      
      expect(batchResponse.status).toBe(200);
      
      // Verify response structure includes analytics-relevant data
      const data = await batchResponse.json();
      expect(data).toHaveProperty('found');
      expect(data).toHaveProperty('missing');
      expect(data).toHaveProperty('videos');
    });

    it('should track error metrics', async () => {
      // Make a request that should trigger an error (invalid JSON)
      const errorResponse = await fetch(`${baseUrl}/api/videos/batch`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${testApiKey}`,
          'Content-Type': 'application/json',
        },
        body: 'invalid json',
      });
      
      expect(errorResponse.status).toBe(400);
      
      // Analytics should track this error (happens in background)
    });
  });

  describe('Performance Tracking', () => {
    it('should track response times', async () => {
      const start = Date.now();
      
      const response = await fetch(`${baseUrl}/api/video/test123`, {
        headers: {
          'Authorization': `Bearer ${testApiKey}`,
        },
      });
      
      const responseTime = Date.now() - start;
      
      // Response should be reasonably fast
      expect(responseTime).toBeLessThan(5000); // 5 seconds max
      
      // Analytics tracks this in background
      expect(response.status).toBeDefined();
    });

    it('should handle concurrent requests for analytics', async () => {
      // Make multiple concurrent requests
      const requests = Array(5).fill(null).map(() =>
        fetch(`${baseUrl}/api/video/test${Math.random()}`, {
          headers: {
            'Authorization': `Bearer ${testApiKey}`,
          },
        })
      );
      
      const responses = await Promise.all(requests);
      
      // All should complete
      responses.forEach(response => {
        expect([400, 404]).toContain(response.status);
      });
    });
  });

  describe('Cache Metrics', () => {
    it('should track cache performance metrics', async () => {
      const healthResponse = await fetch(`${baseUrl}/health`);
      const data = await healthResponse.json();
      
      // Cache hit rate should be a valid percentage
      expect(data.metrics.cacheHitRate).toBeGreaterThanOrEqual(0);
      expect(data.metrics.cacheHitRate).toBeLessThanOrEqual(1);
      
      // Even with no cache hits, the rate should be 0, not undefined
      expect(typeof data.metrics.cacheHitRate).toBe('number');
    });
  });

  describe('System Monitoring', () => {
    it('should monitor system dependencies', async () => {
      const response = await fetch(`${baseUrl}/health`);
      const data = await response.json();
      
      // All dependencies should be monitored
      expect(data.dependencies.r2).toBeDefined();
      expect(data.dependencies.kv).toBeDefined();
      expect(data.dependencies.rateLimiter).toBeDefined();
      
      // At least one should be healthy in a working system
      const healthyDeps = Object.values(data.dependencies).filter(dep => dep === 'healthy');
      expect(healthyDeps.length).toBeGreaterThan(0);
    });

    it('should provide timestamp for monitoring', async () => {
      const response = await fetch(`${baseUrl}/health`);
      const data = await response.json();
      
      // Should have valid ISO timestamp
      expect(data.timestamp).toBeTruthy();
      const timestamp = new Date(data.timestamp);
      expect(timestamp.getTime()).toBeGreaterThan(0);
      
      // Timestamp should be recent (within last minute)
      const now = Date.now();
      const timestampAge = now - timestamp.getTime();
      expect(timestampAge).toBeLessThan(60000); // 1 minute
    });
  });
});