// ABOUTME: Feature flags API handler for managing gradual rollouts
// ABOUTME: Provides endpoints for flag management, metrics, and A/B testing

import { FeatureFlagService, FeatureFlag } from '../services/feature-flags';
import { checkSecurity, applySecurityHeaders } from '../services/security';

interface FeatureFlagUpdateRequest {
  enabled?: boolean;
  rolloutPercentage?: number;
  variants?: Array<{
    name: string;
    percentage: number;
    metadata?: Record<string, any>;
  }>;
  metadata?: Record<string, any>;
}

interface FeatureFlagCheckRequest {
  userId?: string;
  attributes?: Record<string, any>;
}

interface GradualRolloutRequest {
  targetPercentage: number;
  incrementPercentage?: number;
  intervalMinutes?: number;
}

/**
 * Handle GET /api/feature-flags
 * List all feature flags
 */
export async function handleListFeatureFlags(
  request: Request,
  env: Env,
  ctx: ExecutionContext
): Promise<Response> {
  try {
    // Check security (admin only)
    const securityCheck = await checkSecurity(request, env);
    if (!securityCheck.allowed || !securityCheck.isAdmin) {
      return applySecurityHeaders(
        securityCheck.response || new Response(
          JSON.stringify({ error: 'Admin access required' }),
          { status: 403 }
        )
      );
    }

    const service = new FeatureFlagService(env, ctx);
    const flags = await service.getAllFlags();

    return applySecurityHeaders(new Response(
      JSON.stringify({
        flags,
        count: flags.length,
        timestamp: new Date().toISOString(),
      }),
      {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
          'Cache-Control': 'private, max-age=60', // Cache for 1 minute
        },
      }
    ));
  } catch (error) {
    console.error('Error listing feature flags:', error);
    return applySecurityHeaders(new Response(
      JSON.stringify({ error: 'Failed to list feature flags' }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    ));
  }
}

/**
 * Handle GET /api/feature-flags/{flagName}
 * Get specific feature flag details
 */
export async function handleGetFeatureFlag(
  flagName: string,
  request: Request,
  env: Env,
  ctx: ExecutionContext
): Promise<Response> {
  try {
    // Check security
    const securityCheck = await checkSecurity(request, env);
    if (!securityCheck.allowed) {
      return applySecurityHeaders(securityCheck.response!);
    }

    const service = new FeatureFlagService(env, ctx);
    const flags = await service.getAllFlags();
    const flag = flags.find(f => f.name === flagName);

    if (!flag) {
      return applySecurityHeaders(new Response(
        JSON.stringify({ error: 'Feature flag not found' }),
        { status: 404, headers: { 'Content-Type': 'application/json' } }
      ));
    }

    // Get metrics if admin
    let metrics;
    if (securityCheck.isAdmin) {
      metrics = await service.getRolloutMetrics(flagName);
    }

    return applySecurityHeaders(new Response(
      JSON.stringify({
        flag,
        metrics,
        timestamp: new Date().toISOString(),
      }),
      {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
          'Cache-Control': 'private, max-age=60',
        },
      }
    ));
  } catch (error) {
    console.error(`Error getting feature flag ${flagName}:`, error);
    return applySecurityHeaders(new Response(
      JSON.stringify({ error: 'Failed to get feature flag' }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    ));
  }
}

/**
 * Handle POST /api/feature-flags/{flagName}/check
 * Check if a feature is enabled for a user
 */
export async function handleCheckFeatureFlag(
  flagName: string,
  request: Request,
  env: Env,
  ctx: ExecutionContext
): Promise<Response> {
  try {
    // Check security
    const securityCheck = await checkSecurity(request, env);
    if (!securityCheck.allowed) {
      return applySecurityHeaders(securityCheck.response!);
    }

    // Parse request body
    let body: FeatureFlagCheckRequest = {};
    try {
      const contentType = request.headers.get('content-type');
      if (contentType?.includes('application/json')) {
        body = await request.json();
      }
    } catch (e) {
      // Optional body, ignore parse errors
    }

    const service = new FeatureFlagService(env, ctx);
    const decision = await service.isEnabled(
      flagName,
      body.userId || securityCheck.userId,
      body.attributes
    );

    return applySecurityHeaders(new Response(
      JSON.stringify({
        flagName,
        ...decision,
        timestamp: new Date().toISOString(),
      }),
      {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
          'Cache-Control': 'private, no-cache', // Don't cache flag decisions
        },
      }
    ));
  } catch (error) {
    console.error(`Error checking feature flag ${flagName}:`, error);
    return applySecurityHeaders(new Response(
      JSON.stringify({ error: 'Failed to check feature flag' }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    ));
  }
}

/**
 * Handle PUT /api/feature-flags/{flagName}
 * Update a feature flag (admin only)
 */
