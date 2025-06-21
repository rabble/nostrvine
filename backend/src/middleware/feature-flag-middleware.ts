// ABOUTME: Feature flag middleware for API endpoints
// ABOUTME: Enables gradual rollout and A/B testing for video caching features

import { FeatureFlagService } from '../services/feature-flags';
import { VideoAnalyticsService } from '../services/analytics';

export interface FeatureFlagContext {
  featureFlags: FeatureFlagService;
  analytics: VideoAnalyticsService;
  decisions: Map<string, any>;
}

/**
 * Create feature flag middleware that checks flags before processing requests
 */
export function createFeatureFlagMiddleware(
  requiredFlag: string,
  options?: {
    fallbackResponse?: (request: Request) => Response;
    trackUsage?: boolean;
    requireVariant?: string;
  }
) {
  return async function(
    request: Request,
    env: Env,
    ctx: ExecutionContext,
    next: (request: Request, env: Env, ctx: ExecutionContext, ffContext: FeatureFlagContext) => Promise<Response>
  ): Promise<Response> {
    const startTime = Date.now();
    const featureFlags = new FeatureFlagService(env, ctx);
    const analytics = new VideoAnalyticsService(env, ctx);
    
    // Extract user ID from request
    const authHeader = request.headers.get('authorization');
    const userId = authHeader ? extractUserIdFromAuth(authHeader) : 'anonymous';
    
    // Check feature flag
    const decision = await featureFlags.isEnabled(requiredFlag, userId, {
      userAgent: request.headers.get('user-agent'),
      country: (request as any).cf?.country,
      url: request.url,
    });

    // If feature is disabled, return fallback response
    if (!decision.enabled) {
      console.log(`Feature ${requiredFlag} disabled for user ${userId}: ${decision.reason}`);
      
      // Track the attempt
      if (ctx) {
        ctx.waitUntil(
          trackFeatureFlagAttempt(env, requiredFlag, false, decision, startTime)
        );
      }
      
      if (options?.fallbackResponse) {
        return options.fallbackResponse(request);
      }
      
      return new Response(
        JSON.stringify({
          error: 'Feature not available',
          message: `The ${requiredFlag} feature is being gradually rolled out`,
          reason: decision.reason,
        }),
        {
          status: 503,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Retry-After': '3600', // Retry in 1 hour
            'X-Feature-Flag': requiredFlag,
            'X-Feature-Enabled': 'false',
          },
        }
      );
    }

    // Check variant requirement if specified
    if (options?.requireVariant && decision.variant !== options.requireVariant) {
      console.log(`Feature ${requiredFlag} wrong variant for user ${userId}: ${decision.variant}`);
      
      return new Response(
        JSON.stringify({
          error: 'Feature variant not available',
          message: `This endpoint requires variant: ${options.requireVariant}`,
        }),
        {
          status: 503,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'X-Feature-Flag': requiredFlag,
            'X-Feature-Variant': decision.variant || 'none',
          },
        }
      );
    }

    // Create feature flag context
    const ffContext: FeatureFlagContext = {
      featureFlags,
      analytics,
      decisions: new Map([[requiredFlag, decision]]),
    };

    // Process request with feature enabled
    const response = await next(request, env, ctx, ffContext);
    
    // Track successful usage
    if (options?.trackUsage !== false && ctx) {
      const endTime = Date.now();
      const responseTime = endTime - startTime;
      
      ctx.waitUntil(
        trackFeatureFlagUsage(
          env,
          requiredFlag,
          decision,
          response.status,
          responseTime,
          {
            url: request.url,
            method: request.method,
            userAgent: request.headers.get('user-agent'),
            country: (request as any).cf?.country,
          }
        )
      );
    }

    // Add feature flag headers to response
    const newHeaders = new Headers(response.headers);
    newHeaders.set('X-Feature-Flag', requiredFlag);
    newHeaders.set('X-Feature-Enabled', 'true');
    if (decision.variant) {
      newHeaders.set('X-Feature-Variant', decision.variant);
    }

    return new Response(response.body, {
      status: response.status,
      statusText: response.statusText,
      headers: newHeaders,
    });
  };
}

