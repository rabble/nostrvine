// ABOUTME: Main entry point for NostrVine Video API Cloudflare Worker
// ABOUTME: Routes requests to appropriate handlers with CORS support

import { VideoAPI } from './video-api';
import { BatchVideoAPI } from './batch-video-api';
import { SmartFeedAPI } from './smart-feed-api';
import { PrefetchManager } from './prefetch-manager';
import { VideoAnalyticsService } from './video-analytics-service';
import { MonitoringHandler } from './monitoring-handler';
import { Env, ExecutionContext } from './types';

// CORS headers for mobile app access
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  'Access-Control-Max-Age': '86400',
};

export default {
  async fetch(
    request: Request,
    env: Env,
    ctx: ExecutionContext
  ): Promise<Response> {
    const url = new URL(request.url);
    
    // Handle CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    // Route: GET /api/video/{video_id}
    const videoMatch = url.pathname.match(/^\/api\/video\/([a-f0-9]{64})$/i);
    if (request.method === 'GET' && videoMatch) {
      const videoId = videoMatch[1];
      const videoAPI = new VideoAPI(env);
      const response = await videoAPI.handleVideoRequest(videoId, request, ctx);
      
      // Add CORS headers to response
      const newHeaders = new Headers(response.headers);
      Object.entries(corsHeaders).forEach(([key, value]) => {
        newHeaders.set(key, value);
      });
      
      return new Response(response.body, {
        status: response.status,
        headers: newHeaders
      });
    }

    // Route: POST /api/videos/batch
    if (request.method === 'POST' && url.pathname === '/api/videos/batch') {
      const batchAPI = new BatchVideoAPI(env);
      const response = await batchAPI.handleBatchRequest(request, ctx);
      
      // Add CORS headers to response
      const newHeaders = new Headers(response.headers);
      Object.entries(corsHeaders).forEach(([key, value]) => {
        newHeaders.set(key, value);
      });
      
      return new Response(response.body, {
        status: response.status,
        headers: newHeaders
      });
    }

    // Route: GET /api/feed
    if (request.method === 'GET' && url.pathname === '/api/feed') {
      const feedAPI = new SmartFeedAPI(env);
      const response = await feedAPI.handleFeedRequest(request, ctx);
      
      // Add CORS headers to response
      const newHeaders = new Headers(response.headers);
      Object.entries(corsHeaders).forEach(([key, value]) => {
        newHeaders.set(key, value);
      });
      
      return new Response(response.body, {
        status: response.status,
        headers: newHeaders
      });
    }

    // Route: GET/POST /api/prefetch
    if ((request.method === 'GET' || request.method === 'POST') && url.pathname === '/api/prefetch') {
      const prefetchManager = new PrefetchManager(env);
      const response = await prefetchManager.handlePrefetchRequest(request, ctx);
      
      // Add CORS headers to response
      const newHeaders = new Headers(response.headers);
      Object.entries(corsHeaders).forEach(([key, value]) => {
        newHeaders.set(key, value);
      });
      
      return new Response(response.body, {
        status: response.status,
        headers: newHeaders
      });
    }

    // Route: GET /api/prefetch/analytics
    if (request.method === 'GET' && url.pathname === '/api/prefetch/analytics') {
      const prefetchManager = new PrefetchManager(env);
      const response = await prefetchManager.handlePrefetchAnalytics(request, ctx);
      
      // Add CORS headers to response
      const newHeaders = new Headers(response.headers);
      Object.entries(corsHeaders).forEach(([key, value]) => {
        newHeaders.set(key, value);
      });
      
      return new Response(response.body, {
        status: response.status,
        headers: newHeaders
      });
    }

    // Route: GET /health (Enhanced health check - public endpoint)
    if (request.method === 'GET' && url.pathname === '/health') {
      const monitoringHandler = new MonitoringHandler(env);
      const response = await monitoringHandler.handleHealthCheck(ctx);
      
      // Add CORS headers to response
      const newHeaders = new Headers(response.headers);
      Object.entries(corsHeaders).forEach(([key, value]) => {
        newHeaders.set(key, value);
      });
      
      return new Response(response.body, {
        status: response.status,
        headers: newHeaders
      });
    }

    // Route: GET /api/analytics (Legacy endpoint - kept for backwards compatibility)
    if (request.method === 'GET' && url.pathname === '/api/analytics') {
      // Check for admin access (you might want to add authentication here)
      const authHeader = request.headers.get('Authorization');
      if (!authHeader || !authHeader.startsWith('Bearer ')) {
        return new Response(
          JSON.stringify({ error: 'Unauthorized' }),
          {
            status: 401,
            headers: {
              'Content-Type': 'application/json',
              ...corsHeaders
            }
          }
        );
      }

      const analyticsService = new VideoAnalyticsService(env);
      const hours = parseInt(url.searchParams.get('hours') || '24', 10);
      const summary = await analyticsService.getAnalyticsSummary(hours);

      return new Response(
        JSON.stringify({
          summary,
          timestamp: new Date().toISOString()
        }),
        {
          headers: {
            'Content-Type': 'application/json',
            ...corsHeaders
          }
        }
      );
    }

    // Route: GET /api/analytics/popular (Requires authentication)
    if (request.method === 'GET' && url.pathname === '/api/analytics/popular') {
      const monitoringHandler = new MonitoringHandler(env);
      
      // Validate authentication
      if (!monitoringHandler.validateAuth(request)) {
        return new Response(
          JSON.stringify({ error: 'Unauthorized' }),
          {
            status: 401,
            headers: {
              'Content-Type': 'application/json',
              ...corsHeaders
            }
          }
        );
      }

      const response = await monitoringHandler.handlePopularVideos(request, ctx);
      
      // Add CORS headers to response
      const newHeaders = new Headers(response.headers);
      Object.entries(corsHeaders).forEach(([key, value]) => {
        newHeaders.set(key, value);
      });
      
      return new Response(response.body, {
        status: response.status,
        headers: newHeaders
      });
    }

    // Route: GET /api/analytics/dashboard (Requires authentication)
    if (request.method === 'GET' && url.pathname === '/api/analytics/dashboard') {
      const monitoringHandler = new MonitoringHandler(env);
      
      // Validate authentication
      if (!monitoringHandler.validateAuth(request)) {
        return new Response(
          JSON.stringify({ error: 'Unauthorized' }),
          {
            status: 401,
            headers: {
              'Content-Type': 'application/json',
              ...corsHeaders
            }
          }
        );
      }

      const response = await monitoringHandler.handleDashboard(request, ctx);
      
      // Add CORS headers to response
      const newHeaders = new Headers(response.headers);
      Object.entries(corsHeaders).forEach(([key, value]) => {
        newHeaders.set(key, value);
      });
      
      return new Response(response.body, {
        status: response.status,
        headers: newHeaders
      });
    }

    // 404 for unmatched routes
    return new Response(
      JSON.stringify({ error: 'Not found' }),
      {
        status: 404,
        headers: {
          'Content-Type': 'application/json',
          ...corsHeaders
        }
      }
    );
  },
};