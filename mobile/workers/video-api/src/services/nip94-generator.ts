// ABOUTME: Service for generating NIP-94 file metadata event tags
// ABOUTME: Creates standardized tags for Nostr file sharing

import { CloudinaryWebhookPayload } from '../types/cloudinary';

export class NIP94Generator {
  /**
   * Generates NIP-94 compliant tags for a processed video/image
   * @param payload Cloudinary webhook payload
   * @returns Array of tags for the Nostr event
   */
  static generateTags(payload: CloudinaryWebhookPayload): string[][] {
    const tags: string[][] = [];

    // Required: URL of the file
    tags.push(['url', payload.secure_url]);
    
    // Required: MIME type
    const mimeType = this.getMimeType(payload.resource_type, payload.format);
    tags.push(['m', mimeType]);
    
    // Optional but recommended: File hash (using etag if available)
    if (payload.etag) {
      tags.push(['x', payload.etag]);
    }
    
    // Optional: Original hash (for modified files)
    // tags.push(['ox', 'original-file-hash']);
    
    // Required: File size in bytes
    tags.push(['size', payload.bytes.toString()]);
    
    // Optional: Dimensions for images/videos
    if (payload.width && payload.height) {
      tags.push(['dim', `${payload.width}x${payload.height}`]);
    }
    
    // Optional: Magnet URI (not applicable for Cloudinary)
    // tags.push(['magnet', 'magnet:?xt=urn:btih:...']);
    
    // Optional: Torrent infohash (not applicable)
    // tags.push(['i', 'torrent-infohash']);
    
    // Optional: Blurhash for preview
    // This would need to be calculated separately
    // tags.push(['blurhash', 'calculated-blurhash']);
    
    // Optional: Thumbnail/preview URL
    const thumbnailUrl = this.extractThumbnailUrl(payload);
    if (thumbnailUrl) {
      tags.push(['thumb', thumbnailUrl]);
    }
    
    // Optional: Content warning
    // tags.push(['content-warning', 'reason']);
    
    // Alternative versions (different formats/qualities)
    if (payload.eager && Array.isArray(payload.eager)) {
      payload.eager.forEach(eager => {
        const altMimeType = this.getMimeType(payload.resource_type, eager.format);
        const altTags = [
          'alt',
          eager.secure_url,
          altMimeType
        ];
        
        // Add size if available
        if (eager.bytes) {
          altTags.push(eager.bytes.toString());
        }
        
        // Add dimensions if available
        if (eager.width && eager.height) {
          altTags.push(`${eager.width}x${eager.height}`);
        }
        
        tags.push(altTags);
      });
    }

    // Custom tags for NostrVine
    tags.push(['client', 'nostrvine']);
    tags.push(['processing', 'cloudinary']);
    
    // Add transformation info if present
    if (payload.eager && payload.eager.length > 0) {
      tags.push(['transformations', payload.eager.length.toString()]);
    }

    return tags;
  }

  /**
   * Generates content text suggestion for the Nostr event
   * @param payload Cloudinary webhook payload
   * @param customText Optional custom text from user
   * @returns Suggested content for the event
   */
  static generateContent(payload: CloudinaryWebhookPayload, customText?: string): string {
    if (customText) {
      return customText;
    }

    const isVideo = payload.resource_type === 'video';
    const format = payload.format.toUpperCase();
    const sizeMB = (payload.bytes / (1024 * 1024)).toFixed(1);
    
    let content = '';
    
    if (isVideo) {
      content = `🎬 Shared a video (${format}, ${sizeMB}MB)`;
      
      // Add resolution if available
      if (payload.width && payload.height) {
        content += ` - ${payload.width}x${payload.height}`;
      }
    } else {
      content = `🖼️ Shared an image (${format}, ${sizeMB}MB)`;
      
      // Add resolution if available
      if (payload.width && payload.height) {
        content += ` - ${payload.width}x${payload.height}`;
      }
    }

    // Add NostrVine tag
    content += '\n\n#nostrvine';

    return content;
  }

  /**
   * Determines the correct MIME type from resource type and format
   */
  private static getMimeType(resourceType: string, format: string): string {
    const mimeMap: Record<string, string> = {
      // Video formats
      'video/mp4': 'video/mp4',
      'video/webm': 'video/webm',
      'video/mov': 'video/quicktime',
      'video/avi': 'video/x-msvideo',
      'video/mkv': 'video/x-matroska',
      'video/flv': 'video/x-flv',
      
      // Image formats
      'image/jpg': 'image/jpeg',
      'image/jpeg': 'image/jpeg',
      'image/png': 'image/png',
      'image/gif': 'image/gif',
      'image/webp': 'image/webp',
      'image/bmp': 'image/bmp',
      'image/svg': 'image/svg+xml'
    };

    const key = `${resourceType}/${format.toLowerCase()}`;
    return mimeMap[key] || `${resourceType}/${format}`;
  }

  /**
   * Extracts thumbnail URL from payload
   */
  private static extractThumbnailUrl(payload: CloudinaryWebhookPayload): string | null {
    // For videos, Cloudinary usually generates a thumbnail
    if (payload.resource_type === 'video') {
      // Construct thumbnail URL (frame extraction)
      const baseUrl = payload.secure_url.substring(0, payload.secure_url.lastIndexOf('.'));
      return `${baseUrl}.jpg`;
    }
    
    // For images, we could return a smaller version if available in eager transformations
    if (payload.eager && Array.isArray(payload.eager)) {
      const thumbnail = payload.eager.find(e => 
        e.transformation?.includes('thumb') || 
        (e.width && e.width <= 400)
      );
      
      if (thumbnail) {
        return thumbnail.secure_url;
      }
    }
    
    // For small images, use the image itself
    if (payload.resource_type === 'image' && payload.width <= 400) {
      return payload.secure_url;
    }
    
    return null;
  }

  /**
   * Validates if the generated tags are NIP-94 compliant
   */
  static validateTags(tags: string[][]): { valid: boolean; errors: string[] } {
    const errors: string[] = [];
    
    // Check for required tags
    const hasUrl = tags.some(tag => tag[0] === 'url');
    const hasMimeType = tags.some(tag => tag[0] === 'm');
    const hasSize = tags.some(tag => tag[0] === 'size');
    
    if (!hasUrl) {
      errors.push('Missing required "url" tag');
    }
    
    if (!hasMimeType) {
      errors.push('Missing required "m" (MIME type) tag');
    }
    
    if (!hasSize) {
      errors.push('Missing required "size" tag');
    }
    
    // Validate tag formats
    tags.forEach(tag => {
      if (tag.length < 2) {
        errors.push(`Invalid tag format: ${JSON.stringify(tag)}`);
      }
      
      // Validate specific tag formats
      if (tag[0] === 'dim' && tag[1]) {
        if (!/^\d+x\d+$/.test(tag[1])) {
          errors.push(`Invalid dimension format: ${tag[1]}`);
        }
      }
      
      if (tag[0] === 'size' && tag[1]) {
        if (!/^\d+$/.test(tag[1])) {
          errors.push(`Invalid size format: ${tag[1]}`);
        }
      }
    });
    
    return {
      valid: errors.length === 0,
      errors
    };
  }
}