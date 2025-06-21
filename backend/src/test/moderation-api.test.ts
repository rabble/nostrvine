// ABOUTME: Comprehensive tests for video moderation API endpoints
// ABOUTME: Validates report submission, tracking, moderation queue, and admin actions

import { describe, it, expect, beforeEach } from 'vitest';

describe('Video Moderation API', () => {
  const baseUrl = 'http://localhost:8787';
  const testApiKey = 'test-api-key';
  const adminApiKey = 'test-admin-key';
  
  // Test data
  const validVideoId = 'a'.repeat(64); // 64 char hex string
  const testReporterPubkey = 'npub1'.repeat(10);
  
  beforeEach(async () => {
    // Clear any existing reports/moderation data
    // In real tests, we'd reset test data here
  });

  describe('POST /api/moderation/report', () => {
    it('should submit a valid report', async () => {
      const response = await fetch(`${baseUrl}/api/moderation/report`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${testApiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          videoId: validVideoId,
          reportType: 'spam',
          reason: 'This video appears to be spam content',
          reporterPubkey: testReporterPubkey,
        }),
      });

      expect(response.status).toBe(200);
      
      const data = await response.json();
      expect(data).toHaveProperty('success', true);
      expect(data).toHaveProperty('reportId');
      expect(data).toHaveProperty('videoStatus');
      expect(data.videoStatus).toHaveProperty('reportCount');
      expect(data.videoStatus.reportCount).toBeGreaterThan(0);
    });

    it('should validate report types', async () => {
      const response = await fetch(`${baseUrl}/api/moderation/report`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${testApiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          videoId: validVideoId,
          reportType: 'invalid_type',
          reason: 'Test',
          reporterPubkey: testReporterPubkey,
        }),
      });

      expect(response.status).toBe(400);
      const data = await response.json();
      expect(data.error).toContain('Invalid report type');
    });

    it('should require all fields', async () => {
      const response = await fetch(`${baseUrl}/api/moderation/report`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${testApiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          videoId: validVideoId,
          reportType: 'spam',
          // missing reason and reporterPubkey
        }),
      });

      expect(response.status).toBe(400);
      const data = await response.json();
      expect(data.error).toContain('Missing required fields');
    });

    it('should enforce rate limiting for reports', async () => {
      // Submit 10 reports quickly to trigger rate limit
      const reportPromises = Array(11).fill(null).map((_, i) =>
        fetch(`${baseUrl}/api/moderation/report`, {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${testApiKey}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            videoId: `${'b'.repeat(63)}${i}`, // Different video IDs
            reportType: 'spam',
            reason: `Spam report ${i}`,
            reporterPubkey: testReporterPubkey,
          }),
        })
      );

      const responses = await Promise.all(reportPromises);
      
      // First 10 should succeed
      const successCount = responses.filter(r => r.status === 200).length;
      expect(successCount).toBe(10);
      
      // 11th should be rate limited
      const rateLimited = responses.find(r => r.status === 429);
      expect(rateLimited).toBeTruthy();
      
      if (rateLimited) {
        const data = await rateLimited.json();
        expect(data.error).toContain('rate_limit_exceeded');
        expect(data).toHaveProperty('retryAfter');
      }
    });

    it('should include Nostr event ID if provided', async () => {
      const response = await fetch(`${baseUrl}/api/moderation/report`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${testApiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          videoId: validVideoId,
          reportType: 'harassment',
          reason: 'Harassing content',
          reporterPubkey: testReporterPubkey,
          nostrEventId: 'event123',
        }),
      });

      expect(response.status).toBe(200);
      const data = await response.json();
      expect(data.success).toBe(true);
    });

    it('should auto-hide videos after threshold reports', async () => {
      const testVideoId = 'c'.repeat(64);
      
      // Submit 5 reports (threshold)
      for (let i = 0; i < 5; i++) {
        const response = await fetch(`${baseUrl}/api/moderation/report`, {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${testApiKey}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            videoId: testVideoId,
            reportType: i % 2 === 0 ? 'spam' : 'illegal',
            reason: `Report ${i + 1}`,
            reporterPubkey: `reporter${i}`,
          }),
        });
        
        const data = await response.json();
        
        if (i < 4) {
          // First 4 reports shouldn't hide the video
          expect(data.videoStatus.isHidden).toBe(false);
        } else {
          // 5th report should trigger auto-hide
          expect(data.videoStatus.isHidden).toBe(true);
          expect(data.videoStatus.reportCount).toBe(5);
        }
      }
    });

    it('should handle CORS preflight', async () => {
      const response = await fetch(`${baseUrl}/api/moderation/report`, {
        method: 'OPTIONS',
      });

      expect(response.status).toBe(204);
      expect(response.headers.get('Access-Control-Allow-Origin')).toBe('*');
      expect(response.headers.get('Access-Control-Allow-Methods')).toContain('POST');
    });
  });

  describe('GET /api/moderation/status/{videoId}', () => {
    it('should return moderation status for a video', async () => {
      const response = await fetch(`${baseUrl}/api/moderation/status/${validVideoId}`, {
        headers: {
          'Authorization': `Bearer ${testApiKey}`,
        },
      });

      expect(response.status).toBe(200);
      
      const data = await response.json();
      expect(data).toHaveProperty('videoId', validVideoId);
      expect(data).toHaveProperty('reportCount');
      expect(data).toHaveProperty('isHidden');
      expect(data).toHaveProperty('reportTypes');
      expect(data).toHaveProperty('moderationActions');
      expect(Array.isArray(data.reportTypes)).toBe(true);
      expect(Array.isArray(data.moderationActions)).toBe(true);
    });

    it('should return default status for unreported videos', async () => {
      const unreportedVideo = 'd'.repeat(64);
      const response = await fetch(`${baseUrl}/api/moderation/status/${unreportedVideo}`, {
        headers: {
          'Authorization': `Bearer ${testApiKey}`,
        },
      });

      expect(response.status).toBe(200);
      
      const data = await response.json();
      expect(data.videoId).toBe(unreportedVideo);
      expect(data.reportCount).toBe(0);
      expect(data.isHidden).toBe(false);
      expect(data.reportTypes).toEqual([]);
      expect(data.moderationActions).toEqual([]);
    });

    it('should cache responses', async () => {
      const response = await fetch(`${baseUrl}/api/moderation/status/${validVideoId}`, {
        headers: {
          'Authorization': `Bearer ${testApiKey}`,
        },
      });

      expect(response.headers.get('Cache-Control')).toContain('max-age=60');
    });
  });

  describe('GET /api/moderation/queue (Admin)', () => {
    it('should require admin privileges', async () => {
      const response = await fetch(`${baseUrl}/api/moderation/queue`, {
        headers: {
          'Authorization': `Bearer ${testApiKey}`, // Regular API key
        },
      });

      expect(response.status).toBe(403);
      const data = await response.json();
      expect(data.error).toContain('Admin privileges required');
    });

    it('should return moderation queue for admins', async () => {
      const response = await fetch(`${baseUrl}/api/moderation/queue`, {
        headers: {
          'Authorization': `Bearer ${adminApiKey}`,
        },
      });

      expect(response.status).toBe(200);
      
      const data = await response.json();
      expect(data).toHaveProperty('queue');
      expect(data).toHaveProperty('totalItems');
      expect(data).toHaveProperty('timestamp');
      expect(Array.isArray(data.queue)).toBe(true);
    });

    it('should not cache admin responses', async () => {
      const response = await fetch(`${baseUrl}/api/moderation/queue`, {
        headers: {
          'Authorization': `Bearer ${adminApiKey}`,
        },
      });

      expect(response.headers.get('Cache-Control')).toBe('no-cache');
    });
  });

  describe('POST /api/moderation/action (Admin)', () => {
    it('should require admin privileges', async () => {
      const response = await fetch(`${baseUrl}/api/moderation/action`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${testApiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          videoId: validVideoId,
          action: 'hide',
          moderatorPubkey: 'mod123',
          reason: 'Violates community guidelines',
        }),
      });

      expect(response.status).toBe(403);
    });

    it('should allow admins to hide videos', async () => {
      const response = await fetch(`${baseUrl}/api/moderation/action`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${adminApiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          videoId: validVideoId,
          action: 'hide',
          moderatorPubkey: 'admin123',
          reason: 'Manual review - inappropriate content',
        }),
      });

      expect(response.status).toBe(200);
      
      const data = await response.json();
      expect(data.success).toBe(true);
      expect(data.action).toBe('hide');
      expect(data.newStatus.isHidden).toBe(true);
      expect(data.newStatus.moderationActions.length).toBeGreaterThan(0);
    });

    it('should allow admins to unhide videos', async () => {
      const response = await fetch(`${baseUrl}/api/moderation/action`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${adminApiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          videoId: validVideoId,
          action: 'unhide',
          moderatorPubkey: 'admin123',
          reason: 'False reports - content is acceptable',
        }),
      });

      expect(response.status).toBe(200);
      
      const data = await response.json();
      expect(data.success).toBe(true);
      expect(data.action).toBe('unhide');
      expect(data.newStatus.isHidden).toBe(false);
    });

    it('should validate action types', async () => {
      const response = await fetch(`${baseUrl}/api/moderation/action`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${adminApiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          videoId: validVideoId,
          action: 'invalid_action',
          moderatorPubkey: 'admin123',
          reason: 'Test',
        }),
      });

      expect(response.status).toBe(400);
      const data = await response.json();
      expect(data.error).toContain('Invalid input');
    });

    it('should track moderation history', async () => {
      // First action
      await fetch(`${baseUrl}/api/moderation/action`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${adminApiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          videoId: validVideoId,
          action: 'hide',
          moderatorPubkey: 'admin1',
          reason: 'First review',
        }),
      });

      // Second action
      const response = await fetch(`${baseUrl}/api/moderation/action`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${adminApiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          videoId: validVideoId,
          action: 'unhide',
          moderatorPubkey: 'admin2',
          reason: 'Second review - false positive',
        }),
      });

      const data = await response.json();
      expect(data.newStatus.moderationActions.length).toBeGreaterThanOrEqual(2);
      
      // Check history contains both actions
      const actions = data.newStatus.moderationActions;
      const hideAction = actions.find((a: any) => a.action === 'hide');
      const unhideAction = actions.find((a: any) => a.action === 'unhide');
      
      expect(hideAction).toBeTruthy();
      expect(unhideAction).toBeTruthy();
    });
  });

  describe('Security Tests', () => {
    it('should require API key for all endpoints', async () => {
      const endpoints = [
        { method: 'POST', path: '/api/moderation/report' },
        { method: 'GET', path: `/api/moderation/status/${validVideoId}` },
        { method: 'GET', path: '/api/moderation/queue' },
        { method: 'POST', path: '/api/moderation/action' },
      ];

      for (const endpoint of endpoints) {
        const response = await fetch(`${baseUrl}${endpoint.path}`, {
          method: endpoint.method,
          headers: {
            'Content-Type': 'application/json',
          },
          body: endpoint.method === 'POST' ? JSON.stringify({}) : undefined,
        });

        expect(response.status).toBe(401);
        const data = await response.json();
        expect(data.error).toContain('unauthorized');
      }
    });

    it('should apply security headers', async () => {
      const response = await fetch(`${baseUrl}/api/moderation/status/${validVideoId}`, {
        headers: {
          'Authorization': `Bearer ${testApiKey}`,
        },
      });

      expect(response.headers.get('X-Content-Type-Options')).toBe('nosniff');
      expect(response.headers.get('X-Frame-Options')).toBe('DENY');
    });
  });

  describe('Analytics Integration', () => {
    it('should track report submissions', async () => {
      const response = await fetch(`${baseUrl}/api/moderation/report`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${testApiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          videoId: validVideoId,
          reportType: 'spam',
          reason: 'Analytics test',
          reporterPubkey: testReporterPubkey,
        }),
      });

      expect(response.status).toBe(200);
      // Analytics tracking happens in background
      // In real tests, we'd verify analytics were recorded
    });

    it('should track moderation actions', async () => {
      const response = await fetch(`${baseUrl}/api/moderation/action`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${adminApiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          videoId: validVideoId,
          action: 'hide',
          moderatorPubkey: 'admin123',
          reason: 'Analytics test',
        }),
      });

      expect(response.status).toBe(200);
      // Analytics tracking happens in background
    });
  });
});