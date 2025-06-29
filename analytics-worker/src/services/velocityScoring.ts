// ABOUTME: Velocity scoring system to detect rapidly ascending content
// ABOUTME: Identifies videos gaining momentum through accelerated view rates

import { AnalyticsEnv, TimeWindowStats, TrendingVideo } from '../types/analytics';

// Calculate velocity score based on view acceleration
export async function calculateVelocityScore(
  env: AnalyticsEnv,
  eventId: string
): Promise<number> {
  try {
    const now = Date.now();
    const hourlyViews = await getHourlyViews(env, eventId, 24); // Last 24 hours
    
    if (hourlyViews.length < 2) return 0;
    
    // Calculate velocity as rate of change in view rate
    let velocitySum = 0;
    let weightSum = 0;
    
    for (let i = 1; i < hourlyViews.length; i++) {
      const prevHour = hourlyViews[i - 1];
      const currHour = hourlyViews[i];
      
      // Calculate hourly acceleration
      const acceleration = currHour.views - prevHour.views;
      
      // Weight recent hours more heavily (exponential decay)
      const hoursAgo = hourlyViews.length - i;
      const weight = Math.exp(-hoursAgo / 12); // 12-hour half-life
      
      velocitySum += acceleration * weight;
      weightSum += weight;
    }
    
    // Normalize velocity score
    const velocityScore = weightSum > 0 ? velocitySum / weightSum : 0;
    
    // Apply logarithmic scaling to prevent extreme values
    return velocityScore > 0 ? Math.log10(velocityScore + 1) * 100 : 0;
    
  } catch (error) {
    console.error(`Error calculating velocity for ${eventId}:`, error);
    return 0;
  }
}

// Get hourly view counts for a video
async function getHourlyViews(
  env: AnalyticsEnv,
  eventId: string,
  hours: number
): Promise<Array<{ hour: string; views: number }>> {
  const now = new Date();
  const hourlyData: Array<{ hour: string; views: number }> = [];
  
  for (let i = 0; i < hours; i++) {
    const hourDate = new Date(now.getTime() - i * 60 * 60 * 1000);
    const hourBucket = hourDate.toISOString().slice(0, 13);
    const hourKey = `hour:${hourBucket}:${eventId}`;
    
    const views = parseInt(await env.ANALYTICS_KV.get(hourKey) || '0');
    hourlyData.unshift({ hour: hourBucket, views });
  }
  
  return hourlyData;
}

// Get videos with highest velocity scores
export async function getVelocityTrending(
  env: AnalyticsEnv,
  limit: number = 20
): Promise<TrendingVideo[]> {
  try {
    // Get recent videos (last 48 hours) - use smaller limit to prevent timeout
    const cutoffTime = Date.now() - 48 * 60 * 60 * 1000;
    const recentVideos = await env.ANALYTICS_KV.list({
      prefix: 'views:',
      limit: 50 // Much smaller limit to prevent timeout
    });
    
    // Calculate velocity scores
    const videosWithVelocity: Array<TrendingVideo & { velocity: number }> = [];
    
    for (const key of recentVideos.keys) {
      const eventId = key.name.replace('views:', '');
      const viewData = await env.ANALYTICS_KV.get<any>(key.name, 'json');
      
      if (!viewData || viewData.lastUpdate < cutoffTime) continue;
      
      const velocityScore = await calculateVelocityScore(env, eventId);
      
      if (velocityScore > 0) {
        videosWithVelocity.push({
          eventId,
          views: viewData.count,
          score: velocityScore,
          velocity: velocityScore,
          title: viewData.title,
          hashtags: viewData.hashtags
        });
      }
    }
    
    // Sort by velocity score
    videosWithVelocity.sort((a, b) => b.velocity - a.velocity);
    
    // Cache result
    const cacheKey = 'trending:velocity';
    await env.ANALYTICS_KV.put(
      cacheKey,
      JSON.stringify(videosWithVelocity.slice(0, limit)),
      { expirationTtl: 300 } // 5 minute cache
    );
    
    return videosWithVelocity.slice(0, limit);
    
  } catch (error) {
    console.error('Error calculating velocity trending:', error);
    return [];
  }
}

// Get time window statistics for a video
export async function getTimeWindowStats(
  env: AnalyticsEnv,
  eventId: string
): Promise<TimeWindowStats> {
  const hourlyViews = await getHourlyViews(env, eventId, 24 * 30); // 30 days
  
  // Calculate views for different time windows
  const stats: TimeWindowStats = {
    eventId,
    views1h: 0,
    views6h: 0,
    views24h: 0,
    views7d: 0,
    views30d: 0,
    velocityScore: 0
  };
  
  // Sum views for each time window
  hourlyViews.forEach((hour, index) => {
    const hoursAgo = hourlyViews.length - index - 1;
    
    if (hoursAgo < 1) stats.views1h += hour.views;
    if (hoursAgo < 6) stats.views6h += hour.views;
    if (hoursAgo < 24) stats.views24h += hour.views;
    if (hoursAgo < 24 * 7) stats.views7d += hour.views;
    stats.views30d += hour.views;
  });
  
  // Calculate velocity score
  stats.velocityScore = await calculateVelocityScore(env, eventId);
  
  return stats;
}