/**
 * Check multiple feature flags
 */
export async function checkMultipleFlags(
  env: Env,
  ctx: ExecutionContext,
  userId: string,
  flagNames: string[]
): Promise<Map<string, boolean>> {
  const featureFlags = new FeatureFlagService(env, ctx);
  const results = new Map<string, boolean>();
  
  const decisions = await Promise.all(
    flagNames.map(flag => featureFlags.isEnabled(flag, userId))
  );
  
  flagNames.forEach((flag, index) => {
    results.set(flag, decisions[index].enabled);
  });
  
  return results;
}

/**
 * Get feature flag variant for A/B testing
 */
export async function getFeatureFlagVariant(
  env: Env,
  ctx: ExecutionContext,
  flagName: string,
  userId: string
): Promise<string | null> {
  const featureFlags = new FeatureFlagService(env, ctx);
  const decision = await featureFlags.isEnabled(flagName, userId);
  return decision.variant || null;
}

// Helper functions

function extractUserIdFromAuth(authHeader: string): string {
  // Extract user ID from Bearer token or API key
  // This is a simplified version - implement based on your auth system
  const parts = authHeader.split(' ');
  if (parts.length === 2 && parts[0] === 'Bearer') {
    // Hash the token to create a stable user ID
    const crypto = require('crypto');
    return crypto.createHash('sha256').update(parts[1]).digest('hex').substring(0, 16);
  }
  return 'anonymous';
}

async function trackFeatureFlagAttempt(
  env: Env,
  flagName: string,
  enabled: boolean,
  decision: any,
  startTime: number
): Promise<void> {
  const key = `ff_attempt:${flagName}:${Date.now()}`;
  const data = {
    flagName,
    enabled,
    decision,
    timestamp: new Date().toISOString(),
    responseTime: Date.now() - startTime,
  };
  
  await env.METADATA_CACHE.put(key, JSON.stringify(data), {
    expirationTtl: 86400, // 24 hours
  });
}

async function trackFeatureFlagUsage(
  env: Env,
  flagName: string,
  decision: any,
  statusCode: number,
  responseTime: number,
  metadata: any
): Promise<void> {
  // Update hourly metrics
  const hourKey = `ff_metrics:${flagName}:${new Date().toISOString().substring(0, 13)}`;
  
  try {
    const existing = await env.METADATA_CACHE.get(hourKey);
    const metrics = existing ? JSON.parse(existing) : {
      flagName,
      hour: new Date().toISOString().substring(0, 13),
      requests: 0,
      enabledCount: 0,
      variants: {},
      avgResponseTime: 0,
      totalResponseTime: 0,
      statusCodes: {},
      errors: 0,
    };
    
    // Update metrics
    metrics.requests++;
    if (decision.enabled) metrics.enabledCount++;
    if (decision.variant) {
      metrics.variants[decision.variant] = (metrics.variants[decision.variant] || 0) + 1;
    }
    metrics.totalResponseTime += responseTime;
    metrics.avgResponseTime = metrics.totalResponseTime / metrics.requests;
    metrics.statusCodes[statusCode] = (metrics.statusCodes[statusCode] || 0) + 1;
    if (statusCode >= 400) metrics.errors++;
    
    // Calculate performance metrics for rollout health
    const performanceMetrics = {
      averageResponseTime: metrics.avgResponseTime,
      p95ResponseTime: responseTime, // Simplified - would need proper percentile tracking
      cacheHitRate: metadata.cacheHit ? 1 : 0, // Simplified
      successRate: statusCode < 400 ? 1 : 0,
    };
    
    // Save updated metrics
    await env.METADATA_CACHE.put(hourKey, JSON.stringify({
      ...metrics,
      performanceMetrics,
      lastUpdated: new Date().toISOString(),
    }), {
      expirationTtl: 86400 * 7, // Keep for 7 days
    });
  } catch (error) {
    console.error('Error tracking feature flag usage:', error);
  }
}