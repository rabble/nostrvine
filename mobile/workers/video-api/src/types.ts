// ABOUTME: TypeScript type definitions for the Cloudflare Worker environment
// ABOUTME: Includes bindings for KV namespaces, R2 buckets, and environment variables

export interface Env {
  // KV Namespace bindings
  VIDEO_METADATA: KVNamespace;
  
  // R2 Bucket bindings
  VIDEO_BUCKET: R2Bucket;
  
  // Environment variables
  ENVIRONMENT: 'development' | 'staging' | 'production';
  
  // Secrets (configured via wrangler secret)
  API_KEY_SALT?: string;
  SIGNING_SECRET?: string;
  
  // Feature flags
  ENABLE_ANALYTICS?: boolean;
}

export interface ExecutionContext {
  waitUntil(promise: Promise<any>): void;
  passThroughOnException(): void;
}