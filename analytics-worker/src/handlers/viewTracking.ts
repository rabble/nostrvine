// ABOUTME: Minimal view tracking handler - increments counters without user data
// ABOUTME: Foundation for future opt-in personalization features

import { ViewData, ViewRequest, AnalyticsEnv, CreatorData } from '../types/analytics';

export async function handleViewTracking(
  request: Request,
  env: AnalyticsEnv
): Promise<Response> {
  try {
    // Parse request body
    const body = await request.json() as ViewRequest;
    const { eventId, source = 'web', creatorPubkey, hashtags, title } = body;

    // Validate event ID (64 char hex string)
    if (!eventId || !/^[a-f0-9]{64}$/i.test(eventId)) {
      return new Response(
        JSON.stringify({ error: 'Invalid event ID' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      );
    }

    // NO RATE LIMITING - We want to track ALL usage of our app!

    // Get current view count
    const viewKey = `views:${eventId}`;
    const currentData = await env.ANALYTICS_KV.get<ViewData>(viewKey, 'json');
    
    // Increment view count
    const newCount = (currentData?.count || 0) + 1;
    const now = Date.now();
    
    // Preserve existing metadata or use new
    const viewData: ViewData = {
      count: newCount,
      lastUpdate: now,
      hashtags: hashtags || currentData?.hashtags || [],
      creatorPubkey: creatorPubkey || currentData?.creatorPubkey,
      title: title || currentData?.title
    };

    // Store updated count with metadata
    await env.ANALYTICS_KV.put(viewKey, JSON.stringify(viewData));
    
    // Track hourly buckets for time-window analytics
    const hourBucket = new Date(now).toISOString().slice(0, 13); // YYYY-MM-DDTHH
    const hourKey = `hour:${hourBucket}:${eventId}`;
    const hourData = await env.ANALYTICS_KV.get<number>(hourKey);
    await env.ANALYTICS_KV.put(hourKey, String((hourData || 0) + 1), {
      expirationTtl: 60 * 60 * 24 * 31 // Keep hourly data for 31 days
    });
    
    // Track hashtag views
    if (hashtags && hashtags.length > 0) {
      await trackHashtagViews(env, eventId, hashtags);
    }

    // Track creator metrics if provided
    if (creatorPubkey && /^[a-f0-9]{64}$/i.test(creatorPubkey)) {
      await updateCreatorMetrics(env, creatorPubkey, eventId);
    }

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


// Track views for each hashtag
async function trackHashtagViews(env: AnalyticsEnv, eventId: string, hashtags: string[]): Promise<void> {
  try {
    for (const hashtag of hashtags) {
      // Normalize hashtag (lowercase, remove # if present)
      const normalizedTag = hashtag.toLowerCase().replace(/^#/, '');
      
      // Track this video is associated with this hashtag
      const hashtagVideoKey = `hashtag-video:${normalizedTag}:${eventId}`;
      const exists = await env.ANALYTICS_KV.get(hashtagVideoKey);
      if (!exists) {
        await env.ANALYTICS_KV.put(hashtagVideoKey, '1', {
          expirationTtl: 60 * 60 * 24 * 30 // 30 days
        });
      }
      
      // Increment hashtag view counter
      const hashtagViewKey = `hashtag-views:${normalizedTag}`;
      const currentViews = await env.ANALYTICS_KV.get<number>(hashtagViewKey);
      await env.ANALYTICS_KV.put(hashtagViewKey, String((currentViews || 0) + 1));
    }
  } catch (error) {
    console.error('Failed to track hashtag views:', error);
    // Don't fail the whole request if hashtag tracking fails
  }
}

// Update creator metrics when their video gets a view
async function updateCreatorMetrics(env: AnalyticsEnv, creatorPubkey: string, eventId: string): Promise<void> {
  try {
    const creatorKey = `creator:${creatorPubkey}`;
    const currentData = await env.ANALYTICS_KV.get<CreatorData>(creatorKey, 'json');
    
    // Track unique videos this creator has had views on
    const videoSetKey = `creator-videos:${creatorPubkey}`;
    const existingVideos = await env.ANALYTICS_KV.get(videoSetKey);
    let videoIds: string[] = existingVideos ? JSON.parse(existingVideos) : [];
    
    // Add this video if not already tracked
    const isNewVideo = !videoIds.includes(eventId);
    if (isNewVideo) {
      videoIds.push(eventId);
      await env.ANALYTICS_KV.put(videoSetKey, JSON.stringify(videoIds));
    }
    
    // Update creator metrics
    const creatorData: CreatorData = {
      totalViews: (currentData?.totalViews || 0) + 1,
      videoCount: videoIds.length,
      lastUpdate: Date.now()
    };
    
    await env.ANALYTICS_KV.put(creatorKey, JSON.stringify(creatorData));
    
    console.log(`Creator metrics updated: ${creatorPubkey.substring(0, 8)}... - ${creatorData.totalViews} total views, ${creatorData.videoCount} videos`);
  } catch (error) {
    console.error('Failed to update creator metrics:', error);
    // Don't fail the whole request if creator tracking fails
  }
}