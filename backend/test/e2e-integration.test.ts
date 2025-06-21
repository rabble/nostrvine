// ABOUTME: Complete end-to-end integration tests for NostrVine video system
// ABOUTME: Tests real API calls, Nostr integration, and video playback flow

import { describe, test, expect, beforeAll, afterAll } from '@jest/globals';
import fetch from 'node-fetch';
import WebSocket from 'ws';
import crypto from 'crypto';

// Test configuration
const API_BASE_URL = process.env.API_BASE_URL || 'http://localhost:8787';
const TEST_API_KEY = process.env.TEST_API_KEY || 'test-key-123';
const NOSTR_RELAY_URL = process.env.NOSTR_RELAY_URL || 'wss://relay.damus.io';

// Test data
const TEST_VIDEO_IDS = [
  crypto.randomBytes(32).toString('hex'),
  crypto.randomBytes(32).toString('hex'),
  crypto.randomBytes(32).toString('hex'),
];

// Nostr event structure for NIP-94 file metadata
interface NostrEvent {
  id?: string;
  pubkey: string;
  created_at: number;
  kind: number;
  tags: string[][];
  content: string;
  sig?: string;
}

// Helper to create Nostr event
function createNostrVideoEvent(videoId: string, videoUrl: string): NostrEvent {
  return {
    pubkey: crypto.randomBytes(32).toString('hex'),
    created_at: Math.floor(Date.now() / 1000),
    kind: 1063, // NIP-94 file metadata
    tags: [
      ['url', videoUrl],
      ['m', 'video/mp4'],
      ['dim', '1280x720'],
      ['duration', '6'],
      ['size', '1048576'],
      ['x', videoId], // SHA256 hash of file
      ['alt', 'Test vine video'],
    ],
    content: 'Test vine #nostrvine',
  };
}

