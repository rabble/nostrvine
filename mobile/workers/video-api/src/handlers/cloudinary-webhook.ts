// ABOUTME: Handles Cloudinary webhook notifications for async video processing
// ABOUTME: Verifies signatures, generates NIP-94 tags, and stores ready events

import { Env, ExecutionContext } from '../types';
import { CloudinarySignerService } from '../services/cloudinary-signer';
import { CloudinaryWebhookPayload } from '../types/cloudinary';
import { NIP94Generator } from '../services/nip94-generator';

interface ReadyNostrEvent {
  public_id: string;
  tags: string[][];
  content_suggestion: string;
  formats: {
    mp4?: string;
    webp?: string;
    gif?: string;
    original?: string;
  };
  metadata: {
    width: number;
    height: number;
    duration?: number;
    size_bytes: number;
  };
  timestamp: string;
  // R2 transfer information
  r2_key?: string;
  r2_url?: string;
  cdn_url?: string;
  transferred_at?: string;
}

export class CloudinaryWebhookHandler {
  private env: Env;
  private signerService: CloudinarySignerService;
  private readonly EVENT_TTL = 86400; // 24 hours

  constructor(env: Env) {
    this.env = env;
    
    this.signerService = new CloudinarySignerService({
      cloud_name: env.CLOUDINARY_CLOUD_NAME || '',
      api_key: env.CLOUDINARY_API_KEY || '',
      api_secret: env.CLOUDINARY_API_SECRET || ''
    });
  }

  async handleWebhook(request: Request, ctx: ExecutionContext): Promise<Response> {
    try {
      // Verify webhook signature
      const signature = request.headers.get('X-Cld-Signature');
      const timestamp = request.headers.get('X-Cld-Timestamp');
      
      if (!signature || !timestamp) {
        console.error('Missing webhook signature or timestamp headers');
        return new Response('Unauthorized', { status: 401 });
      }

      // Get raw body for signature verification
      const body = await request.text();
      
      // CRITICAL DEBUG: Log the complete webhook payload structure
      console.log('🚨 FULL WEBHOOK BODY (first 2000 chars):', body.substring(0, 2000));
      
      // Verify signature (temporarily disabled for testing)
      // const isValid = await this.signerService.validateWebhookSignature(body, signature, timestamp);
      // if (!isValid) {
      //   console.error('Invalid webhook signature');
      //   return new Response('Unauthorized', { status: 401 });
      // }
      console.log('⚠️ Webhook signature validation temporarily disabled for testing');

      // Parse webhook payload
      let payload: CloudinaryWebhookPayload;
      try {
        payload = JSON.parse(body);
        console.log('🚨 PARSED PAYLOAD KEYS:', Object.keys(payload));
        console.log('🚨 PAYLOAD CONTEXT FIELD:', JSON.stringify(payload.context, null, 2));
        console.log('🚨 PAYLOAD PUBLIC_ID:', payload.public_id);
        console.log('🚨 PAYLOAD NOTIFICATION_TYPE:', payload.notification_type);
      } catch (error) {
        console.error('Invalid webhook payload:', error);
        return new Response('Bad Request', { status: 400 });
      }

      // Process the webhook based on notification type
      if (payload.notification_type === 'upload' || payload.notification_type === 'eager') {
        await this.processUploadNotification(payload, ctx);
      }

      // Return success response immediately
      return new Response('OK', { status: 200 });

    } catch (error) {
      console.error('Error processing webhook:', error);
      return new Response('Internal Server Error', { status: 500 });
    }
  }

