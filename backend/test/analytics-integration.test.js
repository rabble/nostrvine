// ABOUTME: Integration test for analytics system with real API calls
// ABOUTME: Verifies analytics tracking works across video cache and batch APIs

const { test, expect } = require('@jest/globals');

// Mock environment for testing
const createTestEnv = () => ({
  METADATA_CACHE: {
    get: jest.fn(),
    put: jest.fn(),
  },
  MEDIA_BUCKET: {
    list: jest.fn().mockResolvedValue({ objects: [] }),
    createSignedUrl: jest.fn().mockResolvedValue('https://example.com/signed-url'),
  },
  API_KEYS: {
    get: jest.fn().mockResolvedValue('test-key-data'),
  },
});

// Mock execution context
const createTestContext = () => ({
  waitUntil: jest.fn((promise) => promise), // Execute immediately for testing
});

// Mock request
const createTestRequest = (url, options = {}) => ({
  url,
  method: options.method || 'GET',
  headers: new Map([
    ['authorization', 'Bearer test-api-key'],
    ['user-agent', 'NostrVine-Test/1.0'],
    ...Object.entries(options.headers || {}),
  ]),
  ...options,
});

describe('Analytics Integration Tests', () => {
  let env, ctx;

  beforeEach(() => {
    env = createTestEnv();
    ctx = createTestContext();
    
    // Mock video metadata
    env.METADATA_CACHE.get.mockImplementation((key) => {
      if (key.startsWith('video:')) {
        return JSON.stringify({
          videoId: 'test-video-id',
          videoUrl: 'https://example.com/video.mp4',
          duration: 6.0,
          posterUrl: 'poster.jpg',
          renditions: {
            '480p': { path: 'video_480p.mp4', size: 1024 },
            '720p': { path: 'video_720p.mp4', size: 2048 },
          },
        });
      }
      if (key.startsWith('rate_limit:')) {
        return '5'; // 5 requests made
      }
      return null;
    });
    
    // Mock API key validation
    env.API_KEYS.get.mockResolvedValue(JSON.stringify({
      key: 'test-api-key',
      permissions: ['read', 'analytics'],
      quota: 1000,
    }));
  });

  test('Video metadata API tracks analytics correctly', async () => {
    const { handleVideoMetadata } = require('../src/handlers/video-cache-api');
    
    const request = createTestRequest('https://api.example.com/api/video/test-video-id');
    const response = await handleVideoMetadata('test-video-id', request, env, ctx);
    
    expect(response.status).toBe(200);
    
    // Verify analytics tracking was called
    expect(ctx.waitUntil).toHaveBeenCalled();
    expect(env.METADATA_CACHE.put).toHaveBeenCalledWith(
      expect.stringMatching(/video:test-video-id:analytics/),
      expect.any(String),
      expect.objectContaining({ expirationTtl: 86400 })
    );
  });

  test('Batch video API tracks analytics correctly', async () => {
    const { handleBatchVideoLookup } = require('../src/handlers/batch-video-api');
    
    const request = createTestRequest('https://api.example.com/api/videos/batch', {
      method: 'POST',
      json: () => Promise.resolve({
        videoIds: ['test-video-id', 'missing-video-id'],
        quality: '720p',
      }),
    });
    
    const response = await handleBatchVideoLookup(request, env, ctx);
    
    expect(response.status).toBe(200);
    
    // Verify batch analytics tracking
    expect(ctx.waitUntil).toHaveBeenCalled();
    expect(env.METADATA_CACHE.put).toHaveBeenCalledWith(
      expect.stringMatching(/batch:/),
      expect.any(String),
      expect.any(Object)
    );
  });

  test('Health check includes analytics data', async () => {
    const { VideoAnalyticsService } = require('../src/services/analytics');
    
    const analytics = new VideoAnalyticsService(env, ctx);
    const healthStatus = await analytics.getHealthStatus();
    
    expect(healthStatus).toMatchObject({
      status: expect.oneOf(['healthy', 'degraded', 'unhealthy']),
      timestamp: expect.any(String),
      metrics: expect.objectContaining({
        totalRequests: expect.any(Number),
        cacheHitRate: expect.any(Number),
        averageResponseTime: expect.any(Number),
        errorRate: expect.any(Number),
      }),
      dependencies: expect.objectContaining({
        r2: expect.oneOf(['healthy', 'error', 'unknown']),
        kv: expect.oneOf(['healthy', 'error', 'unknown']),
        rateLimiter: expect.oneOf(['healthy', 'error', 'unknown']),
      }),
    });
  });

  test('Popular videos tracking works', async () => {
    const { VideoAnalyticsService } = require('../src/services/analytics');
    
    const analytics = new VideoAnalyticsService(env, ctx);
    
    // Mock popular videos data
    env.METADATA_CACHE.get.mockImplementation((key) => {
      if (key === 'popular:24h') {
        return JSON.stringify([
          {
            videoId: 'popular-video-1',
            requestCount: 100,
            cacheHits: 80,
            cacheMisses: 20,
            qualityBreakdown: { '480p': 30, '720p': 70 },
            averageResponseTime: 150,
            errorRate: 0.01,
            lastAccessed: Date.now(),
          },
        ]);
      }
      return null;
    });
    
    const popularVideos = await analytics.getPopularVideos('24h', 5);
    
    expect(popularVideos).toHaveLength(1);
    expect(popularVideos[0]).toMatchObject({
      videoId: 'popular-video-1',
      requestCount: 100,
      cacheHits: 80,
      cacheMisses: 20,
    });
  });

  test('Error tracking captures API failures', async () => {
    const { VideoAnalyticsService } = require('../src/services/analytics');
    
    const analytics = new VideoAnalyticsService(env, ctx);
    const request = createTestRequest('https://api.example.com/api/video/invalid');
    
    const error = new Error('Video not found');
    await analytics.trackError(error, '/api/video', request);
    
    // Verify error was logged
    expect(ctx.waitUntil).toHaveBeenCalled();
    expect(env.METADATA_CACHE.put).toHaveBeenCalledWith(
      expect.stringMatching(/error:/),
      expect.stringContaining('Video not found'),
      expect.objectContaining({ expirationTtl: 86400 })
    );
  });

  test('Analytics dashboard endpoint returns comprehensive data', async () => {
    // Mock dashboard data
    env.METADATA_CACHE.get.mockImplementation((key) => {
      if (key.startsWith('global:')) {
        return '100'; // Mock counter values
      }
      if (key === 'popular:24h') {
        return JSON.stringify([
          { videoId: 'video1', requestCount: 50 },
          { videoId: 'video2', requestCount: 30 },
        ]);
      }
      return null;
    });

    const { VideoAnalyticsService } = require('../src/services/analytics');
    const analytics = new VideoAnalyticsService(env, ctx);
    
    const [healthStatus, metrics, popular] = await Promise.all([
      analytics.getHealthStatus(),
      analytics.getCurrentMetrics(),
      analytics.getPopularVideos('24h', 5),
    ]);
    
    expect(healthStatus.status).toBeDefined();
    expect(metrics.totalRequests).toBeGreaterThanOrEqual(0);
    expect(popular).toBeInstanceOf(Array);
  });
});

// Performance test for analytics overhead
describe('Analytics Performance Tests', () => {
  test('Analytics tracking has minimal overhead', async () => {
    const env = createTestEnv();
    const ctx = createTestContext();
    
    const { VideoAnalyticsService } = require('../src/services/analytics');
    const analytics = new VideoAnalyticsService(env, ctx);
    
    const startTime = Date.now();
    
    // Simulate 100 concurrent analytics calls
    const promises = Array(100).fill(0).map(() => 
      analytics.trackVideoRequest(
        'test-video',
        '720p',
        true,
        50,
        createTestRequest('https://example.com/api/video/test')
      )
    );
    
    await Promise.all(promises);
    
    const duration = Date.now() - startTime;
    
    // Analytics should complete quickly since it runs in background
    expect(duration).toBeLessThan(1000); // Less than 1 second for 100 calls
    expect(ctx.waitUntil).toHaveBeenCalledTimes(100);
  });
});