// ABOUTME: Video moderation API endpoints for content reporting and safety
// ABOUTME: Implements report submission, tracking, and admin moderation features

import { checkSecurity, applySecurityHeaders, RateLimiter, RATE_LIMITS } from '../services/security';
import { VideoAnalyticsService } from '../services/analytics';

interface ReportSubmission {
  videoId: string;
  reportType: 'spam' | 'illegal' | 'harassment' | 'other';
  reason: string;
  reporterPubkey: string;
  nostrEventId?: string;
}

interface VideoReport {
  id: string;
  videoId: string;
  reportType: string;
  reason: string;
  reporterPubkey: string;
  nostrEventId?: string;
  createdAt: string;
}

interface VideoModerationStatus {
  videoId: string;
  reportCount: number;
  isHidden: boolean;
  reportTypes: string[];
  lastReportedAt?: string;
  moderationActions: ModerationAction[];
}

interface ModerationAction {
  action: 'hide' | 'unhide' | 'delete';
  moderatorPubkey: string;
  reason: string;
  timestamp: string;
}

interface ModerationQueueItem {
  videoId: string;
  reportCount: number;
  reports: VideoReport[];
  videoMetadata?: any;
  firstReportedAt: string;
  lastReportedAt: string;
}

// Auto-hide threshold
const AUTO_HIDE_THRESHOLD = 5;

// Report rate limits (stricter than general API)
const REPORT_RATE_LIMITS = {
  windowMs: 3600000, // 1 hour
  maxRequests: 10,   // 10 reports per hour per user
};

/**
 * Handle POST /api/moderation/report
 * Submit a content report
 */
