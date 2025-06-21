// ABOUTME: TypeScript type definitions for Cloudinary integration
// ABOUTME: Includes types for signed uploads, webhooks, and API responses

export interface CloudinaryConfig {
  cloud_name: string;
  api_key: string;
  api_secret: string;
}

export interface UploadRequestBody {
  file_type: string;
  byte_size?: number;
}

export interface SignedUploadResponse {
  signature: string;
  timestamp: number;
  api_key: string;
  cloud_name: string;
  upload_preset: string;
  context: string; // Contains user pubkey for state management
}

export interface CloudinaryUploadPreset {
  upload_preset: string;
  settings: {
    eager: Array<{
      format: string;
      video_codec?: string;
      quality: string;
      fps?: number;
    }>;
    context: {
      pubkey: string;
    };
    notification_url: string;
  };
}

export interface CloudinaryWebhookPayload {
  notification_type: 'upload' | 'eager';
  resource_type: 'video' | 'image';
  public_id: string;
  secure_url: string;
  width: number;
  height: number;
  format: string;
  bytes: number;
  etag?: string;
  context?: {
    custom?: {
      pubkey?: string;
    };
  };
  eager?: Array<{
    secure_url: string;
    format: string;
    transformation: string;
    bytes: number;
    width: number;
    height: number;
  }>;
}

export interface CloudinarySignatureParams {
  timestamp: number;
  upload_preset: string;
  context: string;
  notification_url?: string;
  eager?: string;
  allowed_formats?: string;
  max_file_size?: number;
  resource_type?: string;
}

export interface CloudinaryUploadResult {
  public_id: string;
  version: number;
  signature: string;
  width: number;
  height: number;
  format: string;
  resource_type: string;
  created_at: string;
  tags: string[];
  bytes: number;
  type: string;
  etag: string;
  placeholder: boolean;
  url: string;
  secure_url: string;
  folder: string;
  access_mode: string;
  context?: {
    custom?: {
      pubkey?: string;
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
}