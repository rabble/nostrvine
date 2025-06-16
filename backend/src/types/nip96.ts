// ABOUTME: NIP-96 type definitions for HTTP file storage protocol
// ABOUTME: Defines interfaces and types for NIP-96 compliant file upload responses

/**
 * NIP-96 Server Information Response
 * Returned from /.well-known/nostr/nip96.json
 */
export interface NIP96ServerInfo {
  /** Base URL for upload API */
  api_url: string;
  /** Base URL for file downloads */
  download_url: string;
  /** Supported NIP extensions */
  supported_nips: number[];
  /** Terms of service URL */
  tos_url: string;
  /** Privacy policy URL */
  privacy_url?: string;
  /** Supported content types */
  content_types: string[];
  /** Service plans and limits */
  plans: Record<string, NIP96Plan>;
}

/**
 * Service plan with limits and features
 */
export interface NIP96Plan {
  /** Human-readable plan name */
  name: string;
  /** Maximum file size in bytes */
  max_byte_size: number;
  /** File expiry policy [seconds, description] */
  file_expiry?: [number, string];
  /** Available media transformations */
  media_transformations?: Record<string, string[]>;
}

/**
 * Upload request payload
 */
export interface NIP96UploadRequest {
  /** File to upload */
  file: File | ArrayBuffer;
  /** Optional caption/description */
  caption?: string;
  /** Optional alternative text for accessibility */
  alt?: string;
  /** Content expiration time */
  expiration?: string;
  /** Custom content type */
  content_type?: string;
  /** Whether to skip content moderation */
  no_transform?: boolean;
}

/**
 * Upload response from NIP-96 server
 */
export interface NIP96UploadResponse {
  /** Upload status */
  status: 'success' | 'error' | 'processing';
  /** Status message */
  message?: string;
  /** NIP-94 event data for broadcasting */
  nip94_event?: {
    tags: Array<[string, string, ...string[]]>;
    content: string;
  };
  /** URL for checking processing status */
  processing_url?: string;
}

/**
 * Error response for failed uploads
 */
export interface NIP96ErrorResponse extends NIP96UploadResponse {
  status: 'error';
  /** Standard error code */
  error: NIP96ErrorCode;
  /** Human-readable error message */
  message: string;
}

/**
 * Standard NIP-96 error codes
 */
export enum NIP96ErrorCode {
  INVALID_FILE_TYPE = 'invalid_file_type',
  FILE_TOO_LARGE = 'file_too_large', 
  RATE_LIMIT_EXCEEDED = 'rate_limit_exceeded',
  AUTHENTICATION_REQUIRED = 'authentication_required',
  PROCESSING_FAILED = 'processing_failed',
  INSUFFICIENT_PAYMENT = 'insufficient_payment',
  SERVER_ERROR = 'server_error',
  CONTENT_BLOCKED = 'content_blocked',
  QUOTA_EXCEEDED = 'quota_exceeded'
}

/**
 * Upload job status for async processing
 */
export interface UploadJobStatus {
  /** Unique job identifier */
  job_id: string;
  /** Current processing status */
  status: 'pending' | 'processing' | 'completed' | 'failed';
  /** Progress percentage (0-100) */
  progress?: number;
  /** Status message */
  message?: string;
  /** Final result when completed */
  result?: NIP96UploadResponse;
  /** Error details if failed */
  error?: string;
  /** Job creation timestamp */
  created_at: number;
  /** Last update timestamp */
  updated_at: number;
}

/**
 * Cloudflare Stream integration types
 */
export interface StreamUploadResult {
  /** Stream video ID */
  uid: string;
  /** Upload URL for direct upload */
  uploadUrl: string;
  /** Playback URL (available after processing) */
  playback?: string;
  /** Thumbnail URL */
  thumbnail?: string;
  /** Processing status */
  status?: 'uploading' | 'processing' | 'ready' | 'error';
}

/**
 * Cloudflare Stream webhook payload
 */
export interface StreamWebhookPayload {
  /** Stream video ID */
  uid: string;
  /** Video status */
  status: 'ready' | 'error' | 'processing';
  /** Playback URL when ready */
  playback?: string;
  /** Thumbnail URL */
  thumbnail?: string;
  /** File size in bytes */
  size?: number;
  /** Video duration in seconds */
  duration?: number;
  /** Video dimensions */
  width?: number;
  height?: number;
  /** Error message if failed */
  error?: string;
  /** Timestamp */
  timestamp: string;
}

/**
 * Internal file metadata for storage
 */
export interface FileMetadata {
  /** Unique file identifier */
  id: string;
  /** Original filename */
  filename: string;
  /** MIME type */
  content_type: string;
  /** File size in bytes */
  size: number;
  /** SHA-256 hash */
  sha256: string;
  /** Upload timestamp */
  uploaded_at: number;
  /** Uploader's public key (NIP-98) */
  uploader_pubkey?: string;
  /** File URL */
  url: string;
  /** Thumbnail URL (for videos/images) */
  thumbnail_url?: string;
  /** File dimensions (for images/videos) */
  dimensions?: string;
  /** Video duration (for videos) */
  duration?: number;
  /** BlurHash for progressive loading */
  blurhash?: string;
  /** Content moderation status */
  moderation_status?: 'pending' | 'approved' | 'blocked';
}