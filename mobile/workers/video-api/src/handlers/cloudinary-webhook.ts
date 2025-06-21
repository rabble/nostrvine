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
      
      // Verify signature
      const isValid = await this.signerService.validateWebhookSignature(body, signature, timestamp);
      if (!isValid) {
        console.error('Invalid webhook signature');
        return new Response('Unauthorized', { status: 401 });
      }

      // Parse webhook payload
      let payload: CloudinaryWebhookPayload;
      try {
        payload = JSON.parse(body);
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
      timestamp: new Date().toISOString()
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
    // Try to extract from context
    if (payload.context?.custom?.pubkey) {
      return payload.context.custom.pubkey;
    }

    // Try to extract from context string
    if (typeof payload.context === 'string') {
      return CloudinarySignerService.extractPubkeyFromContext(payload.context);
    }

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
}