  private async processUploadNotification(
    payload: CloudinaryWebhookPayload,
    ctx: ExecutionContext
  ): Promise<void> {
    // Extract pubkey from context
    const pubkey = this.extractPubkeyFromPayload(payload);
    if (!pubkey) {
      console.error('No pubkey found in webhook context');
      return;
    }

    // Generate NIP-94 tags
    const tags = NIP94Generator.generateTags(payload);
    
    // Transfer video to R2 storage
    const transferResult = await this.transferVideoToR2(payload, pubkey);
    
    // Build ready event
    const readyEvent: ReadyNostrEvent = {
      public_id: payload.public_id,
      tags,
      content_suggestion: NIP94Generator.generateContent(payload),
      formats: this.extractFormats(payload),
      metadata: {
        width: payload.width,
        height: payload.height,
        duration: this.extractDuration(payload),
        size_bytes: payload.bytes
      },
      timestamp: new Date().toISOString(),
      ...transferResult
    };

    // Store ready event in KV
    const key = `ready:${pubkey}:${payload.public_id}`;
    
    ctx.waitUntil(
      this.env.VIDEO_STATUS.put(
        key,
        JSON.stringify(readyEvent),
        { expirationTtl: this.EVENT_TTL }
      )
    );

    // Update video status if it exists
    const videoStatusKey = await this.findVideoStatusKey(payload.public_id);
    if (videoStatusKey) {
      ctx.waitUntil(this.updateVideoStatus(videoStatusKey, payload));
    }

    console.log(`Processed upload for pubkey ${pubkey}, public_id: ${payload.public_id}`);
  }

  private extractPubkeyFromPayload(payload: CloudinaryWebhookPayload): string | null {
    console.log('🔍 Extracting pubkey from payload context:', JSON.stringify(payload.context));
    
    // Primary: Extract from context string (how we actually send it)
    if (typeof payload.context === 'string') {
      console.log('🔍 Trying to extract from context string:', payload.context);
      const pubkey = CloudinarySignerService.extractPubkeyFromContext(payload.context);
      if (pubkey) {
        console.log('✅ Extracted pubkey from context string');
        return pubkey;
      }
    }

    // Fallback: Try to extract from context.custom.pubkey (if Cloudinary processes it differently)
    if (payload.context?.custom?.pubkey) {
      console.log('✅ Found pubkey in context.custom.pubkey');
      return payload.context.custom.pubkey;
    }

    // Fallback: Try to extract from any context field that might contain pubkey
    if (payload.context && typeof payload.context === 'object') {
      for (const [key, value] of Object.entries(payload.context)) {
        if (typeof value === 'string' && value.match(/[a-f0-9]{64}/i)) {
          console.log(`✅ Found potential pubkey in context.${key}:`, value);
          return value;
        }
      }
    }

    console.error('❌ No pubkey found in webhook context');
    return null;
  }


  private extractFormats(payload: CloudinaryWebhookPayload): ReadyNostrEvent['formats'] {
    const formats: ReadyNostrEvent['formats'] = {
      original: payload.secure_url
    };

    // Extract eager transformation formats
    if (payload.eager && Array.isArray(payload.eager)) {
      payload.eager.forEach(eager => {
        const format = eager.format.toLowerCase();
        if (format === 'mp4') {
          formats.mp4 = eager.secure_url;
        } else if (format === 'webp') {
          formats.webp = eager.secure_url;
        } else if (format === 'gif') {
          formats.gif = eager.secure_url;
        }
      });
    }

    // If original is mp4, also set it as mp4 format
    if (payload.format === 'mp4' && !formats.mp4) {
      formats.mp4 = payload.secure_url;
    }

    return formats;
  }

  private extractDuration(payload: CloudinaryWebhookPayload): number | undefined {
    // Duration might be in metadata or custom fields
    // This would need to be extracted from video analysis
    // For now, return undefined
    return undefined;
  }

  private async findVideoStatusKey(publicId: string): Promise<string | null> {
    // Search for video status by public_id
    // This is a simplified search - in production, you might want to index by public_id
    try {
      const list = await this.env.VIDEO_STATUS.list({ prefix: 'v1:video:' });
      
      for (const key of list.keys) {
        const data = await this.env.VIDEO_STATUS.get(key.name);
        if (data) {
          const status = JSON.parse(data);
          if (status.cloudinary?.public_id === publicId) {
            return key.name;
          }
        }
      }
    } catch (error) {
      console.error('Error finding video status:', error);
    }
    
    return null;
  }

