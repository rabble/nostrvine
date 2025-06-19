// ABOUTME: Cloudflare Stream webhook handler for video processing completion
// ABOUTME: Updates video status and triggers content moderation pipeline

/**
 * Handle POST /v1/webhooks/stream-complete - Cloudflare Stream webhook
 */
export async function handleStreamWebhook(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
  try {
    // Get request body for signature validation
    const body = await request.text();
    
    // Validate webhook signature
    const signatureValid = await validateWebhookSignature(request, body, env);
    if (!signatureValid) {
      console.error('Invalid webhook signature');
      return new Response('Unauthorized', { status: 401 });
    }

    // Parse webhook payload
    let payload: StreamWebhookPayload;
    try {
      payload = JSON.parse(body);
    } catch (e) {
      console.error('Invalid JSON in webhook payload');
      return new Response('Bad Request', { status: 400 });
    }

    const videoId = payload.uid;
    console.log(`Processing Stream webhook for video ${videoId}`);

    // Get current video status (idempotency check)
    const existingStatus = await env.METADATA_CACHE.get(`v1:video:${videoId}`);
    if (!existingStatus) {
      console.warn(`Webhook for unknown video: ${videoId}`);
      return new Response('Video not found', { status: 404 });
    }

    const videoStatus = JSON.parse(existingStatus);

    // Idempotency: Skip if already in final state
    if (['published', 'quarantined', 'failed'].includes(videoStatus.status)) {
      console.log(`Video ${videoId} already processed (${videoStatus.status}), skipping`);
      return new Response('OK - Already processed', { status: 200 });
    }

    // Check if video processing succeeded
    if (!payload.readyToStream || payload.status?.state !== 'ready') {
      console.error(`Video processing failed for ${videoId}:`, payload.status);
      
      // Mark as failed
      videoStatus.status = 'failed';
      videoStatus.source.error = `Stream processing failed: ${payload.status?.errorReasonText || 'Unknown error'}`;
      videoStatus.updatedAt = new Date().toISOString();
      
      await env.METADATA_CACHE.put(`v1:video:${videoId}`, JSON.stringify(videoStatus));
      return new Response('OK', { status: 200 });
    }

    // Update video status with Stream URLs
    videoStatus.status = 'processing';
    videoStatus.updatedAt = new Date().toISOString();
    videoStatus.source.uploadedAt = payload.created;
    videoStatus.stream.hlsUrl = payload.playback?.hls || null;
    videoStatus.stream.dashUrl = payload.playback?.dash || null;
    videoStatus.stream.thumbnailUrl = payload.thumbnail || null;

    // Save updated status
    await env.METADATA_CACHE.put(`v1:video:${videoId}`, JSON.stringify(videoStatus));

    // Trigger moderation asynchronously (don't block webhook response)
    ctx.waitUntil(runModerationChecks(videoStatus, env));

    console.log(`Video ${videoId} processing complete, moderation queued`);
    return new Response('OK', { status: 200 });

  } catch (error) {
    console.error('Stream webhook processing error:', error);
    
    // Return 200 to prevent Cloudflare retries for unrecoverable errors
    return new Response(`Processing failed: ${error}`, { status: 200 });
  }
}

/**
 * Handle OPTIONS /v1/webhooks/stream-complete
 */
export function handleStreamWebhookOptions(): Response {
  return new Response(null, {
    status: 204,
    headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Webhook-Signature',
      'Access-Control-Max-Age': '86400'
    }
  });
}

/**
 * Validate webhook signature using HMAC-SHA256
 */
async function validateWebhookSignature(request: Request, body: string, env: Env): Promise<boolean> {
  try {
    const signature = request.headers.get('webhook-signature');
    if (!signature) {
      console.error('Missing webhook-signature header');
      return false;
    }
    
    // Parse Cloudflare's signature format: "time=timestamp,sig1=hash"
    const parts = signature.split(',');
    let timestamp = '';
    let receivedSig = '';
    
    for (const part of parts) {
      if (part.startsWith('time=')) {
        timestamp = part.substring(5);
      } else if (part.startsWith('sig1=')) {
        receivedSig = part.substring(5);
      }
    }
    
    if (!timestamp || !receivedSig) {
      console.error('Invalid signature format');
      return false;
    }
    
    // Verify timestamp is recent (within 5 minutes)
    const now = Math.floor(Date.now() / 1000);
    const webhookTime = parseInt(timestamp);
    if (Math.abs(now - webhookTime) > 300) {
      console.error('Webhook timestamp too old or in future');
      return false;
    }
    
    // Calculate expected signature using Cloudflare's format: timestamp + body
    const message = timestamp + body;
    const key = await crypto.subtle.importKey(
      'raw',
      new TextEncoder().encode(env.STREAM_WEBHOOK_SECRET),
      { name: 'HMAC', hash: 'SHA-256' },
      false,
      ['sign']
    );

    const expectedSignature = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(message));
    const expectedHex = Array.from(new Uint8Array(expectedSignature))
      .map(b => b.toString(16).padStart(2, '0'))
      .join('');
    
    return expectedHex === receivedSig;

  } catch (error) {
    console.error('Signature validation error:', error);
    return false;
  }
}

/**
 * Run content moderation checks (Phase 1: Auto-approve)
 */
async function runModerationChecks(videoStatus: any, env: Env): Promise<void> {
  try {
    console.log(`Starting moderation for video ${videoStatus.videoId}`);
    
    // Phase 1: Auto-approve all content for MVP
    videoStatus.status = 'published';
    videoStatus.moderation.status = 'approved';
    videoStatus.moderation.checkedAt = new Date().toISOString();
    videoStatus.updatedAt = new Date().toISOString();
    
    await env.METADATA_CACHE.put(`v1:video:${videoStatus.videoId}`, JSON.stringify(videoStatus));
    
    console.log(`Video ${videoStatus.videoId} auto-approved and published`);
    
  } catch (error) {
    console.error(`Moderation failed for ${videoStatus.videoId}:`, error);
    
    // Mark as failed if moderation pipeline crashes
    videoStatus.status = 'failed';
    videoStatus.source.error = `Moderation pipeline error: ${error}`;
    videoStatus.updatedAt = new Date().toISOString();
    
    await env.METADATA_CACHE.put(`v1:video:${videoStatus.videoId}`, JSON.stringify(videoStatus));
  }
}

// Type definitions
interface StreamWebhookPayload {
  uid: string;
  readyToStream: boolean;
  status: {
    state: string;
    pctComplete: string;
    errorReasonCode?: string;
    errorReasonText?: string;
  };
  meta: {
    name: string;
  };
  created: string;
  modified: string;
  playback?: {
    hls: string;
    dash: string;
  };
  thumbnail?: string;
  thumbnailTimestampPct: number;
}