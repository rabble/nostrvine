// ABOUTME: NIP-96 server information endpoint handler
// ABOUTME: Serves .well-known/nostr/nip96.json with server capabilities and policies

import { NIP96ServerInfo } from '../types/nip96';

/**
 * Handle requests to /.well-known/nostr/nip96.json
 * Returns server capabilities and upload policies per NIP-96 spec
 */
export async function handleNIP96Info(request: Request, env: Env): Promise<Response> {
  // Get base URL from request
  const url = new URL(request.url);
  const baseUrl = `${url.protocol}//${url.host}`;
  
  const serverInfo: NIP96ServerInfo = {
    api_url: `${baseUrl}/api/upload`,
    download_url: `${baseUrl}/media`,
    supported_nips: [94, 96, 98],
    tos_url: `${baseUrl}/terms`,
    privacy_url: `${baseUrl}/privacy`,
    content_types: [
      // Video formats (primary focus for NostrVine)
      'video/mp4',
      'video/quicktime',
      'video/webm',
      'video/avi',
      'video/mov',
      
      // Image formats (for thumbnails and static content)
      'image/jpeg',
      'image/png', 
      'image/gif',
      'image/webp',
      
      // Audio formats (future expansion)
      'audio/mpeg',
      'audio/wav',
      'audio/ogg'
    ],
    plans: {
      free: {
        name: 'Free Plan',
        max_byte_size: 104857600, // 100MB
        file_expiry: [31536000, 'Files deleted after 1 year of inactivity'],
        media_transformations: {
          gif_conversion: [
            'Convert videos to optimized GIFs',
            'Support up to 30 frames for vine-style content'
          ],
          video_transcoding: [
            'Multiple quality levels (480p, 720p, 1080p)',
            'Adaptive bitrate streaming (HLS/DASH)'
          ],
          thumbnail_generation: [
            'Auto-generated video thumbnails',
            'Multiple sizes (small, medium, large)'
          ],
          blurhash_generation: [
            'Progressive loading placeholders',
            'Computed for all visual media'
          ]
        }
      },
      pro: {
        name: 'Pro Plan', 
        max_byte_size: 1073741824, // 1GB
        file_expiry: [63072000, 'Files kept for 2 years'],
        media_transformations: {
          gif_conversion: [
            'High-quality GIF conversion',
            'Up to 60 frames with advanced optimization'
          ],
          video_transcoding: [
            'Premium quality up to 4K',
            'Advanced codec support (AV1, HEVC)',
            'Custom bitrate profiles'
          ],
          thumbnail_generation: [
            'Custom thumbnail timestamps',
            'Animated preview clips'
          ],
          content_analysis: [
            'Automatic content tagging',
            'Scene detection and keyframe extraction'
          ]
        }
      }
    }
  };

  return new Response(JSON.stringify(serverInfo, null, 2), {
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
      'Cache-Control': 'public, max-age=3600' // Cache for 1 hour
    }
  });
}

/**
 * Validate content type against supported types
 */
export function isSupportedContentType(contentType: string): boolean {
  const supportedTypes = [
    'video/mp4', 'video/quicktime', 'video/webm', 'video/avi', 'video/mov',
    'image/jpeg', 'image/png', 'image/gif', 'image/webp',
    'audio/mpeg', 'audio/wav', 'audio/ogg'
  ];
  
  return supportedTypes.includes(contentType.toLowerCase());
}

/**
 * Get max file size for user plan
 */
export function getMaxFileSize(plan: string = 'free'): number {
  const limits = {
    free: 104857600,  // 100MB
    pro: 1073741824   // 1GB
  };
  
  return limits[plan as keyof typeof limits] || limits.free;
}

/**
 * Check if content type requires special processing
 */
export function requiresStreamProcessing(contentType: string): boolean {
  return contentType.startsWith('video/');
}

/**
 * Get processing capabilities for content type
 */
export function getProcessingCapabilities(contentType: string): string[] {
  if (contentType.startsWith('video/')) {
    return [
      'transcoding',
      'thumbnail_generation', 
      'gif_conversion',
      'blurhash_generation',
      'stream_optimization'
    ];
  } else if (contentType.startsWith('image/')) {
    return [
      'thumbnail_generation',
      'blurhash_generation',
      'format_optimization'
    ];
  } else if (contentType.startsWith('audio/')) {
    return [
      'transcoding',
      'waveform_generation',
      'format_optimization'
    ];
  }
  
  return [];
}