// ABOUTME: Handler for hashtag-specific trending endpoints
// ABOUTME: Provides trending videos within hashtag communities

import { AnalyticsEnv } from '../types/analytics';
import { calculateHashtagTrending, getTrendingHashtags } from '../services/hashtagTrending';

export async function handleHashtagTrending(
  request: Request,
  env: AnalyticsEnv,
  hashtag?: string
): Promise<Response> {
  try {
    // If no hashtag specified, return trending hashtags
    if (!hashtag) {
      const trendingHashtags = await getTrendingHashtags(env, 20);
      
      return new Response(
        JSON.stringify({
          success: true,
          hashtags: trendingHashtags,
          updatedAt: Date.now()
        }),
        {
          status: 200,
          headers: {
            'Content-Type': 'application/json',
            'Cache-Control': 'public, max-age=300', // 5 minute cache
            'Access-Control-Allow-Origin': '*'
          }
        }
      );
    }
    
    // Get timeframe from query params
    const url = new URL(request.url);
    const timeframe = url.searchParams.get('timeframe') as any || '24h';
    
    // Validate timeframe
    const validTimeframes = ['1h', '6h', '24h', '7d', '30d'];
    if (!validTimeframes.includes(timeframe)) {
      return new Response(
        JSON.stringify({ error: 'Invalid timeframe' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      );
    }
    
    // Check cache first
    const normalizedTag = hashtag.toLowerCase().replace(/^#/, '');
    const cacheKey = `hashtag-trending:${normalizedTag}:${timeframe}`;
    const cached = await env.ANALYTICS_KV.get(cacheKey);
    
    if (cached) {
      return new Response(cached, {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
          'Cache-Control': 'public, max-age=300',
          'Access-Control-Allow-Origin': '*',
          'X-Cache': 'HIT'
        }
      });
    }
    
    // Calculate trending for hashtag
    const trending = await calculateHashtagTrending(env, hashtag, timeframe);
    
    return new Response(
      JSON.stringify({
        success: true,
        ...trending
      }),
      {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
          'Cache-Control': 'public, max-age=300',
          'Access-Control-Allow-Origin': '*',
          'X-Cache': 'MISS'
        }
      }
    );
    
  } catch (error) {
    console.error('Hashtag trending error:', error);
    return new Response(
      JSON.stringify({ error: 'Failed to get hashtag trending' }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    );
  }
}