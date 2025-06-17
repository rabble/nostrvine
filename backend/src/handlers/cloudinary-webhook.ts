// ABOUTME: Cloudinary webhook handler for processing completion notifications
// ABOUTME: Receives async processing results and prepares NIP-94 metadata for client retrieval

import { validateWebhookSignature } from '../utils/webhook-validation';

export interface CloudinaryWebhookPayload {
  notification_type: string;
  timestamp: number;
  request_id: string;
  asset_id: string;
  public_id: string;
  version: number;
  version_id: string;
  width: number;
  height: number;
  format: string;
  resource_type: string;
  created_at: string;
  bytes: number;
  type: string;
  etag: string;
  placeholder: boolean;
  url: string;
  secure_url: string;
  folder: string;
  original_filename: string;
  api_key: string;
  context?: {
    custom: {
      pubkey?: string;
      app?: string;
      version?: string;
    };
  };
  eager?: Array<{
    transformation: string;
    width: number;
    height: number;
    bytes: number;
    format: string;
    url: string;
    secure_url: string;
  }>;
  signature: string;
}

export interface ProcessedVideoMetadata {
  public_id: string;
  secure_url: string;
  format: string;
  width: number;
  height: number;
  bytes: number;
  duration?: number;
  resource_type: string;
  created_at: string;
  user_pubkey: string;
  processing_status: 'completed' | 'failed';
  eager_transformations?: Array<{
    transformation: string;
    url: string;
    format: string;
    bytes: number;
  }>;
}

/**
 * Handle Cloudinary webhook notifications
 * POST /v1/media/webhook
 */
export async function handleCloudinaryWebhook(
  request: Request,
  env: Env
): Promise<Response> {
  try {
    // Validate webhook signature
    const body = await request.text();
    const signature = request.headers.get('X-Cld-Signature');
    
    if (!signature) {
      console.warn('⚠️ Webhook received without signature');
      return new Response('Missing webhook signature', { status: 400 });
    }

    const isValidSignature = await validateWebhookSignature(
      body,
      signature,
      env.WEBHOOK_SECRET
    );

    if (!isValidSignature) {
      console.warn('⚠️ Webhook signature validation failed');
      return new Response('Invalid webhook signature', { status: 401 });
    }

    // Parse webhook payload
    let payload: CloudinaryWebhookPayload;
    try {
      payload = JSON.parse(body);
    } catch (e) {
      console.error('❌ Failed to parse webhook payload:', e);
      return new Response('Invalid JSON payload', { status: 400 });
    }

    console.log(`📨 Received webhook for ${payload.notification_type} - ${payload.public_id}`);

    // Process different notification types
    switch (payload.notification_type) {
      case 'upload':
        return await handleUploadComplete(payload, env);
      case 'eager':
        return await handleEagerTransformationComplete(payload, env);
      case 'error':
        return await handleProcessingError(payload, env);
      default:
        console.log(`ℹ️ Ignoring webhook type: ${payload.notification_type}`);
        return new Response('OK', { status: 200 });
    }

  } catch (error) {
    console.error('❌ Webhook processing error:', error);
    return new Response('Internal server error', { status: 500 });
  }
}

/**
 * Handle successful upload completion
 */
