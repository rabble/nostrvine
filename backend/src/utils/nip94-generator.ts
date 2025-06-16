// ABOUTME: NIP-94 file metadata event data generator
// ABOUTME: Creates standardized NIP-94 event tags from processed file metadata

import { FileMetadata } from '../types/nip96';

/**
 * Generate NIP-94 event data from file metadata
 * Returns tags and content for Nostr event broadcasting
 */
export function generateNIP94Event(
  metadata: FileMetadata,
  caption?: string,
  altText?: string
): { tags: Array<[string, string, ...string[]]>; content: string } {
  const tags: Array<[string, string, ...string[]]> = [];
  
  // Required tags per NIP-94
  tags.push(['url', metadata.url]);
  tags.push(['m', metadata.content_type]);
  tags.push(['x', metadata.sha256]);
  tags.push(['size', metadata.size.toString()]);
  
  // Add optional tags
  if (metadata.dimensions) {
    tags.push(['dim', metadata.dimensions]);
  }
  
  if (metadata.thumbnail_url) {
    tags.push(['thumb', metadata.thumbnail_url]);
  }
  
  if (metadata.blurhash) {
    tags.push(['blurhash', metadata.blurhash]);
  }
  
  if (altText) {
    tags.push(['alt', altText]);
  }
  
  // Video-specific tags
  if (metadata.content_type.startsWith('video/')) {
    if (metadata.duration) {
      tags.push(['duration', metadata.duration.toString()]);
    }
    
    // Add stream-specific metadata
    if (metadata.url.includes('stream.cloudflare.com')) {
      tags.push(['stream', 'cloudflare']);
    }
  }
  
  // Add vine-specific tags for short videos
  if (metadata.content_type.startsWith('video/') && metadata.duration && metadata.duration <= 10) {
    tags.push(['t', 'vine']);
    tags.push(['t', 'short-video']);
  }
  
  // Add processing timestamp
  tags.push(['processed_at', Math.floor(Date.now() / 1000).toString()]);
  
  // Content for the event
  const content = caption || `File uploaded: ${metadata.filename}`;
  
  return { tags, content };
}

/**
 * Generate NIP-94 event for GIF converted from video
 */
export function generateGifNIP94Event(
  originalMetadata: FileMetadata,
  gifMetadata: FileMetadata,
  caption?: string
): { tags: Array<[string, string, ...string[]]>; content: string } {
  const { tags, content } = generateNIP94Event(gifMetadata, caption);
  
  // Add relationship to original video
  tags.push(['original', originalMetadata.url]);
  tags.push(['conversion', 'gif']);
  tags.push(['t', 'gif']);
  tags.push(['t', 'vine']);
  
  return { tags, content: content || 'Vine converted to GIF' };
}

/**
 * Validate NIP-94 event data
 */
export function validateNIP94Event(
  tags: Array<[string, string, ...string[]]>,
  content: string
): { valid: boolean; errors: string[] } {
  const errors: string[] = [];
  const requiredTags = ['url', 'm', 'x', 'size'];
  const foundTags = new Set(tags.map(tag => tag[0]));
  
  // Check required tags
  for (const required of requiredTags) {
    if (!foundTags.has(required)) {
      errors.push(`Missing required tag: ${required}`);
    }
  }
  
  // Validate URL format
  const urlTag = tags.find(tag => tag[0] === 'url');
  if (urlTag) {
    try {
      new URL(urlTag[1]);
    } catch {
      errors.push('Invalid URL format');
    }
  }
  
  // Validate hash format (should be hex)
  const hashTag = tags.find(tag => tag[0] === 'x');
  if (hashTag && !/^[a-f0-9]{64}$/i.test(hashTag[1])) {
    errors.push('Invalid SHA-256 hash format');
  }
  
  // Validate size is numeric
  const sizeTag = tags.find(tag => tag[0] === 'size');
  if (sizeTag && isNaN(parseInt(sizeTag[1]))) {
    errors.push('Invalid size value');
  }
  
  // Validate dimensions format (WxH)
  const dimTag = tags.find(tag => tag[0] === 'dim');
  if (dimTag && !/^\d+x\d+$/.test(dimTag[1])) {
    errors.push('Invalid dimensions format (should be WxH)');
  }
  
  return { valid: errors.length === 0, errors };
}

/**
 * Calculate file hash from buffer
 */
export async function calculateSHA256(data: ArrayBuffer): Promise<string> {
  const hashBuffer = await crypto.subtle.digest('SHA-256', data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
}

/**
 * Generate BlurHash for image/video thumbnail
 * Note: This is a placeholder - actual BlurHash generation requires image processing
 */
export function generateBlurHash(imageData: ArrayBuffer): string {
  // Placeholder implementation - in production, use proper BlurHash library
  // For now, return a default BlurHash
  return 'LEHV6nWB2yk8pyo0adR*.7kCMdnj';
}

/**
 * Extract dimensions from image/video file
 * Note: This is a placeholder - requires proper media analysis
 */
export async function extractDimensions(
  data: ArrayBuffer, 
  contentType: string
): Promise<string | null> {
  // Placeholder implementation
  // In production, use proper image/video analysis libraries
  
  if (contentType.startsWith('video/')) {
    // Default video dimensions for vine content
    return '640x640';
  } else if (contentType.startsWith('image/')) {
    // Default image dimensions
    return '512x512';
  }
  
  return null;
}

/**
 * Extract video duration
 * Note: This is a placeholder - requires proper video analysis
 */
export async function extractDuration(data: ArrayBuffer): Promise<number | null> {
  // Placeholder implementation
  // In production, use FFmpeg or similar for accurate duration
  return null;
}