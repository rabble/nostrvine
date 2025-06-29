// ABOUTME: Simple trending calculator - identifies popular videos based on view counts
// ABOUTME: Future foundation for more sophisticated algorithms and opt-in personalization

import { ViewData, TrendingVideo, TrendingData, AnalyticsEnv } from '../types/analytics';

// Calculate trending score for a video based on views and time decay
export function calculateTrendingScore(viewData: ViewData, currentTime: number): number {
  const ageHours = (currentTime - viewData.lastUpdate) / (1000 * 60 * 60);
  return viewData.count / (ageHours + 1);
}

export async function calculateTrending(env: AnalyticsEnv): Promise<TrendingData> {
  const minViews = parseInt(env.MIN_VIEWS_FOR_TRENDING || '1'); // Lower threshold
  const videos: TrendingVideo[] = [];
  
  try {
    // List view entries with a reasonable limit to prevent timeouts
    const list = await env.ANALYTICS_KV.list({ prefix: 'views:', limit: 100 }); // Reduced limit
    
    // Batch fetch to reduce KV round trips
    const promises = list.keys.map(async (key) => {
      const eventId = key.name.replace('views:', '');
      try {
        const viewData = await env.ANALYTICS_KV.get<ViewData>(key.name, 'json');
        
        if (!viewData || viewData.count < minViews) {
          return null;
        }
        
        // Calculate trending score using the exported function
        const score = calculateTrendingScore(viewData, Date.now());
        
        return {
          eventId,
          views: viewData.count,
          score,
        };
      } catch (e) {
        console.warn(`Failed to fetch view data for ${eventId}:`, e);
        return null;
      }
    });
    
    // Wait for all fetches to complete
    const results = await Promise.all(promises);
    
    // Filter out nulls and add to videos array
    for (const result of results) {
      if (result) {
        videos.push(result);
      }
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