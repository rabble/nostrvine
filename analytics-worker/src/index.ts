// ABOUTME: Minimal analytics worker for OpenVine - tracks content popularity
// ABOUTME: Foundation for future opt-in personalization and algorithmic feeds

import { AnalyticsEnv } from './types/analytics';
import { handleViewTracking } from './handlers/viewTracking';
import { handleTrending, handleVideoStats } from './handlers/trending';
import { handleTrendingVines } from './handlers/trendingVines';
import { handleTrendingViners } from './handlers/trendingViners';
import { handleHashtagTrending } from './handlers/hashtagTrending';
import { handleVelocityTrending } from './handlers/velocityTrending';

export default {
  async fetch(
    request: Request,
    env: AnalyticsEnv,
    ctx: ExecutionContext
  ): Promise<Response> {
    const url = new URL(request.url);
    const path = url.pathname;

    // Handle CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, {
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type',
          'Access-Control-Max-Age': '86400',
        }
      });
    }

    // Route requests
    try {
      // POST /analytics/view - Track a video view
      if (path === '/analytics/view' && request.method === 'POST') {
        return handleViewTracking(request, env);
      }

      // GET /analytics/trending/videos - Get trending videos (legacy endpoint)
      if (path === '/analytics/trending/videos' && request.method === 'GET') {
        return handleTrending(request, env);
      }

      // GET /analytics/trending/vines - Get trending vines (videos)
      if (path === '/analytics/trending/vines' && request.method === 'GET') {
        return handleTrendingVines(request, env);
      }

      // GET /analytics/trending/viners - Get trending viners (creators)
      if (path === '/analytics/trending/viners' && request.method === 'GET') {
        return handleTrendingViners(request, env);
      }

      // GET /analytics/video/:eventId/stats - Get video statistics
      const videoStatsMatch = path.match(/^\/analytics\/video\/([a-f0-9]{64})\/stats$/i);
      if (videoStatsMatch && request.method === 'GET') {
        return handleVideoStats(request, env, videoStatsMatch[1]);
      }

      // GET /analytics/hashtag/:hashtag/trending - Get trending for specific hashtag
      const hashtagMatch = path.match(/^\/analytics\/hashtag\/([^\/]+)\/trending$/);
      if (hashtagMatch && request.method === 'GET') {
        return handleHashtagTrending(request, env, hashtagMatch[1]);
      }

      // GET /analytics/hashtags/trending - Get trending hashtags
      if (path === '/analytics/hashtags/trending' && request.method === 'GET') {
        return handleHashtagTrending(request, env);
      }

      // GET /analytics/trending/velocity - Get rapidly ascending content
      if (path === '/analytics/trending/velocity' && request.method === 'GET') {
        return handleVelocityTrending(request, env);
      }

      // Health check endpoint
      if (path === '/analytics/health' && request.method === 'GET') {
        return new Response(
          JSON.stringify({
            status: 'healthy',
            environment: env.ENVIRONMENT,
            timestamp: new Date().toISOString(),
            // Future: could add KV connection status, etc.
          }),
          {
            status: 200,
            headers: {
              'Content-Type': 'application/json',
              'Access-Control-Allow-Origin': '*'
            }
          }
        );
      }

      // 404 for unknown routes
      return new Response(
        JSON.stringify({ error: 'Not found' }),
        { 
          status: 404, 
          headers: { 
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
          } 
        }
      );

    } catch (error) {
      console.error('Worker error:', error);
      return new Response(
        JSON.stringify({ error: 'Internal server error' }),
        { 
          status: 500, 
          headers: { 
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
          } 
        }
      );
    }
  },
};