export async function handleUpdateFeatureFlag(
  flagName: string,
  request: Request,
  env: Env,
  ctx: ExecutionContext
): Promise<Response> {
  try {
    // Check security (admin only)
    const securityCheck = await checkSecurity(request, env);
    if (!securityCheck.allowed || !securityCheck.isAdmin) {
      return applySecurityHeaders(
        securityCheck.response || new Response(
          JSON.stringify({ error: 'Admin access required' }),
          { status: 403 }
        )
      );
    }

    // Parse request body
    let updates: FeatureFlagUpdateRequest;
    try {
      updates = await request.json();
    } catch (e) {
      return applySecurityHeaders(new Response(
        JSON.stringify({ error: 'Invalid request body' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      ));
    }

    const service = new FeatureFlagService(env, ctx);
    const updatedFlag = await service.updateFlag(flagName, updates);

    return applySecurityHeaders(new Response(
      JSON.stringify({
        flag: updatedFlag,
        timestamp: new Date().toISOString(),
      }),
      {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
        },
      }
    ));
  } catch (error) {
    console.error(`Error updating feature flag ${flagName}:`, error);
    return applySecurityHeaders(new Response(
      JSON.stringify({ error: 'Failed to update feature flag' }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    ));
  }
}

/**
 * Handle POST /api/feature-flags/{flagName}/rollout
 * Start gradual rollout (admin only)
 */
export async function handleGradualRollout(
  flagName: string,
  request: Request,
  env: Env,
  ctx: ExecutionContext
): Promise<Response> {
  try {
    // Check security (admin only)
    const securityCheck = await checkSecurity(request, env);
    if (!securityCheck.allowed || !securityCheck.isAdmin) {
      return applySecurityHeaders(
        securityCheck.response || new Response(
          JSON.stringify({ error: 'Admin access required' }),
          { status: 403 }
        )
      );
    }

    // Parse request body
    let rolloutRequest: GradualRolloutRequest;
    try {
      rolloutRequest = await request.json();
    } catch (e) {
      return applySecurityHeaders(new Response(
        JSON.stringify({ error: 'Invalid request body' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      ));
    }

    const service = new FeatureFlagService(env, ctx);
    await service.gradualRollout(
      flagName,
      rolloutRequest.targetPercentage,
      rolloutRequest.incrementPercentage,
      rolloutRequest.intervalMinutes
    );

    return applySecurityHeaders(new Response(
      JSON.stringify({
        message: 'Gradual rollout scheduled',
        flagName,
        targetPercentage: rolloutRequest.targetPercentage,
        timestamp: new Date().toISOString(),
      }),
      {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
        },
      }
    ));
  } catch (error) {
    console.error(`Error scheduling gradual rollout for ${flagName}:`, error);
    return applySecurityHeaders(new Response(
      JSON.stringify({ error: 'Failed to schedule gradual rollout' }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    ));
  }
}

/**
 * Handle GET /api/feature-flags/{flagName}/health
 * Check rollout health (admin only)
 */
export async function handleRolloutHealth(
  flagName: string,
  request: Request,
  env: Env,
  ctx: ExecutionContext
): Promise<Response> {
  try {
    // Check security (admin only)
    const securityCheck = await checkSecurity(request, env);
    if (!securityCheck.allowed || !securityCheck.isAdmin) {
      return applySecurityHeaders(
        securityCheck.response || new Response(
          JSON.stringify({ error: 'Admin access required' }),
          { status: 403 }
        )
      );
    }

    const service = new FeatureFlagService(env, ctx);
    const health = await service.checkRolloutHealth(flagName);

    return applySecurityHeaders(new Response(
      JSON.stringify({
        flagName,
        ...health,
        timestamp: new Date().toISOString(),
      }),
      {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
          'Cache-Control': 'private, max-age=30', // Cache for 30 seconds
        },
      }
    ));
  } catch (error) {
    console.error(`Error checking rollout health for ${flagName}:`, error);
    return applySecurityHeaders(new Response(
      JSON.stringify({ error: 'Failed to check rollout health' }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    ));
  }
}

/**
 * Handle POST /api/feature-flags/{flagName}/rollback
 * Rollback a feature flag (admin only)
 */
export async function handleRollback(
  flagName: string,
  request: Request,
  env: Env,
  ctx: ExecutionContext
): Promise<Response> {
  try {
    // Check security (admin only)
    const securityCheck = await checkSecurity(request, env);
    if (!securityCheck.allowed || !securityCheck.isAdmin) {
      return applySecurityHeaders(
        securityCheck.response || new Response(
          JSON.stringify({ error: 'Admin access required' }),
          { status: 403 }
        )
      );
    }

    // Parse request body
    let body: { reason: string };
    try {
      body = await request.json();
    } catch (e) {
      return applySecurityHeaders(new Response(
        JSON.stringify({ error: 'Invalid request body' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      ));
    }

    const service = new FeatureFlagService(env, ctx);
    const rolledBackFlag = await service.rollback(flagName, body.reason);

    return applySecurityHeaders(new Response(
      JSON.stringify({
        message: 'Feature flag rolled back',
        flag: rolledBackFlag,
        timestamp: new Date().toISOString(),
      }),
      {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
        },
      }
    ));
  } catch (error) {
    console.error(`Error rolling back feature flag ${flagName}:`, error);
    return applySecurityHeaders(new Response(
      JSON.stringify({ error: 'Failed to rollback feature flag' }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    ));
  }
}

/**
 * Handle OPTIONS requests for CORS
 */
export function handleFeatureFlagsOptions(): Response {
  return new Response(null, {
    status: 204,
    headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, PUT, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
      'Access-Control-Max-Age': '86400',
    },
  });
}