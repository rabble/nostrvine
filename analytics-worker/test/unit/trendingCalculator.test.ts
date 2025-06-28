// ABOUTME: Unit tests for trending calculation algorithm - validates scoring and ranking logic
// ABOUTME: Tests time decay, minimum thresholds, and edge cases for trending content

import { describe, it, expect, beforeEach } from 'vitest';
import { calculateTrendingScore, getTrendingVideos } from '../../src/services/trendingCalculator';

describe('Trending Calculator', () => {
  describe('calculateTrendingScore', () => {
    it('should calculate score with time decay', () => {
      const now = Date.now();
      const oneHourAgo = now - (60 * 60 * 1000);
      
      const viewData = {
        count: 100,
        lastUpdate: oneHourAgo
      };

      const score = calculateTrendingScore(viewData, now);
      
      // Score should be views divided by (hours + 1)
      // 100 views / (1 hour + 1) = 50
      expect(score).toBe(50);
    });

    it('should handle very recent content', () => {
      const now = Date.now();
      const viewData = {
        count: 50,
        lastUpdate: now - 30000 // 30 seconds ago
      };

      const score = calculateTrendingScore(viewData, now);
      
      // Score should be views divided by (0.008 hours + 1) ≈ 49.6
      expect(score).toBeCloseTo(49.6, 1);
    });

    it('should handle old content with low scores', () => {
      const now = Date.now();
      const oneDayAgo = now - (24 * 60 * 60 * 1000);
      
      const viewData = {
        count: 100,
        lastUpdate: oneDayAgo
      };

      const score = calculateTrendingScore(viewData, now);
      
      // 100 views / (24 hours + 1) = 4
      expect(score).toBe(4);
    });

    it('should return 0 for zero views', () => {
      const viewData = {
        count: 0,
        lastUpdate: Date.now()
      };

      const score = calculateTrendingScore(viewData, Date.now());
      expect(score).toBe(0);
    });
  });

  describe('getTrendingVideos', () => {
    const mockKV = {
      list: vi.fn(),
      get: vi.fn(),
    };

    beforeEach(() => {
      vi.clearAllMocks();
    });

    it('should return trending videos sorted by score', async () => {
      // Mock KV list response
      mockKV.list.mockResolvedValue({
        keys: [
          { name: 'view:event1' },
          { name: 'view:event2' },
          { name: 'view:event3' },
        ]
      });

      // Mock view data for each event
      const now = Date.now();
      const oneHourAgo = now - (60 * 60 * 1000);
      const twoHoursAgo = now - (2 * 60 * 60 * 1000);

      mockKV.get
        .mockResolvedValueOnce(JSON.stringify({ count: 100, lastUpdate: oneHourAgo }))   // Score: 50
        .mockResolvedValueOnce(JSON.stringify({ count: 150, lastUpdate: twoHoursAgo }))  // Score: 50
        .mockResolvedValueOnce(JSON.stringify({ count: 200, lastUpdate: now }));         // Score: 200

      // Act
      const result = await getTrendingVideos(mockKV, 10, 10);

      // Assert
      expect(result.videos).toHaveLength(3);
      expect(result.videos[0].eventId).toBe('event3'); // Highest score
      expect(result.videos[0].score).toBe(200);
      expect(result.videos[1].score).toBe(50); // Could be either event1 or event2
      expect(result.algorithm).toBe('global_popularity');
    });

    it('should filter out videos below minimum view threshold', async () => {
      mockKV.list.mockResolvedValue({
        keys: [
          { name: 'view:event1' },
          { name: 'view:event2' },
        ]
      });

      mockKV.get
        .mockResolvedValueOnce(JSON.stringify({ count: 5, lastUpdate: Date.now() }))   // Below threshold
        .mockResolvedValueOnce(JSON.stringify({ count: 15, lastUpdate: Date.now() })); // Above threshold

      const result = await getTrendingVideos(mockKV, 10, 10);

      expect(result.videos).toHaveLength(1);
      expect(result.videos[0].eventId).toBe('event2');
    });

    it('should respect the limit parameter', async () => {
      mockKV.list.mockResolvedValue({
        keys: Array.from({ length: 20 }, (_, i) => ({ name: `view:event${i}` }))
      });

      // Mock all with same high view count
      mockKV.get.mockImplementation(() => 
        Promise.resolve(JSON.stringify({ count: 100, lastUpdate: Date.now() }))
      );

      const result = await getTrendingVideos(mockKV, 5, 10);

      expect(result.videos).toHaveLength(5);
    });

    it('should handle empty results gracefully', async () => {
      mockKV.list.mockResolvedValue({ keys: [] });

      const result = await getTrendingVideos(mockKV, 10, 10);

      expect(result.videos).toHaveLength(0);
      expect(result.algorithm).toBe('global_popularity');
      expect(result.updatedAt).toBeTypeOf('number');
    });

    it('should handle malformed view data', async () => {
      mockKV.list.mockResolvedValue({
        keys: [
          { name: 'view:event1' },
          { name: 'view:event2' },
        ]
      });

      mockKV.get
        .mockResolvedValueOnce('invalid json')                                        // Malformed
        .mockResolvedValueOnce(JSON.stringify({ count: 50, lastUpdate: Date.now() })); // Valid

      const result = await getTrendingVideos(mockKV, 10, 10);

      // Should only include the valid entry
      expect(result.videos).toHaveLength(1);
      expect(result.videos[0].eventId).toBe('event2');
    });
  });
});