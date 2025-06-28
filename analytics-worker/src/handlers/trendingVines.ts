// ABOUTME: Handler for trending vines (videos) endpoint - returns top performing videos
// ABOUTME: Provides data for popular content discovery in mobile app and website

import { AnalyticsEnv, TrendingVideo } from '../types/analytics';
import { calculateTrendingScore } from '../services/trendingCalculator';

export async function handleTrendingVines(
  request: Request,
  env: AnalyticsEnv
): Promise<Response> {
  try {
    const url = new URL(request.url);
    const limit = Math.min(parseInt(url.searchParams.get('limit') || '20'), 100);
    const minViews = parseInt(env.MIN_VIEWS_FOR_TRENDING);

    // Get all video view data
    const { keys } = await env.ANALYTICS_KV.list({ prefix: 'views:' });
    const trendingVines: TrendingVideo[] = [];
    const now = Date.now();

    // Process each video's trending score
    for (const key of keys) {
      const eventId = key.name.replace('views:', '');
      
      try {
        const viewDataStr = await env.ANALYTICS_KV.get(key.name);
        if (!viewDataStr) continue;
        
        const viewData = JSON.parse(viewDataStr);
        
        // Skip videos below minimum threshold
        if (viewData.count < minViews) continue;
        
        // Calculate trending score
        const score = calculateTrendingScore(viewData, now);
        
        trendingVines.push({
          eventId,
          views: viewData.count,
          score,
          // Note: title and hashtags could be fetched from Nostr events in the future
        });
      } catch (error) {
        console.warn(`Failed to process vine ${eventId}:`, error);
        continue;
      }
    }

    // Sort by trending score and limit results
    const topVines = trendingVines
      .sort((a, b) => b.score - a.score)
      .slice(0, limit);

    const response = {
      vines: topVines,
      algorithm: 'global_popularity',
      updatedAt: now,
      period: '24h', // Could make this configurable
      totalVines: trendingVines.length
    };

    return new Response(JSON.stringify(response), {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
        'Cache-Control': 'public, max-age=300', // 5 minute cache
        'Access-Control-Allow-Origin': '*'
      }
    });

  } catch (error) {
    console.error('Trending vines error:', error);
    return new Response(
      JSON.stringify({ 
        error: 'Failed to fetch trending vines',
        vines: [],
        updatedAt: Date.now()
      }),
      { 
        status: 500, 
        headers: { 
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        } 
      }
    );
  }
}