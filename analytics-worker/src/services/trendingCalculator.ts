// ABOUTME: Simple trending calculator - identifies popular videos based on view counts
// ABOUTME: Future foundation for more sophisticated algorithms and opt-in personalization

import { ViewData, TrendingVideo, TrendingData, AnalyticsEnv } from '../types/analytics';

export async function calculateTrending(env: AnalyticsEnv): Promise<TrendingData> {
  const minViews = parseInt(env.MIN_VIEWS_FOR_TRENDING || '10');
  const videos: TrendingVideo[] = [];
  
  try {
    // List all view entries (limited to prevent overwhelming KV)
    const list = await env.ANALYTICS_KV.list({ prefix: 'views:', limit: 1000 });
    
    // Process each video's view data
    for (const key of list.keys) {
      const eventId = key.name.replace('views:', '');
      const viewData = await env.ANALYTICS_KV.get<ViewData>(key.name, 'json');
      
      if (!viewData || viewData.count < minViews) {
        continue;
      }
      
      // Calculate simple trending score
      // Future: could use time decay, velocity, engagement metrics
      const age = Date.now() - viewData.lastUpdate;
      const ageHours = age / (1000 * 60 * 60);
      
      // Simple score: views divided by age in hours (plus 1 to avoid division by zero)
      // This favors recent popular videos
      const score = viewData.count / (ageHours + 1);
      
      videos.push({
        eventId,
        views: viewData.count,
        score,
        // Future: fetch title and hashtags from Nostr or cache
      });
    }
    
    // Sort by score (highest first)
    videos.sort((a, b) => b.score - a.score);
    
    // Return top 20 trending videos
    const trending: TrendingData = {
      videos: videos.slice(0, 20),
      updatedAt: Date.now()
    };
    
    // Cache the trending data
    await env.ANALYTICS_KV.put(
      'trending:videos',
      JSON.stringify(trending),
      { expirationTtl: 300 } // 5 minute cache
    );
    
    console.log(`Trending calculated: ${trending.videos.length} videos`);
    return trending;
    
  } catch (error) {
    console.error('Trending calculation error:', error);
    
    // Return empty trending list on error
    return {
      videos: [],
      updatedAt: Date.now()
    };
  }
}

export async function getTrending(env: AnalyticsEnv): Promise<TrendingData> {
  // Try to get from cache first
  const cached = await env.ANALYTICS_KV.get<TrendingData>('trending:videos', 'json');
  
  if (cached) {
    const age = Date.now() - cached.updatedAt;
    const maxAge = parseInt(env.TRENDING_UPDATE_INTERVAL || '300') * 1000;
    
    // Return cached if fresh enough
    if (age < maxAge) {
      return cached;
    }
  }
  
  // Calculate fresh trending data
  return calculateTrending(env);
}