// ABOUTME: Trending content API - returns popular videos without user personalization
// ABOUTME: Sets foundation for future opt-in algorithmic feeds

import { AnalyticsEnv } from '../types/analytics';
import { getTrending } from '../services/trendingCalculator';

export async function handleTrending(
  request: Request,
  env: AnalyticsEnv
): Promise<Response> {
  try {
    // Get trending data (from cache or fresh calculation)
    const trending = await getTrending(env);
    
    // Parse query parameters for future filtering
    const url = new URL(request.url);
    const limit = parseInt(url.searchParams.get('limit') || '20');
    
    // Future: could add filters like:
    // - category (once we have hashtags)
    // - timeframe (trending today vs this week)
    // - personalized (if user opts in and provides auth)
    
    // Apply limit
    const limitedVideos = trending.videos.slice(0, Math.min(limit, 50));
    
    return new Response(
      JSON.stringify({
        videos: limitedVideos,
        updatedAt: trending.updatedAt,
        // Future: could include user preferences if authenticated
        algorithm: 'global_popularity', // Identifies this as non-personalized
      }),
      {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
          'Cache-Control': 'public, max-age=60', // Cache for 1 minute
          'Access-Control-Allow-Origin': '*'
        }
      }
    );
    
  } catch (error) {
    console.error('Trending API error:', error);
    return new Response(
      JSON.stringify({ error: 'Failed to get trending videos' }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    );
  }
}

export async function handleVideoStats(
  request: Request,
  env: AnalyticsEnv,
  eventId: string
): Promise<Response> {
  try {
    // Validate event ID
    if (!eventId || !/^[a-f0-9]{64}$/i.test(eventId)) {
      return new Response(
        JSON.stringify({ error: 'Invalid event ID' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      );
    }
    
    // Get view data
    const viewKey = `views:${eventId}`;
    const viewData = await env.ANALYTICS_KV.get(viewKey, 'json');
    
    if (!viewData) {
      return new Response(
        JSON.stringify({
          eventId,
          views: 0,
          lastUpdate: null,
          // Future: could include personalized engagement data
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
    
    return new Response(
      JSON.stringify({
        eventId,
        ...viewData,
        // Future: trending rank, hashtags, similar videos
      }),
      {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
          'Cache-Control': 'public, max-age=30',
          'Access-Control-Allow-Origin': '*'
        }
      }
    );
    
  } catch (error) {
    console.error('Video stats error:', error);
    return new Response(
      JSON.stringify({ error: 'Failed to get video stats' }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    );
  }
}