async function handleUploadComplete(
  payload: CloudinaryWebhookPayload,
  env: Env
): Promise<Response> {
  try {
    // Extract user pubkey from context
    const userPubkey = payload.context?.custom?.pubkey;
    if (!userPubkey) {
      console.warn(`⚠️ Upload completed but no user pubkey in context for ${payload.public_id}`);
      return new Response('Missing user context', { status: 400 });
    }

    // Create metadata for the processed video
    const metadata: ProcessedVideoMetadata = {
      public_id: payload.public_id,
      secure_url: payload.secure_url,
      format: payload.format,
      width: payload.width,
      height: payload.height,
      bytes: payload.bytes,
      resource_type: payload.resource_type,
      created_at: payload.created_at,
      user_pubkey: userPubkey,
      processing_status: 'completed'
    };

    // Store metadata in KV for client retrieval
    const metadataKey = `video_metadata:${payload.public_id}`;
    await env.METADATA_CACHE.put(metadataKey, JSON.stringify(metadata), {
      expirationTtl: 86400 * 7 // 7 days
    });

    // Store user's video list for easier querying
    const userVideosKey = `user_videos:${userPubkey}`;
    const existingVideos = await env.METADATA_CACHE.get(userVideosKey);
    let videosList: string[] = [];
    
    if (existingVideos) {
      try {
        videosList = JSON.parse(existingVideos);
      } catch (e) {
        console.warn('Failed to parse existing videos list, starting fresh');
      }
    }

    // Add new video to the list (most recent first)
    videosList.unshift(payload.public_id);
    
    // Keep only the last 100 videos per user to manage storage
    if (videosList.length > 100) {
      videosList = videosList.slice(0, 100);
    }

    await env.METADATA_CACHE.put(userVideosKey, JSON.stringify(videosList), {
      expirationTtl: 86400 * 30 // 30 days
    });

    console.log(`✅ Stored metadata for video ${payload.public_id} by user ${userPubkey.substring(0, 8)}...`);

    return new Response('Upload processed successfully', { status: 200 });

  } catch (error) {
    console.error('❌ Error processing upload completion:', error);
    return new Response('Failed to process upload', { status: 500 });
  }
}

/**
 * Handle eager transformation completion
 */
async function handleEagerTransformationComplete(
  payload: CloudinaryWebhookPayload,
  env: Env
): Promise<Response> {
  try {
    if (!payload.eager || payload.eager.length === 0) {
      return new Response('No eager transformations found', { status: 400 });
    }

    // Update existing metadata with eager transformation URLs
    const metadataKey = `video_metadata:${payload.public_id}`;
    const existingMetadata = await env.METADATA_CACHE.get(metadataKey);
    
    if (!existingMetadata) {
      console.warn(`⚠️ Eager transformation completed but no metadata found for ${payload.public_id}`);
      return new Response('Metadata not found', { status: 404 });
    }

    let metadata: ProcessedVideoMetadata;
    try {
      metadata = JSON.parse(existingMetadata);
    } catch (e) {
      console.error('Failed to parse existing metadata');
      return new Response('Invalid metadata format', { status: 500 });
    }

    // Add eager transformation URLs
    metadata.eager_transformations = payload.eager.map(eager => ({
      transformation: eager.transformation,
      url: eager.secure_url,
      format: eager.format,
      bytes: eager.bytes
    }));

    // Update metadata in KV
    await env.METADATA_CACHE.put(metadataKey, JSON.stringify(metadata), {
      expirationTtl: 86400 * 7 // 7 days
    });

    console.log(`✅ Updated metadata with ${payload.eager.length} transformations for ${payload.public_id}`);

    return new Response('Eager transformations processed', { status: 200 });

  } catch (error) {
    console.error('❌ Error processing eager transformations:', error);
    return new Response('Failed to process transformations', { status: 500 });
  }
}

/**
 * Handle processing errors
 */
async function handleProcessingError(
  payload: CloudinaryWebhookPayload,
  env: Env
): Promise<Response> {
  try {
    // Extract user pubkey from context if available
    const userPubkey = payload.context?.custom?.pubkey;

    // Create error metadata
    const errorMetadata: ProcessedVideoMetadata = {
      public_id: payload.public_id,
      secure_url: '', // No URL for failed processing
      format: payload.format || 'unknown',
      width: 0,
      height: 0,
      bytes: 0,
      resource_type: payload.resource_type || 'video',
      created_at: payload.created_at || new Date().toISOString(),
      user_pubkey: userPubkey || 'unknown',
      processing_status: 'failed'
    };

    // Store error metadata
    const metadataKey = `video_metadata:${payload.public_id}`;
    await env.METADATA_CACHE.put(metadataKey, JSON.stringify(errorMetadata), {
      expirationTtl: 86400 * 3 // 3 days for failed processing
    });

    console.log(`❌ Stored error metadata for failed processing: ${payload.public_id}`);

    return new Response('Error processed', { status: 200 });

  } catch (error) {
    console.error('❌ Error processing webhook error:', error);
    return new Response('Failed to process error', { status: 500 });
  }
}

/**
 * Handle OPTIONS preflight for CORS
 */
export function handleCloudinaryWebhookOptions(): Response {
  return new Response(null, {
    status: 204,
    headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, X-Cld-Signature',
      'Access-Control-Max-Age': '86400'
    }
  });
}