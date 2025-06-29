// ABOUTME: Hashtag-specific trending calculator for community-based discovery
// ABOUTME: Identifies popular videos within each hashtag community

import { ViewData, TrendingVideo, HashtagTrending, AnalyticsEnv } from '../types/analytics';
import { calculateTrendingScore } from './trendingCalculator';

// Calculate trending videos for a specific hashtag
export async function calculateHashtagTrending(
  env: AnalyticsEnv, 
  hashtag: string,
  timeframe: '1h' | '6h' | '24h' | '7d' | '30d' = '24h'
): Promise<HashtagTrending> {
  const normalizedTag = hashtag.toLowerCase().replace(/^#/, '');
  const videos: TrendingVideo[] = [];
  
  try {
    // List all videos associated with this hashtag
    const videoKeys = await env.ANALYTICS_KV.list({ 
      prefix: `hashtag-video:${normalizedTag}:`,
      limit: 500 // Higher limit for popular hashtags
    });
    
    // Get current time for filtering
    const now = Date.now();
    const timeWindowMs = getTimeWindowMs(timeframe);
    const cutoffTime = now - timeWindowMs;
    
    // Batch fetch view data for all videos
    const promises = videoKeys.keys.map(async (key) => {
      const eventId = key.name.split(':').pop() || '';
      const viewKey = `views:${eventId}`;
      
      try {
        const viewData = await env.ANALYTICS_KV.get<ViewData>(viewKey, 'json');
        
        if (!viewData) return null;
        
        // Filter by time window
        if (viewData.lastUpdate < cutoffTime) return null;
        
        // Calculate trending score
        const score = calculateTrendingScore(viewData, now);
        
        return {
          eventId,
          views: viewData.count,
          score,
          title: viewData.title,
          hashtags: viewData.hashtags
        };
      } catch (e) {
        console.warn(`Failed to fetch view data for ${eventId}:`, e);
        return null;
      }
    });
    
    // Wait for all fetches
    const results = await Promise.all(promises);
    
    // Filter and collect valid results
    for (const result of results) {
      if (result) {
        videos.push(result);
      }
    }
    
    // Sort by score
    videos.sort((a, b) => b.score - a.score);
    
    // Get total views for this hashtag
    const hashtagViewKey = `hashtag-views:${normalizedTag}`;
    const totalViews = parseInt(await env.ANALYTICS_KV.get(hashtagViewKey) || '0');
    
    const trending: HashtagTrending = {
      hashtag: normalizedTag,
      timeframe,
      videoCount: videos.length,
      totalViews,
      topVideos: videos.slice(0, 20) // Top 20 videos
    };
    
    // Cache the result
    const cacheKey = `hashtag-trending:${normalizedTag}:${timeframe}`;
    await env.ANALYTICS_KV.put(
      cacheKey,
      JSON.stringify(trending),
      { expirationTtl: 300 } // 5 minute cache
    );
    
    return trending;
    
  } catch (error) {
    console.error(`Hashtag trending calculation error for ${hashtag}:`, error);
    
    return {
      hashtag: normalizedTag,
      timeframe,
      videoCount: 0,
      totalViews: 0,
      topVideos: []
    };
  }
}

// Get trending hashtags across the platform
export async function getTrendingHashtags(
  env: AnalyticsEnv,
  limit: number = 10
): Promise<Array<{ hashtag: string; views: number }>> {
  try {
    // List all hashtag view counters
    const hashtagKeys = await env.ANALYTICS_KV.list({
      prefix: 'hashtag-views:',
      limit: 1000 // Get many hashtags
    });
    
    // Fetch view counts
    const hashtags: Array<{ hashtag: string; views: number }> = [];
    
    for (const key of hashtagKeys.keys) {
      const hashtag = key.name.replace('hashtag-views:', '');
      const views = parseInt(await env.ANALYTICS_KV.get(key.name) || '0');
      
      if (views > 0) {
        hashtags.push({ hashtag, views });
      }
    }
    
    // Sort by views and return top
    hashtags.sort((a, b) => b.views - a.views);
    
    return hashtags.slice(0, limit);
    
  } catch (error) {
    console.error('Error getting trending hashtags:', error);
    return [];
  }
}

// Convert timeframe to milliseconds
function getTimeWindowMs(timeframe: string): number {
  switch (timeframe) {
    case '1h': return 60 * 60 * 1000;
    case '6h': return 6 * 60 * 60 * 1000;
    case '24h': return 24 * 60 * 60 * 1000;
    case '7d': return 7 * 24 * 60 * 60 * 1000;
    case '30d': return 30 * 24 * 60 * 60 * 1000;
    default: return 24 * 60 * 60 * 1000;
  }
}