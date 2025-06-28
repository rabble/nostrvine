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
    const { eventId, source = 'web', creatorPubkey } = body;

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
    const viewData: ViewData = {
      count: newCount,
      lastUpdate: Date.now()
    };

    // Store updated count
    await env.ANALYTICS_KV.put(viewKey, JSON.stringify(viewData));

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