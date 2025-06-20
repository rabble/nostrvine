// ABOUTME: Security and rate limiting implementation for video API protection
// ABOUTME: Provides API key validation, rate limiting, and security headers

interface RateLimitConfig {
  windowMs: number;
  maxRequests: number;
  keyGenerator: (request: Request) => string;
}

interface SecurityLog {
  timestamp: number;
  ip: string;
  userAgent: string;
  endpoint: string;
  apiKey?: string;
  blocked: boolean;
  reason?: string;
}

// Rate limit configurations
export const RATE_LIMITS = {
  video_api: { windowMs: 3600000, maxRequests: 1000 }, // 1000/hour
  batch_api: { windowMs: 3600000, maxRequests: 500 },  // 500/hour for batch
  burst: { windowMs: 60000, maxRequests: 50 },         // 50/minute burst protection
};

// Security headers to apply to all responses
export const SECURITY_HEADERS = {
  'X-Content-Type-Options': 'nosniff',
  'X-Frame-Options': 'DENY',
  'X-XSS-Protection': '1; mode=block',
  'Referrer-Policy': 'strict-origin-when-cross-origin',
  'Content-Security-Policy': "default-src 'self'",
};

/**
 * Rate limiter using KV storage
 */
export class RateLimiter {
  constructor(private env: Env) {}

  async checkLimit(request: Request, config: RateLimitConfig): Promise<{ allowed: boolean; remaining: number; resetTime: number }> {
    const key = config.keyGenerator(request);
    const window = Math.floor(Date.now() / config.windowMs);
    const countKey = `rate_limit:${key}:${window}`;
    
    const current = await this.env.METADATA_CACHE.get(countKey);
    const count = current ? parseInt(current) : 0;
    
    const remaining = Math.max(0, config.maxRequests - count - 1);
    const resetTime = (window + 1) * config.windowMs;
    
    if (count >= config.maxRequests) {
      return { allowed: false, remaining: 0, resetTime };
    }
    
    // Increment counter
    await this.env.METADATA_CACHE.put(countKey, (count + 1).toString(), {
      expirationTtl: Math.ceil(config.windowMs / 1000),
    });
    
    return { allowed: true, remaining, resetTime };
  }
}

/**
 * Extract client IP from request
 */
export function getClientIp(request: Request): string {
  return request.headers.get('CF-Connecting-IP') || 
         request.headers.get('X-Forwarded-For')?.split(',')[0].trim() || 
         'unknown';
}

/**
 * Validate API key from Authorization header
 */
export async function validateApiKey(request: Request, env: Env): Promise<{ valid: boolean; apiKey?: string }> {
  const authHeader = request.headers.get('Authorization');
  
  if (!authHeader?.startsWith('Bearer ')) {
    return { valid: false };
  }
  
  const apiKey = authHeader.substring(7).trim();
  
  if (!apiKey) {
    return { valid: false };
  }
  
  // Check if API key exists in KV
  const keyData = await env.METADATA_CACHE.get(`api_key:${apiKey}`);
  
  if (!keyData) {
    // For development, accept test key
    if (env.ENVIRONMENT === 'development' && apiKey === 'test-api-key') {
      return { valid: true, apiKey };
    }
    return { valid: false };
  }
  
  try {
    const parsed = JSON.parse(keyData);
    // Check if key is active and not expired
    if (parsed.active && (!parsed.expiresAt || Date.now() < parsed.expiresAt)) {
      return { valid: true, apiKey };
    }
  } catch (e) {
    console.error('Invalid API key data:', e);
  }
  
  return { valid: false };
}

/**
 * Generate rate limit key based on API key or IP
 */
export function generateRateLimitKey(request: Request, apiKey?: string): string {
  if (apiKey) {
    return `api:${apiKey}`;
  }
  return `ip:${getClientIp(request)}`;
}

/**
 * Log security events for monitoring
 */
export async function logSecurityEvent(event: SecurityLog, env: Env): Promise<void> {
  console.log(`[SECURITY] ${JSON.stringify(event)}`);
  
  // Store recent security events in KV for analysis
  const key = `security_log:${Date.now()}:${Math.random()}`;
  await env.METADATA_CACHE.put(key, JSON.stringify(event), {
    expirationTtl: 86400, // Keep logs for 24 hours
  });
}

