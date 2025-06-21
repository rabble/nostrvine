// ABOUTME: Tests for monitoring and analytics endpoints
// ABOUTME: Verifies health check, popular videos, and dashboard functionality

import { describe, it, expect, beforeEach, vi } from 'vitest';
import { MonitoringHandler } from '../src/monitoring-handler';
import { VideoAnalyticsService } from '../src/video-analytics-service';

// Mock environment
const mockEnv = {
  VIDEO_METADATA: {
    get: vi.fn(),
    put: vi.fn(),
    list: vi.fn(),
  },
  VIDEO_BUCKET: {
    head: vi.fn(),
  },
  ENVIRONMENT: 'test' as const,
  ENABLE_ANALYTICS: true,
};

// Mock execution context
const mockCtx = {
  waitUntil: vi.fn(),
  passThroughOnException: vi.fn(),
};

describe('MonitoringHandler', () => {
  let handler: MonitoringHandler;

  beforeEach(() => {
    vi.clearAllMocks();
    handler = new MonitoringHandler(mockEnv as any);
  });

  describe('handleHealthCheck', () => {
    it('should return healthy status when services are operational', async () => {
      // Mock successful service checks
      mockEnv.VIDEO_METADATA.get.mockResolvedValue(null);
      mockEnv.VIDEO_BUCKET.head.mockResolvedValue(null);

      const response = await handler.handleHealthCheck(mockCtx as any);
      const data = await response.json();

      expect(response.status).toBe(200);
      expect(data.status).toBe('healthy');
      expect(data.environment).toBe('test');
      expect(data.services.kv.status).toBe('operational');
      expect(data.services.r2.status).toBe('operational');
    });

    it('should return degraded status when analytics show issues', async () => {
      // Mock service checks
      mockEnv.VIDEO_METADATA.get.mockResolvedValue(null);
      mockEnv.VIDEO_BUCKET.head.mockResolvedValue(null);

      // Mock analytics summary with high error rate
      const mockSummary = [{
        hour: '2024-12-20-10',
        videoMetadata: {
          totalRequests: 100,
          cacheHits: 50,
          avgResponseTime: 1500
        },
        errors: {
          '/api/video': { '500': 10 }
        }
      }];

      // Mock the analytics service
      vi.spyOn(VideoAnalyticsService.prototype, 'getAnalyticsSummary')
        .mockResolvedValue(mockSummary);

      const response = await handler.handleHealthCheck(mockCtx as any);
      const data = await response.json();

      expect(data.status).toBe('degraded');
      expect(data.metrics.errorRate).toBe(0.1);
      expect(data.metrics.avgResponseTime).toBe(1500);
    });
  });

  describe('handlePopularVideos', () => {
    it('should return popular videos for valid time window', async () => {
      const mockRequest = new Request('http://localhost/api/analytics/popular?window=24h', {
        headers: { 'Authorization': 'Bearer test-token' }
      });

      // Mock current timestamp to ensure videos are within window
      const currentTime = Date.now();
      const recentTimestamp = currentTime - (12 * 60 * 60 * 1000); // 12 hours ago

      // Mock KV list response
      mockEnv.VIDEO_METADATA.list.mockResolvedValue({
        keys: [
          { name: `analytics:video:abc123:${recentTimestamp}` },
          { name: `analytics:video:def456:${recentTimestamp}` }
        ],
        list_complete: true
      });

      // Mock individual video data
      mockEnv.VIDEO_METADATA.get
        .mockResolvedValueOnce({
          videoId: 'abc123',
          responseTime: 200,
          cacheHit: true,
          timestamp: recentTimestamp
        })
        .mockResolvedValueOnce({
          videoId: 'def456',
          responseTime: 300,
          cacheHit: false,
          timestamp: recentTimestamp
        });

      const response = await handler.handlePopularVideos(mockRequest, mockCtx as any);
      const data = await response.json();

      expect(response.status).toBe(200);
      expect(data.window).toBe('24h');
      expect(data.videos).toHaveLength(2);
      expect(data.videos[0].videoId).toBe('abc123');
    });

    it('should reject requests without authentication', async () => {
      const mockRequest = new Request('http://localhost/api/analytics/popular');

      const response = await handler.handlePopularVideos(mockRequest, mockCtx as any);
      
      expect(response.status).toBe(401);
    });

    it('should validate time window parameter', async () => {
      const mockRequest = new Request('http://localhost/api/analytics/popular?window=invalid', {
        headers: { 'Authorization': 'Bearer test-token' }
      });

      const response = await handler.handlePopularVideos(mockRequest, mockCtx as any);
      
      expect(response.status).toBe(400);
    });
  });

  describe('handleDashboard', () => {
    it('should return comprehensive dashboard data', async () => {
      const mockRequest = new Request('http://localhost/api/analytics/dashboard', {
        headers: { 'Authorization': 'Bearer test-token' }
      });

      // Mock service health checks
      mockEnv.VIDEO_METADATA.get.mockResolvedValue(null);
      mockEnv.VIDEO_BUCKET.head.mockResolvedValue(null);

      // Mock analytics summary
      const mockSummary = [{
        hour: '2024-12-20-10',
        videoMetadata: {
          totalRequests: 100,
          cacheHits: 80,
          avgResponseTime: 200
        },
        batchVideo: {
          totalRequests: 10,
          totalVideosRequested: 50,
          totalVideosFound: 45
        },
        errors: {}
      }];

      vi.spyOn(VideoAnalyticsService.prototype, 'getAnalyticsSummary')
        .mockResolvedValue(mockSummary);

      // Mock KV list for popular videos
      mockEnv.VIDEO_METADATA.list.mockResolvedValue({
        keys: [],
        list_complete: true
      });

      const response = await handler.handleDashboard(mockRequest, mockCtx as any);
      const data = await response.json();

      expect(response.status).toBe(200);
      expect(data.data.health).toBeDefined();
      expect(data.data.performance).toBeDefined();
      expect(data.data.popularVideos).toBeDefined();
      expect(data.data.errors).toBeDefined();
      expect(data.data.cache).toBeDefined();
    });
  });

  describe('validateAuth', () => {
    it('should accept valid Bearer token', () => {
      const request = new Request('http://localhost/', {
        headers: { 'Authorization': 'Bearer valid-token' }
      });

      expect(handler.validateAuth(request)).toBe(true);
    });

    it('should reject missing Authorization header', () => {
      const request = new Request('http://localhost/');

      expect(handler.validateAuth(request)).toBe(false);
    });

    it('should reject invalid Authorization format', () => {
      const request = new Request('http://localhost/', {
        headers: { 'Authorization': 'Basic username:password' }
      });

      expect(handler.validateAuth(request)).toBe(false);
    });
  });
});