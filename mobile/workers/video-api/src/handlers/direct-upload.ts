// ABOUTME: Direct video upload handler for CF Workers → R2 storage
// ABOUTME: Processes video uploads without external dependencies, stores in R2 with CDN serving

import { Env, ExecutionContext } from '../types';
import { validateNIP98Event, NIP98AuthError } from '../lib/auth';

interface UploadMetadata {
  videoId: string;
  nostrPubkey: string;
  filename: string;
  contentType: string;
  fileSize: number;
  uploadedAt: string;
  r2Key: string;
  cdnUrl: string;
  status: 'uploaded' | 'processing' | 'ready' | 'failed';
}

interface UploadResponse {
  success: boolean;
  videoId: string;
  cdnUrl: string;
  metadata: UploadMetadata;
}

export class DirectUploadHandler {
  private env: Env;
  private readonly MAX_FILE_SIZE = 500 * 1024 * 1024; // 500MB
  private readonly ALLOWED_TYPES = [
    'video/mp4', 'video/mov', 'video/avi', 'video/webm', 'video/mkv'
  ];

  constructor(env: Env) {
    this.env = env;
  }

  async handleUpload(request: Request, ctx: ExecutionContext): Promise<Response> {
    try {
      // Validate NIP-98 authentication
      const authHeader = request.headers.get('Authorization');
      if (!authHeader) {
        return this.errorResponse('Missing Authorization header', 401);
      }

      let nostrEvent;
      try {
        nostrEvent = await validateNIP98Event(authHeader, request.url, 'POST');
      } catch (error) {
        if (error instanceof NIP98AuthError) {
          return this.errorResponse(error.message, 401);
        }
        throw error;
      }

      const pubkey = nostrEvent.pubkey;

      // Parse multipart form data
      const formData = await request.formData();
      const videoFile = formData.get('video') as File;
      
      if (!videoFile) {
        return this.errorResponse('No video file provided', 400);
      }

      // Validate file
      const validation = this.validateFile(videoFile);
      if (!validation.valid) {
        return this.errorResponse(validation.error!, 400);
      }

      // Generate unique video ID and R2 key
      const videoId = crypto.randomUUID();
      const date = new Date();
      const year = date.getFullYear();
      const month = String(date.getMonth() + 1).padStart(2, '0');
      const day = String(date.getDate()).padStart(2, '0');
      const userPrefix = pubkey.substring(0, 8);
      
      // Get file extension
      const extension = this.getFileExtension(videoFile.name, videoFile.type);
      const r2Key = `videos/${year}/${month}/${day}/${userPrefix}/${videoId}.${extension}`;

      // Upload to R2
      const videoBuffer = await videoFile.arrayBuffer();
      
      await this.env.VIDEO_BUCKET.put(r2Key, videoBuffer, {
        httpMetadata: {
          contentType: videoFile.type,
          cacheControl: 'public, max-age=31536000', // 1 year cache
        },
        customMetadata: {
          'video-id': videoId,
          'user-pubkey': pubkey,
          'original-filename': videoFile.name,
          'uploaded-at': date.toISOString(),
          'file-size': videoFile.size.toString(),
          'content-type': videoFile.type,
        }
      });

      // Generate CDN URL
      const cdnUrl = `https://cdn.openvine.co/${r2Key}`;

      // Create metadata
      const metadata: UploadMetadata = {
        videoId,
        nostrPubkey: pubkey,
        filename: videoFile.name,
        contentType: videoFile.type,
        fileSize: videoFile.size,
        uploadedAt: date.toISOString(),
        r2Key,
        cdnUrl,
        status: 'ready'
      };

      // Store metadata in KV
      await this.env.VIDEO_METADATA.put(
        `video:${videoId}`,
        JSON.stringify(metadata),
        { expirationTtl: 86400 * 30 } // 30 days
      );

      // Store in user's video list
      await this.addToUserVideoList(pubkey, videoId);

      console.log(`✅ Direct upload completed: ${videoId} (${videoFile.size} bytes)`);

      const response: UploadResponse = {
        success: true,
        videoId,
        cdnUrl,
        metadata
      };

      return new Response(JSON.stringify(response), {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
          'Cache-Control': 'no-store'
        }
      });

    } catch (error) {
      console.error('Error handling direct upload:', error);
      return this.errorResponse('Upload failed', 500);
    }
  }

  private validateFile(file: File): { valid: boolean; error?: string } {
    // Check file size
    if (file.size > this.MAX_FILE_SIZE) {
      return {
        valid: false,
        error: `File size exceeds maximum of ${this.MAX_FILE_SIZE / 1024 / 1024}MB`
      };
    }

    if (file.size === 0) {
      return {
        valid: false,
        error: 'File is empty'
      };
    }

    // Check file type
    if (!this.ALLOWED_TYPES.includes(file.type.toLowerCase())) {
      return {
        valid: false,
        error: `Unsupported file type: ${file.type}. Allowed: ${this.ALLOWED_TYPES.join(', ')}`
      };
    }

    return { valid: true };
  }

  private getFileExtension(filename: string, mimeType: string): string {
    // Try to get extension from filename first
    const filenameExt = filename.split('.').pop()?.toLowerCase();
    if (filenameExt && ['mp4', 'mov', 'avi', 'webm', 'mkv'].includes(filenameExt)) {
      return filenameExt;
    }

    // Fall back to mime type
    const mimeExtMap: Record<string, string> = {
      'video/mp4': 'mp4',
      'video/mov': 'mov',
      'video/quicktime': 'mov',
      'video/avi': 'avi',
      'video/webm': 'webm',
      'video/x-msvideo': 'avi',
      'video/x-matroska': 'mkv'
    };

    return mimeExtMap[mimeType.toLowerCase()] || 'mp4';
  }

  private async addToUserVideoList(pubkey: string, videoId: string): Promise<void> {
    const userVideosKey = `user_videos:${pubkey}`;
    const existingVideos = await this.env.VIDEO_METADATA.get(userVideosKey);
    let videosList: string[] = [];
    
    if (existingVideos) {
      try {
        videosList = JSON.parse(existingVideos);
      } catch (e) {
        console.warn('Failed to parse existing videos list, starting fresh');
      }
    }

    // Add new video to the list (most recent first)
    videosList.unshift(videoId);
    
    // Keep only the last 100 videos per user
    if (videosList.length > 100) {
      videosList = videosList.slice(0, 100);
    }

    await this.env.VIDEO_METADATA.put(userVideosKey, JSON.stringify(videosList), {
      expirationTtl: 86400 * 30 // 30 days
    });
  }

  private errorResponse(message: string, status: number): Response {
    return new Response(JSON.stringify({ 
      success: false, 
      error: message 
    }), {
      status,
      headers: {
        'Content-Type': 'application/json',
        'Cache-Control': 'no-store'
      }
    });
  }
}