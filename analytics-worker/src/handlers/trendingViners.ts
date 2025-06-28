// ABOUTME: Handler for trending viners (creators) endpoint - returns top performing creators
// ABOUTME: Provides data for creator discovery in mobile app and website

import { AnalyticsEnv, TrendingCreator, CreatorData } from '../types/analytics';

export async function handleTrendingViners(
  request: Request,
  env: AnalyticsEnv
): Promise<Response> {
  try {
    const url = new URL(request.url);
    const limit = Math.min(parseInt(url.searchParams.get('limit') || '20'), 100);
    const minViews = parseInt(env.MIN_VIEWS_FOR_TRENDING);

    // Get all creator data
    const { keys } = await env.ANALYTICS_KV.list({ prefix: 'creator:' });
    const trendingViners: TrendingCreator[] = [];
    const now = Date.now();

    // Process each creator's metrics
    for (const key of keys) {
      const pubkey = key.name.replace('creator:', '');
      
      try {
        const creatorDataStr = await env.ANALYTICS_KV.get(key.name);
        if (!creatorDataStr) continue;
        
        const creatorData: CreatorData = JSON.parse(creatorDataStr);
        
        // Skip creators below minimum threshold
        if (creatorData.totalViews < minViews) continue;
        
        // Calculate creator trending score
        // Factors: total views, video count, recency, avg views per video
        const avgViewsPerVideo = creatorData.videoCount > 0 
          ? creatorData.totalViews / creatorData.videoCount 
          : 0;
        
        // Time decay factor (creators active recently get boost)
        const ageHours = (now - creatorData.lastUpdate) / (1000 * 60 * 60);
        const recencyBoost = 1 / (ageHours * 0.1 + 1); // Gentle time decay
        
        // Creator score: combination of total engagement and consistency
        const score = (creatorData.totalViews * 0.7 + avgViewsPerVideo * 0.3) * recencyBoost;
        
        trendingViners.push({
          pubkey,
          totalViews: creatorData.totalViews,
          videoCount: creatorData.videoCount,
          score,
          avgViewsPerVideo: Math.round(avgViewsPerVideo * 100) / 100, // Round to 2 decimals
          // Note: displayName could be fetched from Nostr profiles in the future
        });
      } catch (error) {
        console.warn(`Failed to process viner ${pubkey.substring(0, 8)}:`, error);
        continue;
      }
    }

    // Sort by trending score and limit results
    const topViners = trendingViners
      .sort((a, b) => b.score - a.score)
      .slice(0, limit);

    const response = {
      viners: topViners,
      algorithm: 'creator_engagement',
      updatedAt: now,
      period: '24h', // Could make this configurable
      totalViners: trendingViners.length,
      metrics: {
        minViews,
        avgVideosPerCreator: trendingViners.length > 0 
          ? Math.round((trendingViners.reduce((sum, v) => sum + v.videoCount, 0) / trendingViners.length) * 100) / 100
          : 0
      }
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
    console.error('Trending viners error:', error);
    return new Response(
      JSON.stringify({ 
        error: 'Failed to fetch trending viners',
        viners: [],
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