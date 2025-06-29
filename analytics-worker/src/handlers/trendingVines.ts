// ABOUTME: Handler for trending vines (videos) endpoint - returns top performing videos
// ABOUTME: Provides data for popular content discovery in mobile app and website

import { AnalyticsEnv, TrendingVideo } from '../types/analytics';
import { calculateTrendingScore, getTrending } from '../services/trendingCalculator';

export async function handleTrendingVines(
  request: Request,
  env: AnalyticsEnv
): Promise<Response> {
  try {
    const url = new URL(request.url);
    const limit = Math.min(parseInt(url.searchParams.get('limit') || '20'), 100);
    const minViews = parseInt(env.MIN_VIEWS_FOR_TRENDING || '1'); // Default to 1 view minimum

    // Try to get cached trending data first
    const cachedTrending = await getTrending(env);
    
    // If we have cached data, return it immediately
    if (cachedTrending && cachedTrending.videos.length > 0) {
      const response = {
        vines: cachedTrending.videos.slice(0, limit),
        algorithm: 'global_popularity',
        updatedAt: cachedTrending.updatedAt,
        period: '24h',
        totalVines: cachedTrending.videos.length
      };

      return new Response(JSON.stringify(response), {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
          'Cache-Control': 'public, max-age=300', // 5 minute cache
          'Access-Control-Allow-Origin': '*'
        }
      });
    }
    
    // If no cache, return empty list (calculation happens in background)
    const trendingVines: TrendingVideo[] = [];

    // Sort by trending score and limit results
    const topVines = trendingVines
      .sort((a, b) => b.score - a.score)
      .slice(0, limit);

    const response = {
      vines: topVines,
      algorithm: 'global_popularity',
      updatedAt: Date.now(),
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