// ABOUTME: Unit tests for view tracking handler - validates core view counting logic
// ABOUTME: Tests rate limiting, data validation, and KV storage operations

import { describe, it, expect, beforeEach, vi } from 'vitest';
import { handleViewTracking } from '../../src/handlers/viewTracking';
import { AnalyticsEnv } from '../../src/types/analytics';

// Mock environment
const mockKV = {
  get: vi.fn(),
  put: vi.fn(),
  delete: vi.fn(),
  list: vi.fn()
};

const mockEnv: AnalyticsEnv = {
  ANALYTICS_KV: mockKV as any,
  ENVIRONMENT: 'test',
  TRENDING_UPDATE_INTERVAL: '300',
  MIN_VIEWS_FOR_TRENDING: '10'
};

describe('View Tracking Handler', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('should track a new video view', async () => {
    // Arrange
    const request = new Request('https://test.com/analytics/view', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        eventId: '22e73ca1faedb07dd3e24c1dca52d849aa75c6e4090eb60c532820b782c93da3',
        source: 'web',
        creatorPubkey: 'ae73ca1faedb07dd3e24c1dca52d849aa75c6e4090eb60c532820b782c93da3'
      })
    });

    mockKV.get.mockResolvedValue(null); // No existing views or rate limit

    // Act
    const response = await handleViewTracking(request, mockEnv);
    const result = await response.json();

    // Assert
    expect(response.status).toBe(200);
    expect(result.success).toBe(true);
    expect(result.eventId).toBe('22e73ca1faedb07dd3e24c1dca52d849aa75c6e4090eb60c532820b782c93da3');
    expect(result.views).toBe(1);
    
    // Check that views were incremented (not the specific call order)
    const putCalls = mockKV.put.mock.calls;
    const viewsCall = putCalls.find(call => call[0].startsWith('views:'));
    expect(viewsCall).toBeDefined();
    expect(viewsCall[1]).toContain('"count":1');
  });

  it('should increment existing video views', async () => {
    // Arrange
    const eventId = '22e73ca1faedb07dd3e24c1dca52d849aa75c6e4090eb60c532820b782c93da3';
    const request = new Request('https://test.com/analytics/view', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        eventId,
        source: 'mobile'
      })
    });

    const existingData = { count: 5, lastUpdate: Date.now() };
    mockKV.get.mockImplementation((key) => {
      if (key.startsWith('views:')) {
        return Promise.resolve(JSON.stringify(existingData));
      }
      return Promise.resolve(null); // No rate limit
    });

    // Act
    const response = await handleViewTracking(request, mockEnv);
    const result = await response.json();

    // Assert
    expect(response.status).toBe(200);
    expect(result.success).toBe(true);
    expect(result.views).toBe(6);
    expect(mockKV.put).toHaveBeenCalledWith(
      `views:${eventId}`,
      expect.stringContaining('"count":6'),
      undefined
    );
  });

  it('should reject invalid event IDs', async () => {
    // Arrange
    const request = new Request('https://test.com/analytics/view', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        eventId: 'invalid-id',
        source: 'web'
      })
    });

    // Act
    const response = await handleViewTracking(request, mockEnv);
    const result = await response.json();

    // Assert
    expect(response.status).toBe(400);
    expect(result.error).toBe('Invalid event ID');
  });

  it('should allow up to 100 views per minute from the same IP', async () => {
    // Arrange
    const eventId = '22e73ca1faedb07dd3e24c1dca52d849aa75c6e4090eb60c532820b782c93da3';
    const request = new Request('https://test.com/analytics/view', {
      method: 'POST',
      headers: { 
        'Content-Type': 'application/json',
        'CF-Connecting-IP': '192.168.1.1'
      },
      body: JSON.stringify({
        eventId,
        source: 'web'
      })
    });

    // Mock rate limit data showing 99 views already
    const rateLimitData = { 
      count: 99,
      windowStart: Date.now() - 30000 // 30 seconds ago
    };
    
    mockKV.get.mockImplementation((key) => {
      if (key.startsWith('rate:')) {
        return Promise.resolve(JSON.stringify(rateLimitData));
      }
      return Promise.resolve(null);
    });
    
    // Act - 100th view should succeed
    const response = await handleViewTracking(request, mockEnv);
    
    // Assert
    expect(response.status).toBe(200);
    const result = await response.json();
    expect(result.success).toBe(true);
  });

  it('should reject after 100 views per minute from the same IP', async () => {
    // Arrange
    const eventId = '22e73ca1faedb07dd3e24c1dca52d849aa75c6e4090eb60c532820b782c93da3';
    const request = new Request('https://test.com/analytics/view', {
      method: 'POST',
      headers: { 
        'Content-Type': 'application/json',
        'CF-Connecting-IP': '192.168.1.1'
      },
      body: JSON.stringify({
        eventId,
        source: 'web'
      })
    });

    // Mock rate limit data showing 100 views already
    const rateLimitData = { 
      count: 100,
      windowStart: Date.now() - 30000 // 30 seconds ago
    };
    
    mockKV.get.mockImplementation((key) => {
      if (key.startsWith('rate:')) {
        return Promise.resolve(JSON.stringify(rateLimitData));
      }
      return Promise.resolve(null);
    });
    
    // Act - 101st view should fail
    const response = await handleViewTracking(request, mockEnv);
    
    // Assert
    expect(response.status).toBe(429);
    const result = await response.json();
    expect(result.error).toBe('Rate limit exceeded');
  });

  it('should reset rate limit window after 1 minute', async () => {
    // Arrange
    const eventId = '22e73ca1faedb07dd3e24c1dca52d849aa75c6e4090eb60c532820b782c93da3';
    const request = new Request('https://test.com/analytics/view', {
      method: 'POST',
      headers: { 
        'Content-Type': 'application/json',
        'CF-Connecting-IP': '192.168.1.1'
      },
      body: JSON.stringify({
        eventId,
        source: 'web'
      })
    });

    // Mock rate limit data showing 100 views from over 1 minute ago
    const rateLimitData = { 
      count: 100,
      windowStart: Date.now() - 65000 // 65 seconds ago
    };
    
    mockKV.get.mockImplementation((key) => {
      if (key.startsWith('rate:')) {
        return Promise.resolve(JSON.stringify(rateLimitData));
      }
      return Promise.resolve(null);
    });
    
    // Act - Should reset window and allow the view
    const response = await handleViewTracking(request, mockEnv);
    
    // Assert
    expect(response.status).toBe(200);
    const result = await response.json();
    expect(result.success).toBe(true);
    
    // Verify rate limit was reset
    expect(mockKV.put).toHaveBeenCalledWith(
      expect.stringMatching(/^rate:/),
      expect.stringContaining('"count":1'),
      expect.objectContaining({ expirationTtl: 120 })
    );
  });

  it('should update creator metrics when creatorPubkey is provided', async () => {
    // Arrange
    const eventId = '22e73ca1faedb07dd3e24c1dca52d849aa75c6e4090eb60c532820b782c93da3';
    const creatorPubkey = 'ae73ca1faedb07dd3e24c1dca52d849aa75c6e4090eb60c532820b782c93da3';
    const request = new Request('https://test.com/analytics/view', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        eventId,
        source: 'web',
        creatorPubkey
      })
    });

    mockKV.get.mockResolvedValue(null); // No existing data

    // Act
    const response = await handleViewTracking(request, mockEnv);

    // Assert
    expect(response.status).toBe(200);
    
    // Verify creator metrics were updated
    expect(mockKV.put).toHaveBeenCalledWith(
      `creator:${creatorPubkey}`,
      expect.stringContaining('"totalViews":1'),
      undefined
    );
    
    // Verify creator video list was updated
    expect(mockKV.put).toHaveBeenCalledWith(
      `creator-videos:${creatorPubkey}`,
      expect.stringContaining(eventId),
      undefined
    );
  });
});