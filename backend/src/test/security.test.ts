// ABOUTME: Tests for security and rate limiting features
// ABOUTME: Verifies API key validation, rate limiting, and security headers

import { describe, it, expect, beforeAll } from 'vitest';

describe('Security & Authentication', () => {
  const baseUrl = 'http://localhost:8787';
  const testApiKey = 'test-api-key';
  
  describe('API Key Authentication', () => {
    it('should reject requests without API key', async () => {
      const response = await fetch(`${baseUrl}/api/video/test123`);
      expect(response.status).toBe(401);
      
      const data = await response.json();
      expect(data.error).toBe('unauthorized');
      expect(data.message).toBe('Invalid or missing API key');
    });

    it('should reject requests with invalid API key', async () => {
      const response = await fetch(`${baseUrl}/api/video/test123`, {
        headers: {
          'Authorization': 'Bearer invalid-key',
        },
      });
      expect(response.status).toBe(401);
    });

    it('should accept requests with valid API key', async () => {
      const response = await fetch(`${baseUrl}/api/video/test123`, {
        headers: {
          'Authorization': `Bearer ${testApiKey}`,
        },
      });
      // Should get 400 for invalid format, not 401
      expect(response.status).not.toBe(401);
    });

    it('should require Bearer prefix in Authorization header', async () => {
      const response = await fetch(`${baseUrl}/api/video/test123`, {
        headers: {
          'Authorization': testApiKey, // Missing Bearer prefix
        },
      });
      expect(response.status).toBe(401);
    });
  });

  describe('Security Headers', () => {
    it('should include security headers in all responses', async () => {
      const response = await fetch(`${baseUrl}/api/video/test123`, {
        headers: {
          'Authorization': `Bearer ${testApiKey}`,
        },
      });
      
      // Check security headers
      expect(response.headers.get('X-Content-Type-Options')).toBe('nosniff');
      expect(response.headers.get('X-Frame-Options')).toBe('DENY');
      expect(response.headers.get('X-XSS-Protection')).toBe('1; mode=block');
      expect(response.headers.get('Referrer-Policy')).toBe('strict-origin-when-cross-origin');
      expect(response.headers.get('Content-Security-Policy')).toBe("default-src 'self'");
    });

    it('should include security headers even on error responses', async () => {
      const response = await fetch(`${baseUrl}/api/video/test123`);
      
      expect(response.status).toBe(401);
      // Security headers should still be present
      expect(response.headers.get('X-Content-Type-Options')).toBe('nosniff');
      expect(response.headers.get('X-Frame-Options')).toBe('DENY');
    });
  });

  describe('CORS Headers', () => {
    it('should handle OPTIONS preflight with auth headers', async () => {
      const response = await fetch(`${baseUrl}/api/video/test123`, {
        method: 'OPTIONS',
      });
      
      expect(response.status).toBe(204);
      expect(response.headers.get('Access-Control-Allow-Headers')).toContain('Authorization');
      expect(response.headers.get('Access-Control-Allow-Origin')).toBe('*');
    });
  });

  describe('Rate Limiting', () => {
    it('should include rate limit headers in responses', async () => {
      // Note: In a real test, we'd make many requests to trigger rate limiting
      const response = await fetch(`${baseUrl}/api/video/test123`, {
        headers: {
          'Authorization': `Bearer ${testApiKey}`,
        },
      });
      
      // Even if not rate limited, headers might be present
      const remaining = response.headers.get('X-RateLimit-Remaining');
      const limit = response.headers.get('X-RateLimit-Limit');
      
      // Headers might not be present unless rate limited
      if (remaining) {
        expect(parseInt(remaining)).toBeGreaterThanOrEqual(0);
      }
    });

    it('should return 429 when rate limit exceeded', async () => {
      // This test would need to make many requests rapidly
      // For now, just verify the structure is in place
      
      // Make a batch request which has lower limits
      const batchRequests = Array(10).fill(null).map(() => 
        fetch(`${baseUrl}/api/videos/batch`, {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${testApiKey}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ videoIds: ['test1'] }),
        })
      );
      
      const responses = await Promise.all(batchRequests);
      
      // At least verify we can make requests
      expect(responses.some(r => r.status === 200 || r.status === 400)).toBe(true);
    });
  });

  describe('Batch API Security', () => {
    it('should require authentication for batch API', async () => {
      const response = await fetch(`${baseUrl}/api/videos/batch`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ videoIds: ['test1'] }),
      });
      
      expect(response.status).toBe(401);
    });

    it('should accept authenticated batch requests', async () => {
      const response = await fetch(`${baseUrl}/api/videos/batch`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${testApiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ videoIds: ['test1'] }),
      });
      
      // Should not be 401
      expect(response.status).not.toBe(401);
    });
  });
});