// ABOUTME: TypeScript type definitions for the Cloudflare Worker environment
// ABOUTME: Includes bindings for KV namespaces, R2 buckets, and environment variables

export interface Env {
  // KV Namespace bindings
  VIDEO_METADATA: KVNamespace;
  VIDEO_STATUS: KVNamespace;
  
  // R2 Bucket bindings
  VIDEO_BUCKET: R2Bucket;
  
  // Environment variables
  ENVIRONMENT: 'development' | 'staging' | 'production';
  
  // Secrets (configured via wrangler secret)
  API_KEY_SALT?: string;
  SIGNING_SECRET?: string;
  CLOUDFLARE_API_TOKEN?: string;
  STREAM_ACCOUNT_ID?: string;
  
  // Cloudinary secrets
  CLOUDINARY_CLOUD_NAME?: string;
  CLOUDINARY_API_KEY?: string;
  CLOUDINARY_API_SECRET?: string;
  
  // Cloudflare configuration
  CLOUDFLARE_IMAGES_ACCOUNT_HASH?: string;
  WORKER_URL?: string; // The public URL of this worker (e.g., https://api.openvine.co)
  
  // Feature flags
  ENABLE_ANALYTICS?: boolean;
  ENABLE_PERFORMANCE_MODE?: boolean;
}

export interface ExecutionContext {
  waitUntil(promise: Promise<any>): void;
  passThroughOnException(): void;
}