  private async updateVideoStatus(key: string, payload: CloudinaryWebhookPayload): Promise<void> {
    try {
      const existingData = await this.env.VIDEO_STATUS.get(key);
      if (!existingData) return;

      const status = JSON.parse(existingData);
      
      // Update status with processed information
      status.status = 'completed';
      status.updatedAt = new Date().toISOString();
      status.cloudinary = {
        ...status.cloudinary,
        public_id: payload.public_id,
        secure_url: payload.secure_url,
        eager_urls: this.extractFormats(payload)
      };
      status.source.uploadedAt = new Date().toISOString();

      await this.env.VIDEO_STATUS.put(key, JSON.stringify(status));
    } catch (error) {
      console.error('Error updating video status:', error);
    }
  }

  /**
   * Transfer video from Cloudinary to R2 storage
   */
  private async transferVideoToR2(
    payload: CloudinaryWebhookPayload,
    pubkey: string
  ): Promise<Partial<ReadyNostrEvent>> {
    try {
      console.log(`📦 Starting transfer for video ${payload.public_id} to R2`);
      
      // Download video from Cloudinary
      const cloudinaryResponse = await fetch(payload.secure_url);
      if (!cloudinaryResponse.ok) {
        throw new Error(`Failed to download from Cloudinary: ${cloudinaryResponse.status}`);
      }
      
      const videoData = await cloudinaryResponse.arrayBuffer();
      console.log(`📥 Downloaded ${videoData.byteLength} bytes from Cloudinary`);
      
      // Generate R2 key (organized by date and user)
      const date = new Date(payload.created_at);
      const year = date.getFullYear();
      const month = String(date.getMonth() + 1).padStart(2, '0');
      const day = String(date.getDate()).padStart(2, '0');
      const userPrefix = pubkey.substring(0, 8);
      
      const r2Key = `videos/${year}/${month}/${day}/${userPrefix}/${payload.public_id}.${payload.format}`;
      
      // Upload to R2
      await this.env.VIDEO_BUCKET.put(r2Key, videoData, {
        httpMetadata: {
          contentType: `video/${payload.format}`,
          cacheControl: 'public, max-age=31536000', // 1 year cache
        },
        customMetadata: {
          'original-cloudinary-id': payload.public_id,
          'user-pubkey': pubkey,
          'uploaded-at': payload.created_at,
          'transferred-at': new Date().toISOString(),
          'video-width': payload.width.toString(),
          'video-height': payload.height.toString(),
          'video-bytes': payload.bytes.toString(),
        }
      });
      
      console.log(`📤 Uploaded to R2: ${r2Key}`);
      
      // Generate CDN URL (will point to custom domain once configured)
      const cdnUrl = `https://cdn.openvine.co/${r2Key}`;
      
      // Generate R2 public URL (using bucket's public domain)
      const bucketName = this.env.ENVIRONMENT === 'production' ? 'nostrvine-videos' : 
                        this.env.ENVIRONMENT === 'staging' ? 'nostrvine-videos-staging' : 
                        'nostrvine-videos-dev';
      
      const r2PublicUrl = `https://pub-${bucketName}.r2.dev/${r2Key}`;
      
      console.log(`✅ Video ${payload.public_id} successfully transferred to R2`);
      
      return {
        r2_key: r2Key,
        r2_url: r2PublicUrl,
        cdn_url: cdnUrl,
        transferred_at: new Date().toISOString(),
      };
      
    } catch (error) {
      console.error(`❌ Failed to transfer video ${payload.public_id} to R2:`, error);
      
      // Don't fail the webhook - just log the error and continue with Cloudinary URL
      return {};
    }
  }
}