export async function handleReportSubmission(
  request: Request,
  env: Env,
  ctx: ExecutionContext
): Promise<Response> {
  try {
    // Check security (API key and rate limiting)
    const securityCheck = await checkSecurity(request, env);
    if (!securityCheck.allowed) {
      return applySecurityHeaders(securityCheck.response!);
    }

    // Additional rate limiting for reports
    const rateLimiter = new RateLimiter(env);
    const reportRateLimit = await rateLimiter.checkLimit(request, {
      ...REPORT_RATE_LIMITS,
      keyGenerator: () => `report:${securityCheck.apiKey || 'anonymous'}`,
    });

    if (!reportRateLimit.allowed) {
      return applySecurityHeaders(new Response(
        JSON.stringify({
          error: 'rate_limit_exceeded',
          message: 'Too many reports. Please try again later.',
          retryAfter: Math.ceil((reportRateLimit.resetTime - Date.now()) / 1000),
        }),
        {
          status: 429,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Retry-After': Math.ceil((reportRateLimit.resetTime - Date.now()) / 1000).toString(),
          },
        }
      ));
    }

    // Parse request body
    let body: ReportSubmission;
    try {
      body = await request.json();
    } catch (e) {
      return applySecurityHeaders(new Response(
        JSON.stringify({ error: 'Invalid request body' }),
        {
          status: 400,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
          },
        }
      ));
    }

    // Validate input
    if (!body.videoId || !body.reportType || !body.reason || !body.reporterPubkey) {
      return applySecurityHeaders(new Response(
        JSON.stringify({ error: 'Missing required fields' }),
        {
          status: 400,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
          },
        }
      ));
    }

    // Validate report type
    const validReportTypes = ['spam', 'illegal', 'harassment', 'other'];
    if (!validReportTypes.includes(body.reportType)) {
      return applySecurityHeaders(new Response(
        JSON.stringify({ error: 'Invalid report type' }),
        {
          status: 400,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
          },
        }
      ));
    }

    // Create report
    const report: VideoReport = {
      id: `${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
      videoId: body.videoId,
      reportType: body.reportType,
      reason: body.reason.substring(0, 500), // Limit reason length
      reporterPubkey: body.reporterPubkey,
      nostrEventId: body.nostrEventId,
      createdAt: new Date().toISOString(),
    };

    // Store report
    const reportKey = `report:${report.id}`;
    await env.METADATA_CACHE.put(reportKey, JSON.stringify(report), {
      expirationTtl: 86400 * 30, // 30 days
    });

    // Update video moderation status
    const statusKey = `moderation:${body.videoId}`;
    let status = await getModerationStatus(body.videoId, env);

    // Add this report to the count
    status.reportCount++;
    status.reportTypes = [...new Set([...status.reportTypes, body.reportType])];
    status.lastReportedAt = report.createdAt;

    // Check if we need to auto-hide
    if (status.reportCount >= AUTO_HIDE_THRESHOLD && !status.isHidden) {
      status.isHidden = true;
      status.moderationActions.push({
        action: 'hide',
        moderatorPubkey: 'system',
        reason: `Auto-hidden after ${AUTO_HIDE_THRESHOLD} reports`,
        timestamp: new Date().toISOString(),
      });

      console.log(`⚠️ Auto-hiding video ${body.videoId} after ${status.reportCount} reports`);
    }

    // Save updated status
    await env.METADATA_CACHE.put(statusKey, JSON.stringify(status), {
      expirationTtl: 86400 * 90, // 90 days
    });

    // Add report to video's report list
    const reportListKey = `reports:${body.videoId}`;
    const existingReports = await env.METADATA_CACHE.get(reportListKey, 'json') || [];
    existingReports.push(report);
    await env.METADATA_CACHE.put(reportListKey, JSON.stringify(existingReports), {
      expirationTtl: 86400 * 30, // 30 days
    });

    // Track analytics
    const analytics = new VideoAnalyticsService(env, ctx);
    ctx.waitUntil(
      analytics.trackEvent('content_report', {
        videoId: body.videoId,
        reportType: body.reportType,
        autoHidden: status.isHidden,
      })
    );

    console.log(`📋 Report submitted for video ${body.videoId}: ${body.reportType}`);

    return applySecurityHeaders(new Response(
      JSON.stringify({
        success: true,
        reportId: report.id,
        videoStatus: {
          reportCount: status.reportCount,
          isHidden: status.isHidden,
        },
      }),
      {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'POST, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type, Authorization',
        },
      }
    ));
  } catch (error) {
    console.error('❌ Error handling report submission:', error);
    
    return applySecurityHeaders(new Response(
      JSON.stringify({ error: 'Internal server error' }),
      {
        status: 500,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      }
    ));
  }
}

/**
 * Handle GET /api/moderation/status/{videoId}
 * Get moderation status for a video
 */
export async function handleModerationStatus(
  videoId: string,
  request: Request,
  env: Env
): Promise<Response> {
  try {
    // Check security
    const securityCheck = await checkSecurity(request, env);
    if (!securityCheck.allowed) {
      return applySecurityHeaders(securityCheck.response!);
    }

    const status = await getModerationStatus(videoId, env);

    return applySecurityHeaders(new Response(
      JSON.stringify(status),
      {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type, Authorization',
          'Cache-Control': 'public, max-age=60', // Cache for 1 minute
        },
      }
    ));
  } catch (error) {
    console.error('❌ Error getting moderation status:', error);
    
    return applySecurityHeaders(new Response(
      JSON.stringify({ error: 'Internal server error' }),
      {
        status: 500,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      }
    ));
  }
}

/**
 * Handle GET /api/moderation/queue
 * Get moderation queue (admin only)
 */
export async function handleModerationQueue(
  request: Request,
  env: Env
): Promise<Response> {
  try {
    // Check security - require admin privileges
    const securityCheck = await checkSecurity(request, env, true);
    if (!securityCheck.allowed) {
      return applySecurityHeaders(securityCheck.response!);
    }

    // Check if user is admin (simplified - in production, check against admin list)
    const isAdmin = await checkAdminPrivileges(securityCheck.apiKey!, env);
    if (!isAdmin) {
      return applySecurityHeaders(new Response(
        JSON.stringify({ error: 'Admin privileges required' }),
        {
          status: 403,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
          },
        }
      ));
    }

    // Get all reported videos
    const reportedVideos: ModerationQueueItem[] = [];
    
    // In production, this would scan KV more efficiently
    // For now, return sample data
    const sampleQueue: ModerationQueueItem[] = [{
      videoId: 'sample_video_123',
      reportCount: 3,
      reports: [],
      firstReportedAt: new Date(Date.now() - 86400000).toISOString(),
      lastReportedAt: new Date().toISOString(),
    }];

    return applySecurityHeaders(new Response(
      JSON.stringify({
        queue: sampleQueue,
        totalItems: sampleQueue.length,
        timestamp: new Date().toISOString(),
      }),
      {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type, Authorization',
          'Cache-Control': 'no-cache', // Don't cache admin data
        },
      }
    ));
  } catch (error) {
    console.error('❌ Error getting moderation queue:', error);
    
    return applySecurityHeaders(new Response(
      JSON.stringify({ error: 'Internal server error' }),
      {
        status: 500,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      }
    ));
  }
}

/**
 * Handle POST /api/moderation/action
 * Perform moderation action (admin only)
 */
export async function handleModerationAction(
  request: Request,
  env: Env,
  ctx: ExecutionContext
): Promise<Response> {
  try {
    // Check security - require admin privileges
    const securityCheck = await checkSecurity(request, env, true);
    if (!securityCheck.allowed) {
      return applySecurityHeaders(securityCheck.response!);
    }

    // Check admin privileges
    const isAdmin = await checkAdminPrivileges(securityCheck.apiKey!, env);
    if (!isAdmin) {
      return applySecurityHeaders(new Response(
        JSON.stringify({ error: 'Admin privileges required' }),
        {
          status: 403,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
          },
        }
      ));
    }

    // Parse request body
    let body: {
      videoId: string;
      action: 'hide' | 'unhide' | 'delete';
      moderatorPubkey: string;
      reason: string;
    };

    try {
      body = await request.json();
    } catch (e) {
      return applySecurityHeaders(new Response(
        JSON.stringify({ error: 'Invalid request body' }),
        {
          status: 400,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
          },
        }
      ));
    }

    // Validate input
    const validActions = ['hide', 'unhide', 'delete'];
    if (!body.videoId || !validActions.includes(body.action) || !body.reason) {
      return applySecurityHeaders(new Response(
        JSON.stringify({ error: 'Invalid input' }),
        {
          status: 400,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
          },
        }
      ));
    }

    // Get current status
    const status = await getModerationStatus(body.videoId, env);

    // Apply action
    switch (body.action) {
      case 'hide':
        status.isHidden = true;
        break;
      case 'unhide':
        status.isHidden = false;
        break;
      case 'delete':
        // Mark for deletion (actual deletion would be handled separately)
        status.isHidden = true;
        break;
    }

    // Record action
    status.moderationActions.push({
      action: body.action,
      moderatorPubkey: body.moderatorPubkey,
      reason: body.reason,
      timestamp: new Date().toISOString(),
    });

    // Save updated status
    const statusKey = `moderation:${body.videoId}`;
    await env.METADATA_CACHE.put(statusKey, JSON.stringify(status), {
      expirationTtl: 86400 * 90, // 90 days
    });

    // Track analytics
    const analytics = new VideoAnalyticsService(env, ctx);
    ctx.waitUntil(
      analytics.trackEvent('moderation_action', {
        videoId: body.videoId,
        action: body.action,
        moderator: body.moderatorPubkey,
      })
    );

    console.log(`🔨 Moderation action: ${body.action} on video ${body.videoId}`);

    return applySecurityHeaders(new Response(
      JSON.stringify({
        success: true,
        videoId: body.videoId,
        action: body.action,
        newStatus: status,
      }),
      {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'POST, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type, Authorization',
        },
      }
    ));
  } catch (error) {
    console.error('❌ Error performing moderation action:', error);
    
    return applySecurityHeaders(new Response(
      JSON.stringify({ error: 'Internal server error' }),
      {
        status: 500,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      }
    ));
  }
}

/**
 * Handle OPTIONS preflight for CORS
 */
export function handleModerationOptions(): Response {
  return new Response(null, {
    status: 204,
    headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
      'Access-Control-Max-Age': '86400',
    },
  });
}

/**
 * Helper: Get moderation status for a video
 */
async function getModerationStatus(videoId: string, env: Env): Promise<VideoModerationStatus> {
  const statusKey = `moderation:${videoId}`;
  const existingStatus = await env.METADATA_CACHE.get(statusKey, 'json');

  if (existingStatus) {
    return existingStatus as VideoModerationStatus;
  }

  // Return default status
  return {
    videoId,
    reportCount: 0,
    isHidden: false,
    reportTypes: [],
    moderationActions: [],
  };
}

/**
 * Helper: Check if API key has admin privileges
 */
async function checkAdminPrivileges(apiKey: string, env: Env): Promise<boolean> {
  // In production, check against admin list in KV
  // For now, check for special admin key
  const adminKeys = ['admin-api-key', 'test-admin-key'];
  return adminKeys.includes(apiKey) || env.ENVIRONMENT === 'development';
}