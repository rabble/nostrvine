// ABOUTME: Cloudinary signature generation service for secure uploads
// ABOUTME: Handles signed upload parameter generation and validation

import { CloudinaryConfig, CloudinarySignatureParams, SignedUploadResponse } from '../types/cloudinary';

export class CloudinarySignerService {
  private config: CloudinaryConfig;
  private workerUrl?: string;

  constructor(config: CloudinaryConfig, workerUrl?: string) {
    this.config = config;
    this.workerUrl = workerUrl;
  }

  /**
   * Generates signed upload parameters for Cloudinary
   * @param pubkey - User's Nostr public key
   * @param options - Upload configuration options
   * @returns Signed upload parameters for client
   */
  async generateSignedUploadParams(
    pubkey: string,
    options: {
      fileType?: string;
      maxFileSize?: number;
      resourceType?: 'video' | 'image' | 'auto';
    } = {}
  ): Promise<SignedUploadResponse> {
    const timestamp = Math.floor(Date.now() / 1000);
    
    // Build signature parameters
    const signatureParams: CloudinarySignatureParams = {
      timestamp,
      upload_preset: 'nostrvine_video_uploads',
      context: `pubkey=${pubkey}`,
      notification_url: this.getNotificationUrl(),
      eager: this.getEagerTransformations(),
      allowed_formats: options.fileType ? this.getAllowedFormats(options.fileType) : 'mp4,mov,avi,webm',
      max_file_size: options.maxFileSize || 500 * 1024 * 1024, // 500MB default
      resource_type: options.resourceType || 'auto'
    };

    // Generate signature
    const signature = await this.generateSignature(signatureParams);

    return {
      signature,
      timestamp,
      api_key: this.config.api_key,
      cloud_name: this.config.cloud_name,
      upload_preset: signatureParams.upload_preset,
      context: signatureParams.context
    };
  }

  /**
   * Generates a Cloudinary signature for the given parameters
   * @param params - Parameters to sign
   * @returns SHA-1 signature string
   */
  private async generateSignature(params: CloudinarySignatureParams): Promise<string> {
    // Build query string from parameters (excluding api_key)
    const sortedParams = Object.entries(params)
      .filter(([key, value]) => value !== undefined && key !== 'api_key')
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([key, value]) => `${key}=${value}`)
      .join('&');

    // Append API secret
    const stringToSign = `${sortedParams}${this.config.api_secret}`;

    // Generate SHA-1 hash
    const encoder = new TextEncoder();
    const data = encoder.encode(stringToSign);
    const hashBuffer = await crypto.subtle.digest('SHA-1', data);
    const hashArray = Array.from(new Uint8Array(hashBuffer));
    
    return hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
  }

  /**
   * Validates a Cloudinary webhook signature
   * @param body - Raw webhook body
   * @param signature - Signature from X-Cld-Signature header
   * @param timestamp - Timestamp from X-Cld-Timestamp header
   * @returns True if signature is valid
   */
  async validateWebhookSignature(
    body: string,
    signature: string,
    timestamp: string
  ): Promise<boolean> {
    try {
      // Build string to verify
      const stringToVerify = `${body}${timestamp}${this.config.api_secret}`;
      
      // Generate expected signature
      const encoder = new TextEncoder();
      const data = encoder.encode(stringToVerify);
      const hashBuffer = await crypto.subtle.digest('SHA-1', data);
      const hashArray = Array.from(new Uint8Array(hashBuffer));
      const expectedSignature = hashArray.map(b => b.toString(16).padStart(2, '0')).join('');

      // Compare signatures
      return signature === expectedSignature;
    } catch (error) {
      console.error('Error validating webhook signature:', error);
      return false;
    }
  }

  /**
   * Get notification URL for webhook callbacks
   */
  private getNotificationUrl(): string {
    // Use production URL for webhook callbacks
    if (this.workerUrl && this.workerUrl.includes('localhost')) {
      // Development mode - use localhost
      return `${this.workerUrl}/v1/media/webhook`;
    } else {
      // Production mode - use production domain
      return 'https://api.openvine.co/v1/media/webhook';
    }
  }

  /**
   * Get eager transformations for video processing
   */
  private getEagerTransformations(): string {
    const transformations = [
      'f_mp4,vc_h264,q_auto',     // MP4 with H.264 codec
      'f_webp,q_auto:good',       // WebP for web
      'f_gif,fps_10,q_auto:good'  // GIF with 10fps
    ];
    
    return transformations.join('|');
  }

  /**
   * Get allowed file formats based on file type
   */
  private getAllowedFormats(fileType: string): string {
    const videoFormats = ['mp4', 'mov', 'avi', 'webm', 'mkv', 'flv'];
    const imageFormats = ['jpg', 'jpeg', 'png', 'gif', 'webp'];
    
    if (fileType.startsWith('video/')) {
      return videoFormats.join(',');
    } else if (fileType.startsWith('image/')) {
      return imageFormats.join(',');
    } else {
      return [...videoFormats, ...imageFormats].join(',');
    }
  }

  /**
   * Extracts public key from Cloudinary context
   * @param context - Cloudinary context string
   * @returns Extracted public key or null
   */
  static extractPubkeyFromContext(context: string): string | null {
    try {
      const match = context.match(/pubkey=([a-f0-9]{64})/i);
      return match ? match[1] : null;
    } catch {
      return null;
    }
  }

  /**
   * Validates configuration
   */
  validateConfig(): { valid: boolean; errors: string[] } {
    const errors: string[] = [];

    if (!this.config.cloud_name) {
      errors.push('Missing cloud_name');
    }

    if (!this.config.api_key) {
      errors.push('Missing api_key');
    }

    if (!this.config.api_secret) {
      errors.push('Missing api_secret');
    }

    // Validate cloud_name format (should be alphanumeric and dashes)
    if (this.config.cloud_name && !/^[a-zA-Z0-9-]+$/.test(this.config.cloud_name)) {
      errors.push('Invalid cloud_name format');
    }

    // Validate api_key format (should be alphanumeric, underscore, and hyphen)
    if (this.config.api_key && !/^[a-zA-Z0-9_-]+$/.test(this.config.api_key)) {
      errors.push('Invalid api_key format');
    }

    return {
      valid: errors.length === 0,
      errors
    };
  }
}