/**
 * Apply security headers to response
 */
export function applySecurityHeaders(response: Response): Response {
  const newHeaders = new Headers(response.headers);
  
  for (const [key, value] of Object.entries(SECURITY_HEADERS)) {
    newHeaders.set(key, value);
  }
  
  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers: newHeaders,
  });
}

/**
 * Create rate limit error response
 */
export function createRateLimitResponse(remaining: number, resetTime: number): Response {
  const retryAfter = Math.ceil((resetTime - Date.now()) / 1000);
  
  return new Response(
    JSON.stringify({
      error: 'rate_limit_exceeded',
      message: 'Too many requests. Please try again later.',
      retryAfter,
      limit: RATE_LIMITS.video_api.maxRequests,
      remaining,
    }),
    {
      status: 429,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization',
        'Retry-After': retryAfter.toString(),
        'X-RateLimit-Limit': RATE_LIMITS.video_api.maxRequests.toString(),
        'X-RateLimit-Remaining': remaining.toString(),
        'X-RateLimit-Reset': (resetTime / 1000).toString(),
      },
    }
  );
}

/**
 * Middleware to check security for protected endpoints
 */
export async function checkSecurity(
  request: Request,
  env: Env,
  requireAuth: boolean = true
): Promise<{ allowed: boolean; response?: Response; apiKey?: string }> {
  const url = new URL(request.url);
  const path = url.pathname;
  
  // Check API key if required
  let apiKey: string | undefined;
  if (requireAuth) {
    const authResult = await validateApiKey(request, env);
    if (!authResult.valid) {
      await logSecurityEvent({
        timestamp: Date.now(),
        ip: getClientIp(request),
        userAgent: request.headers.get('User-Agent') || 'unknown',
        endpoint: path,
        blocked: true,
        reason: 'invalid_api_key',
      }, env);
      
      return {
        allowed: false,
        response: new Response(
          JSON.stringify({
            error: 'unauthorized',
            message: 'Invalid or missing API key',
          }),
          {
            status: 401,
            headers: {
              'Content-Type': 'application/json',
              'Access-Control-Allow-Origin': '*',
              'WWW-Authenticate': 'Bearer',
            },
          }
        ),
      };
    }
    apiKey = authResult.apiKey;
  }
  
  // Check rate limits
  const rateLimiter = new RateLimiter(env);
  const rateLimitKey = generateRateLimitKey(request, apiKey);
  
  // Check burst protection first
  const burstConfig = {
    ...RATE_LIMITS.burst,
    keyGenerator: () => rateLimitKey,
  };
  
  const burstResult = await rateLimiter.checkLimit(request, burstConfig);
  if (!burstResult.allowed) {
    await logSecurityEvent({
      timestamp: Date.now(),
      ip: getClientIp(request),
      userAgent: request.headers.get('User-Agent') || 'unknown',
      endpoint: path,
      apiKey,
      blocked: true,
      reason: 'burst_rate_limit',
    }, env);
    
    return {
      allowed: false,
      response: createRateLimitResponse(burstResult.remaining, burstResult.resetTime),
    };
  }
  
  // Check endpoint-specific rate limit
  const endpointConfig = path.includes('/batch') ? RATE_LIMITS.batch_api : RATE_LIMITS.video_api;
  const limitConfig = {
    ...endpointConfig,
    keyGenerator: () => rateLimitKey,
  };
  
  const result = await rateLimiter.checkLimit(request, limitConfig);
  if (!result.allowed) {
    await logSecurityEvent({
      timestamp: Date.now(),
      ip: getClientIp(request),
      userAgent: request.headers.get('User-Agent') || 'unknown',
      endpoint: path,
      apiKey,
      blocked: true,
      reason: 'hourly_rate_limit',
    }, env);
    
    return {
      allowed: false,
      response: createRateLimitResponse(result.remaining, result.resetTime),
    };
  }
  
  return { allowed: true, apiKey };
}