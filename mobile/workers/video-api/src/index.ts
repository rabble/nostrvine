// ABOUTME: Main entry point for NostrVine Video API Cloudflare Worker
// ABOUTME: Routes requests to appropriate handlers with CORS support

import { VideoAPI } from './video-api';
import { BatchVideoAPI } from './batch-video-api';
import { OptimizedBatchVideoAPI } from './batch-video-api-optimized';
import { SmartFeedAPI } from './smart-feed-api';
import { PrefetchManager } from './prefetch-manager';
import { VideoAnalyticsService } from './video-analytics-service';
import { MonitoringHandler } from './monitoring-handler';
import { PerformanceOptimizer } from './performance-optimizer';
import { UploadRequestHandler } from './handlers/upload-request';
import { CloudinaryUploadHandler } from './handlers/cloudinary-upload';
import { CloudinaryWebhookHandler } from './handlers/cloudinary-webhook';
import { ReadyEventsHandler } from './handlers/ready-events';
import { VideoStatusHandler } from './handlers/video-status';
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
      // Use optimized API if performance mode is enabled
      const useOptimized = url.searchParams.get('optimize') === 'true' || 
                          request.headers.get('X-Performance-Mode') === 'optimized' ||
                          env.ENABLE_PERFORMANCE_MODE === true;
      
      const batchAPI = useOptimized 
        ? new OptimizedBatchVideoAPI(env)
        : new BatchVideoAPI(env);
        
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

    // Route: POST /v1/media/request-upload (Cloudflare Stream - deprecated)
    if (request.method === 'POST' && url.pathname === '/v1/media/request-upload') {
      const uploadHandler = new UploadRequestHandler(env);
      const response = await uploadHandler.handleRequest(request, ctx);
      
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

    // Route: POST /v1/media/cloudinary/request-upload (Cloudinary - recommended)
    if (request.method === 'POST' && url.pathname === '/v1/media/cloudinary/request-upload') {
      const cloudinaryHandler = new CloudinaryUploadHandler(env);
      const response = await cloudinaryHandler.handleRequest(request, ctx);
      
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

    // Route: GET /api/performance
    if (request.method === 'GET' && url.pathname === '/api/performance') {
      const performanceOptimizer = new PerformanceOptimizer(env);
      const health = await performanceOptimizer.healthCheck();
      
      return new Response(
        JSON.stringify({
          status: health.healthy ? 'healthy' : 'degraded',
          performance: health.performance,
          recommendations: health.recommendations,
          timestamp: new Date().toISOString()
        }),
        {
          status: 200,
          headers: {
            'Content-Type': 'application/json',
            ...corsHeaders
          }
        }
      );
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

    // Route: POST /v1/media/webhook
    if (request.method === 'POST' && url.pathname === '/v1/media/webhook') {
      const webhookHandler = new CloudinaryWebhookHandler(env);
      const response = await webhookHandler.handleWebhook(request, ctx);
      
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

    // Route: GET /v1/media/ready-events
    if (request.method === 'GET' && url.pathname === '/v1/media/ready-events') {
      const readyEventsHandler = new ReadyEventsHandler(env);
      const response = await readyEventsHandler.handleGetReadyEvents(request, ctx);
      
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

    // Route: DELETE /v1/media/ready-events
    if (request.method === 'DELETE' && url.pathname === '/v1/media/ready-events') {
      const readyEventsHandler = new ReadyEventsHandler(env);
      const response = await readyEventsHandler.handleDeleteReadyEvent(request, ctx);
      
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

    // Route: GET /v1/media/ready-events/{public_id}
    const readyEventMatch = url.pathname.match(/^\/v1\/media\/ready-events\/([^\/]+)$/);
    if (request.method === 'GET' && readyEventMatch) {
      const publicId = readyEventMatch[1];
      const readyEventsHandler = new ReadyEventsHandler(env);
      const response = await readyEventsHandler.handleGetSpecificEvent(request, publicId, ctx);
      
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

    // Route: GET /v1/media/status/{videoId}
    const statusMatch = url.pathname.match(/^\/v1\/media\/status\/([^\/]+)$/);
    if (request.method === 'GET' && statusMatch) {
      const videoId = statusMatch[1];
      const statusHandler = new VideoStatusHandler(env);
      const response = await statusHandler.handleStatusCheck(request, videoId, ctx);
      
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