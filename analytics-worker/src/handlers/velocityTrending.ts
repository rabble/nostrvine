// ABOUTME: Handler for velocity-based trending (rapidly ascending content)
// ABOUTME: Surfaces videos with accelerating view rates

import { AnalyticsEnv } from '../types/analytics';
import { getVelocityTrending, getTimeWindowStats } from '../services/velocityScoring';

export async function handleVelocityTrending(
  request: Request,
  env: AnalyticsEnv
): Promise<Response> {
  try {
    const url = new URL(request.url);
    const eventId = url.searchParams.get('eventId');
    
    // If eventId provided, return time window stats for that video
    if (eventId) {
      if (!/^[a-f0-9]{64}$/i.test(eventId)) {
        return new Response(
          JSON.stringify({ error: 'Invalid event ID' }),
          { status: 400, headers: { 'Content-Type': 'application/json' } }
        );
      }
      
      const stats = await getTimeWindowStats(env, eventId);
      
      return new Response(
        JSON.stringify({
          success: true,
          stats,
          updatedAt: Date.now()
        }),
        {
          status: 200,
          headers: {
            'Content-Type': 'application/json',
            'Cache-Control': 'public, max-age=300',
            'Access-Control-Allow-Origin': '*'
          }
        }
      );
    }
    
    // Check cache for velocity trending
    const cacheKey = 'trending:velocity';
    const cached = await env.ANALYTICS_KV.get(cacheKey);
    
    if (cached) {
      return new Response(
        JSON.stringify({
          success: true,
          videos: JSON.parse(cached),
          updatedAt: Date.now()
        }),
        {
          status: 200,
          headers: {
            'Content-Type': 'application/json',
            'Cache-Control': 'public, max-age=300',
            'Access-Control-Allow-Origin': '*',
            'X-Cache': 'HIT'
          }
        }
      );
    }
    
    // For now, return empty array since velocity calculation is expensive
    // TODO: Implement background worker for velocity calculations
    const trending: any[] = [];
    
    return new Response(
      JSON.stringify({
        success: true,
        videos: trending,
        updatedAt: Date.now()
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
    console.error('Velocity trending error:', error);
    return new Response(
      JSON.stringify({ error: 'Failed to get velocity trending' }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    );
  }
}