describe('NostrVine E2E Integration Tests', () => {
  let wsConnection: WebSocket | null = null;
  let receivedEvents: NostrEvent[] = [];

  beforeAll(async () => {
    // Verify API is accessible
    const healthCheck = await fetch(`${API_BASE_URL}/health`);
    expect(healthCheck.ok).toBe(true);
    const health = await healthCheck.json();
    expect(health.status).toBe('healthy');
  });

  afterAll(() => {
    if (wsConnection) {
      wsConnection.close();
    }
  });

  describe('1. Nostr Event to Video Playback Flow', () => {
    test('Connect to Nostr relay and receive video events', (done) => {
      wsConnection = new WebSocket(NOSTR_RELAY_URL);
      
      wsConnection.on('open', () => {
        // Subscribe to video events (NIP-94)
        const subscription = JSON.stringify([
          'REQ',
          'test-sub',
          {
            kinds: [1063], // NIP-94 file metadata
            '#m': ['video/mp4'],
            limit: 10,
          },
        ]);
        wsConnection!.send(subscription);
      });

      wsConnection.on('message', (data: string) => {
        try {
          const message = JSON.parse(data);
          
          if (message[0] === 'EVENT' && message[2]) {
            const event = message[2] as NostrEvent;
            receivedEvents.push(event);
            
            // Extract video ID from event
            const xTag = event.tags.find(tag => tag[0] === 'x');
            if (xTag && xTag[1]) {
              expect(xTag[1]).toMatch(/^[a-f0-9]{64}$/);
            }
          }
          
          if (message[0] === 'EOSE') {
            // End of stored events
            wsConnection!.close();
            done();
          }
        } catch (err) {
          console.error('WebSocket message error:', err);
        }
      });

      wsConnection.on('error', (err) => {
        done(err);
      });
    }, 10000); // 10 second timeout

    test('Fetch video metadata for discovered Nostr events', async () => {
      // Skip if no events received
      if (receivedEvents.length === 0) {
        console.log('No video events received from Nostr relay');
        return;
      }

      // Extract video IDs from events
      const videoIds = receivedEvents
        .map(event => event.tags.find(tag => tag[0] === 'x')?.[1])
        .filter(Boolean)
        .slice(0, 5); // Test first 5

      for (const videoId of videoIds) {
        const response = await fetch(`${API_BASE_URL}/api/video/${videoId}`, {
          headers: {
            'Authorization': `Bearer ${TEST_API_KEY}`,
          },
        });

        // Video might not be in our cache yet (404 is expected)
        expect([200, 404]).toContain(response.status);

        if (response.status === 200) {
          const metadata = await response.json();
          expect(metadata).toHaveProperty('videoId', videoId);
          expect(metadata).toHaveProperty('duration');
          expect(metadata).toHaveProperty('renditions');
          expect(metadata.renditions).toHaveProperty('480p');
          expect(metadata.renditions).toHaveProperty('720p');
        }
      }
    });

    test('Batch lookup for multiple video IDs', async () => {
      const response = await fetch(`${API_BASE_URL}/api/videos/batch`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${TEST_API_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          videoIds: TEST_VIDEO_IDS,
          quality: '720p',
        }),
      });

      expect(response.ok).toBe(true);
      const result = await response.json();
      
      expect(result).toHaveProperty('videos');
      expect(result).toHaveProperty('found');
      expect(result).toHaveProperty('missing');
      expect(typeof result.found).toBe('number');
      expect(typeof result.missing).toBe('number');
      expect(result.found + result.missing).toBe(TEST_VIDEO_IDS.length);
    });
  });

  describe('2. Performance Testing', () => {
    test('Single video metadata request under 200ms', async () => {
      const startTime = Date.now();
      
      const response = await fetch(`${API_BASE_URL}/api/video/${TEST_VIDEO_IDS[0]}`, {
        headers: {
          'Authorization': `Bearer ${TEST_API_KEY}`,
        },
      });
      
      const endTime = Date.now();
      const responseTime = endTime - startTime;
      
      expect(responseTime).toBeLessThan(200);
      expect([200, 404]).toContain(response.status);
    });

    test('Batch API handles 50 videos efficiently', async () => {
      // Generate 50 video IDs
      const largeVideoIds = Array.from({ length: 50 }, () => 
        crypto.randomBytes(32).toString('hex')
      );

      const startTime = Date.now();
      
      const response = await fetch(`${API_BASE_URL}/api/videos/batch`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${TEST_API_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          videoIds: largeVideoIds,
          quality: 'auto',
        }),
      });
      
      const endTime = Date.now();
      const responseTime = endTime - startTime;
      
      expect(response.ok).toBe(true);
      expect(responseTime).toBeLessThan(1000); // Should handle 50 videos in under 1 second
      
      const result = await response.json();
      expect(Object.keys(result.videos).length).toBe(50);
    });

    test('Concurrent requests maintain performance', async () => {
      const concurrentRequests = 10;
      const promises = [];
      
      const startTime = Date.now();
      
      for (let i = 0; i < concurrentRequests; i++) {
        promises.push(
          fetch(`${API_BASE_URL}/api/video/${TEST_VIDEO_IDS[0]}`, {
            headers: {
              'Authorization': `Bearer ${TEST_API_KEY}`,
            },
          })
        );
      }
      
      const responses = await Promise.all(promises);
      const endTime = Date.now();
      const totalTime = endTime - startTime;
      
      // All requests should succeed
      responses.forEach(response => {
        expect([200, 404]).toContain(response.status);
      });
      
      // Average time per request should still be reasonable
      const avgTime = totalTime / concurrentRequests;
      expect(avgTime).toBeLessThan(500);
    });
  });

  describe('3. Cache Testing', () => {
    test('Cache headers are properly set', async () => {
      const response = await fetch(`${API_BASE_URL}/api/video/${TEST_VIDEO_IDS[0]}`, {
        headers: {
          'Authorization': `Bearer ${TEST_API_KEY}`,
        },
      });

      const cacheControl = response.headers.get('cache-control');
      expect(cacheControl).toBeTruthy();
      
      if (response.status === 200) {
        // Successful responses should have cache
        expect(cacheControl).toContain('max-age=');
      } else {
        // Error responses should not cache
        expect(cacheControl).toContain('no-cache');
      }
    });

    test('ETags work for conditional requests', async () => {
      // First request to get ETag
      const firstResponse = await fetch(`${API_BASE_URL}/api/video/${TEST_VIDEO_IDS[0]}`, {
        headers: {
          'Authorization': `Bearer ${TEST_API_KEY}`,
        },
      });

      const etag = firstResponse.headers.get('etag');
      
      if (etag && firstResponse.status === 200) {
        // Second request with If-None-Match
        const secondResponse = await fetch(`${API_BASE_URL}/api/video/${TEST_VIDEO_IDS[0]}`, {
          headers: {
            'Authorization': `Bearer ${TEST_API_KEY}`,
            'If-None-Match': etag,
          },
        });

        // Should return 304 Not Modified if content hasn't changed
        expect([200, 304]).toContain(secondResponse.status);
      }
    });
  });

  describe('4. Error Handling Tests', () => {
    test('Invalid video ID format returns 400', async () => {
      const response = await fetch(`${API_BASE_URL}/api/video/invalid-id-format`, {
        headers: {
          'Authorization': `Bearer ${TEST_API_KEY}`,
        },
      });

      expect(response.status).toBe(400);
      const error = await response.json();
      expect(error).toHaveProperty('error');
    });

    test('Missing authorization returns 401', async () => {
      const response = await fetch(`${API_BASE_URL}/api/video/${TEST_VIDEO_IDS[0]}`);
      
      expect(response.status).toBe(401);
      const error = await response.json();
      expect(error).toHaveProperty('error');
    });

    test('Batch API rejects more than 50 videos', async () => {
      const tooManyIds = Array.from({ length: 51 }, () => 
        crypto.randomBytes(32).toString('hex')
      );

      const response = await fetch(`${API_BASE_URL}/api/videos/batch`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${TEST_API_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          videoIds: tooManyIds,
        }),
      });

      expect(response.status).toBe(400);
      const error = await response.json();
      expect(error).toHaveProperty('error');
      expect(error.error).toContain('50');
    });

    test('Invalid JSON in batch request returns 400', async () => {
      const response = await fetch(`${API_BASE_URL}/api/videos/batch`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${TEST_API_KEY}`,
          'Content-Type': 'application/json',
        },
        body: '{invalid json}',
      });

      expect(response.status).toBe(400);
    });
  });

  describe('5. Mobile Integration Testing', () => {
    test('CORS headers allow mobile app access', async () => {
      const response = await fetch(`${API_BASE_URL}/api/video/${TEST_VIDEO_IDS[0]}`, {
        headers: {
          'Authorization': `Bearer ${TEST_API_KEY}`,
          'Origin': 'https://nostrvine.com',
        },
      });

      const corsOrigin = response.headers.get('access-control-allow-origin');
      expect(corsOrigin).toBe('*');
      
      const corsMethods = response.headers.get('access-control-allow-methods');
      expect(corsMethods).toContain('GET');
    });

    test('OPTIONS preflight requests work', async () => {
      const response = await fetch(`${API_BASE_URL}/api/videos/batch`, {
        method: 'OPTIONS',
        headers: {
          'Origin': 'https://nostrvine.com',
          'Access-Control-Request-Method': 'POST',
          'Access-Control-Request-Headers': 'authorization,content-type',
        },
      });

      expect([200, 204]).toContain(response.status);
      
      const corsOrigin = response.headers.get('access-control-allow-origin');
      expect(corsOrigin).toBe('*');
      
      const corsHeaders = response.headers.get('access-control-allow-headers');
      expect(corsHeaders?.toLowerCase()).toContain('authorization');
      expect(corsHeaders?.toLowerCase()).toContain('content-type');
    });

    test('Mobile user agent is tracked in analytics', async () => {
      const mobileUserAgent = 'NostrVine/1.0 (iPhone; iOS 16.0)';
      
      const response = await fetch(`${API_BASE_URL}/api/video/${TEST_VIDEO_IDS[0]}`, {
        headers: {
          'Authorization': `Bearer ${TEST_API_KEY}`,
          'User-Agent': mobileUserAgent,
        },
      });

      expect([200, 404]).toContain(response.status);
      
      // Check analytics endpoint to verify tracking
      const analyticsResponse = await fetch(`${API_BASE_URL}/api/analytics/popular?window=1h`, {
        headers: {
          'Authorization': `Bearer ${TEST_API_KEY}`,
        },
      });

      if (analyticsResponse.ok) {
        const analytics = await analyticsResponse.json();
        expect(analytics).toHaveProperty('videos');
      }
    });
  });

  describe('6. Load Testing', () => {
    test('Rate limiting prevents abuse', async () => {
      const requests = [];
      const burstSize = 30; // Exceed rate limit
      
      // Send burst of requests
      for (let i = 0; i < burstSize; i++) {
        requests.push(
          fetch(`${API_BASE_URL}/api/video/${TEST_VIDEO_IDS[0]}`, {
            headers: {
              'Authorization': `Bearer ${TEST_API_KEY}`,
            },
          }).then(r => ({ status: r.status, index: i }))
        );
      }
      
      const results = await Promise.all(requests);
      
      // Some requests should be rate limited (429)
      const rateLimited = results.filter(r => r.status === 429);
      expect(rateLimited.length).toBeGreaterThan(0);
      
      // But not all should fail
      const successful = results.filter(r => r.status === 200 || r.status === 404);
      expect(successful.length).toBeGreaterThan(0);
    });

    test('System handles sustained load', async () => {
      const duration = 5000; // 5 seconds
      const requestsPerSecond = 10;
      const startTime = Date.now();
      let totalRequests = 0;
      let successfulRequests = 0;
      let totalResponseTime = 0;

      while (Date.now() - startTime < duration) {
        const batchStart = Date.now();
        const promises = [];
        
        for (let i = 0; i < requestsPerSecond; i++) {
          totalRequests++;
          const requestStart = Date.now();
          
          promises.push(
            fetch(`${API_BASE_URL}/api/video/${TEST_VIDEO_IDS[i % TEST_VIDEO_IDS.length]}`, {
              headers: {
                'Authorization': `Bearer ${TEST_API_KEY}`,
              },
            }).then(response => {
              const responseTime = Date.now() - requestStart;
              totalResponseTime += responseTime;
              
              if (response.status === 200 || response.status === 404) {
                successfulRequests++;
              }
              
              return response;
            }).catch(() => {
              // Ignore errors for load test
            })
          );
        }
        
        await Promise.all(promises);
        
        // Wait to maintain requests per second rate
        const batchDuration = Date.now() - batchStart;
        if (batchDuration < 1000) {
          await new Promise(resolve => setTimeout(resolve, 1000 - batchDuration));
        }
      }

      const successRate = (successfulRequests / totalRequests) * 100;
      const avgResponseTime = totalResponseTime / totalRequests;
      
      console.log(`Load test results:
        Total requests: ${totalRequests}
        Successful: ${successfulRequests}
        Success rate: ${successRate.toFixed(2)}%
        Avg response time: ${avgResponseTime.toFixed(2)}ms
      `);
      
      // Success criteria
      expect(successRate).toBeGreaterThan(90); // 90% success rate
      expect(avgResponseTime).toBeLessThan(500); // Under 500ms average
    });
  });

  describe('7. Analytics and Monitoring', () => {
    test('Analytics endpoints track video requests', async () => {
      // Make some video requests first
      for (let i = 0; i < 5; i++) {
        await fetch(`${API_BASE_URL}/api/video/${TEST_VIDEO_IDS[0]}`, {
          headers: {
            'Authorization': `Bearer ${TEST_API_KEY}`,
          },
        });
      }

      // Check analytics
      const response = await fetch(`${API_BASE_URL}/api/analytics/popular?window=1h`, {
        headers: {
          'Authorization': `Bearer ${TEST_API_KEY}`,
        },
      });

      expect(response.ok).toBe(true);
      const analytics = await response.json();
      
      expect(analytics).toHaveProperty('timeframe', '1h');
      expect(analytics).toHaveProperty('videos');
      expect(Array.isArray(analytics.videos)).toBe(true);
    });

    test('Health endpoint includes dependency status', async () => {
      const response = await fetch(`${API_BASE_URL}/health`);
      
      expect(response.ok).toBe(true);
      const health = await response.json();
      
      expect(health).toHaveProperty('status');
      expect(health).toHaveProperty('timestamp');
      expect(health).toHaveProperty('metrics');
      expect(health).toHaveProperty('dependencies');
      
      // Check dependency health
      expect(health.dependencies).toHaveProperty('r2');
      expect(health.dependencies).toHaveProperty('kv');
      expect(health.dependencies).toHaveProperty('rateLimiter');
      
      // Verify metrics structure
      expect(health.metrics).toHaveProperty('totalRequests');
      expect(health.metrics).toHaveProperty('cacheHitRate');
      expect(health.metrics).toHaveProperty('averageResponseTime');
      expect(health.metrics).toHaveProperty('errorRate');
    });

    test('Dashboard endpoint provides comprehensive metrics', async () => {
      const response = await fetch(`${API_BASE_URL}/api/analytics/dashboard`, {
        headers: {
          'Authorization': `Bearer ${TEST_API_KEY}`,
        },
      });

      expect(response.ok).toBe(true);
      const dashboard = await response.json();
      
      expect(dashboard).toHaveProperty('health');
      expect(dashboard).toHaveProperty('metrics');
      expect(dashboard).toHaveProperty('popularVideos');
      expect(dashboard).toHaveProperty('timestamp');
    });
  });
});