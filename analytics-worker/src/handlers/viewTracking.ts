// ABOUTME: Minimal view tracking handler - increments counters without user data
// ABOUTME: Foundation for future opt-in personalization features

import { ViewData, ViewRequest, AnalyticsEnv } from '../types/analytics';

export async function handleViewTracking(
  request: Request,
  env: AnalyticsEnv
): Promise<Response> {
  try {
    // Parse request body
    const body = await request.json() as ViewRequest;
    const { eventId, source = 'web' } = body;

    // Validate event ID (64 char hex string)
    if (!eventId || !/^[a-f0-9]{64}$/i.test(eventId)) {
      return new Response(
        JSON.stringify({ error: 'Invalid event ID' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      );
    }

    // Simple rate limiting by IP (anonymous)
    const clientIP = request.headers.get('CF-Connecting-IP') || 'unknown';
    const rateLimitKey = `rate:${hashIP(clientIP)}`;
    const rateLimitData = await env.ANALYTICS_KV.get(rateLimitKey);
    
    if (rateLimitData) {
      const { count, windowStart } = JSON.parse(rateLimitData);
      const now = Date.now();
      const windowAge = now - windowStart;
      
      // 5 views per minute per IP
      if (windowAge < 60000 && count >= 5) {
        return new Response(
          JSON.stringify({ error: 'Rate limit exceeded' }),
          { status: 429, headers: { 'Content-Type': 'application/json' } }
        );
      }
      
      // Reset window if expired
      if (windowAge >= 60000) {
        await env.ANALYTICS_KV.put(
          rateLimitKey,
          JSON.stringify({ count: 1, windowStart: now }),
          { expirationTtl: 120 } // 2 minute TTL
        );
      } else {
        await env.ANALYTICS_KV.put(
          rateLimitKey,
          JSON.stringify({ count: count + 1, windowStart }),
          { expirationTtl: 120 }
        );
      }
    } else {
      await env.ANALYTICS_KV.put(
        rateLimitKey,
        JSON.stringify({ count: 1, windowStart: Date.now() }),
        { expirationTtl: 120 }
      );
    }

    // Get current view count
    const viewKey = `views:${eventId}`;
    const currentData = await env.ANALYTICS_KV.get<ViewData>(viewKey, 'json');
    
    // Increment view count
    const newCount = (currentData?.count || 0) + 1;
    const viewData: ViewData = {
      count: newCount,
      lastUpdate: Date.now()
    };

    // Store updated count
    await env.ANALYTICS_KV.put(viewKey, JSON.stringify(viewData));

    // Log to console for debugging (no user data)
    console.log(`View recorded: ${eventId} from ${source}, total views: ${newCount}`);

    // Return success response
    return new Response(
      JSON.stringify({
        success: true,
        eventId,
        views: newCount,
        // Future: could return personalized recommendations if user opts in
      }),
      {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
          'Cache-Control': 'no-cache',
          'Access-Control-Allow-Origin': '*'
        }
      }
    );

  } catch (error) {
    console.error('View tracking error:', error);
    return new Response(
      JSON.stringify({ error: 'Failed to track view' }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    );
  }
}

// Simple IP hashing for rate limiting (not stored permanently)
function hashIP(ip: string): string {
  // Simple hash to anonymize IP for rate limiting
  let hash = 0;
  for (let i = 0; i < ip.length; i++) {
    const char = ip.charCodeAt(i);
    hash = ((hash << 5) - hash) + char;
    hash = hash & hash; // Convert to 32-bit integer
  }
  return Math.abs(hash).toString(36);
}