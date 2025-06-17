// ABOUTME: NIP-96 compliant upload handler with authentication and processing
// ABOUTME: Handles file uploads with NIP-98 auth and returns NIP-94 event data

import { 
  NIP96UploadResponse, 
  NIP96ErrorResponse, 
  NIP96ErrorCode,
  FileMetadata,
  UploadJobStatus 
} from '../types/nip96';
import { 
  isSupportedContentType, 
  getMaxFileSize, 
  requiresStreamProcessing 
} from './nip96-info';
import { 
  generateNIP94Event, 
  calculateSHA256, 
  extractDimensions,
  extractDuration 
} from '../utils/nip94-generator';
import {
  validateNIP98Auth,
  extractUserPlan,
  createAuthErrorResponse,
  type NIP98AuthResult
} from '../utils/nip98-auth';
import { 
  createContentSafetyScanner, 
  reportCSAMToAuthorities,
  ContentSafetyResult 
} from './csam-detection';

/**
 * Handle NIP-96 file upload requests
 * Supports both direct R2 uploads and Cloudflare Stream processing
 */
export async function handleNIP96Upload(
  request: Request, 
  env: Env,
  ctx: ExecutionContext
): Promise<Response> {
  try {
    // Validate request method
    if (request.method !== 'POST') {
      return createErrorResponse(
        NIP96ErrorCode.SERVER_ERROR,
        'Only POST method allowed for uploads'
      );
    }

    // Parse multipart form data
    const formData = await request.formData();
    const file = formData.get('file') as File;
    
    if (!file) {
      return createErrorResponse(
        NIP96ErrorCode.SERVER_ERROR,
        'No file provided in upload'
      );
    }

    // Validate content type
    if (!isSupportedContentType(file.type)) {
      return createErrorResponse(
        NIP96ErrorCode.INVALID_FILE_TYPE,
        `Content type ${file.type} not supported`
      );
    }

    // Validate NIP-98 authentication first to get user plan
    const authResult = await validateNIP98Auth(request);
    if (!authResult.valid) {
      console.error('NIP-98 authentication failed:', authResult.error);
      return createAuthErrorResponse(
        authResult.error || 'Valid NIP-98 authentication required',
        authResult.errorCode
      );
    }

    console.log(`✅ Authenticated user: ${authResult.pubkey}`);

    // Get optional parameters
    const caption = formData.get('caption')?.toString();
    const altText = formData.get('alt')?.toString();
    
    // Extract user plan from auth event or fallback to form data/default
    const userPlan = authResult.authEvent ? 
      extractUserPlan(authResult.authEvent) : 
      (formData.get('plan')?.toString() || 'free');

    // Validate file size
    const maxSize = getMaxFileSize(userPlan);
    if (file.size > maxSize) {
      return createErrorResponse(
        NIP96ErrorCode.FILE_TOO_LARGE,
        `File size ${file.size} exceeds limit of ${maxSize} bytes`
      );
    }

    // Process the upload
    const fileData = await file.arrayBuffer();
    const sha256Hash = await calculateSHA256(fileData);
    const fileId = `${Date.now()}-${sha256Hash.substring(0, 8)}`;

    // Create initial metadata for content safety scanning
    const tempMetadata: FileMetadata = {
      id: fileId,
      filename: file.name,
      content_type: file.type,
      size: file.size,
      sha256: sha256Hash,
      uploaded_at: Date.now(),
      uploader_pubkey: authResult.pubkey,
      url: '', // Will be set after processing
    };

    // Perform content safety scan (CSAM detection and other safety checks)
    const safetyScanner = createContentSafetyScanner();
    const safetyResult = await safetyScanner.scanContent(fileData, tempMetadata);

    // Handle CSAM detection
    if (safetyResult.violations.csam?.isCSAM) {
      // Report to authorities if CSAM is detected
      await reportCSAMToAuthorities(tempMetadata, safetyResult.violations.csam, env);
      
      return createErrorResponse(
        NIP96ErrorCode.CONTENT_POLICY_VIOLATION,
        'Content violates platform policies and cannot be uploaded',
        403
      );
    }

    // Handle other safety violations
    if (!safetyResult.isSafe) {
      const violationTypes = [];
      if (safetyResult.violations.violence) violationTypes.push('violence');
      if (safetyResult.violations.adult) violationTypes.push('adult content');
      if (safetyResult.violations.spam) violationTypes.push('spam');

      return createErrorResponse(
        NIP96ErrorCode.CONTENT_POLICY_VIOLATION,
        `Content flagged for: ${violationTypes.join(', ')}. Please review community guidelines.`,
        403
      );
    }

    // Additional file validation
    if (!validateFileContent(fileData, file.type)) {
      return createErrorResponse(
        NIP96ErrorCode.INVALID_FILE_TYPE,
        'File content validation failed'
      );
    }

    // Check if file requires Stream processing (videos)
    if (requiresStreamProcessing(file.type)) {
      return await processVideoUpload(
        fileData,
        file,
        fileId,
        sha256Hash,
        caption,
        altText,
        env,
        ctx
      );
    } else {
      return await processDirectUpload(
        fileData,
        file,
        fileId,
        sha256Hash,
        caption,
        altText,
        env,
        request,
        authResult.pubkey
      );
    }

  } catch (error) {
    console.error('Upload error:', error);
    return createErrorResponse(
      NIP96ErrorCode.SERVER_ERROR,
      'Internal server error during upload'
    );
  }
}

/**
 * Process video upload through Cloudflare Stream
 */
async function processVideoUpload(
  fileData: ArrayBuffer,
  file: File,
  fileId: string,
  sha256Hash: string,
  caption?: string,
  altText?: string,
  env?: Env,
  ctx?: ExecutionContext
): Promise<Response> {
  try {
    // TODO: Integrate with Cloudflare Stream API
    // For now, return processing response
    const jobId = `job_${fileId}`;
    
    // Store upload job status (would use Durable Objects in production)
    const jobStatus: UploadJobStatus = {
      job_id: jobId,
      status: 'processing',
      progress: 0,
      message: 'Video upload initiated, processing in progress',
      created_at: Date.now(),
      updated_at: Date.now()
    };

    // Create temporary metadata for processing
    const metadata: FileMetadata = {
      id: fileId,
      filename: file.name,
      content_type: file.type,
      size: file.size,
      sha256: sha256Hash,
      uploaded_at: Date.now(),
      url: `https://stream.cloudflare.com/${fileId}/manifest/video.m3u8`, // Placeholder
      dimensions: await extractDimensions(fileData, file.type),
      duration: await extractDuration(fileData)
    };

    // Generate NIP-94 event data (will be updated when processing completes)
    const nip94Event = generateNIP94Event(metadata, caption, altText);

    const response: NIP96UploadResponse = {
      status: 'processing',
      message: 'Video upload initiated, processing in progress',
      processing_url: `${new URL(request.url).origin}/api/status/${jobId}`,
      nip94_event
    };

    return new Response(JSON.stringify(response), {
      status: 202,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      }
    });

  } catch (error) {
    console.error('Video processing error:', error);
    return createErrorResponse(
      NIP96ErrorCode.PROCESSING_FAILED,
      'Failed to initiate video processing'
    );
  }
}

/**
 * Process direct upload to R2 storage
 */
async function processDirectUpload(
  fileData: ArrayBuffer,
  file: File,
  fileId: string,
  sha256Hash: string,
  caption?: string,
  altText?: string,
  env?: Env,
  request?: Request,
  uploaderPubkey?: string
): Promise<Response> {
  try {
    // Store file in R2
    const fileName = `${fileId}-${file.name}`;
    const r2Key = `uploads/${fileName}`;
    
    // Upload file to R2 storage
    if (!env?.MEDIA_BUCKET) {
      throw new Error('R2 MEDIA_BUCKET binding not configured');
    }

    console.log(`📁 Uploading file to R2: ${r2Key}`);
    
    await env.MEDIA_BUCKET.put(r2Key, fileData, {
      httpMetadata: {
        contentType: file.type,
        cacheControl: 'public, max-age=31536000',
        contentEncoding: undefined,
        contentLanguage: undefined,
        contentDisposition: `inline; filename="${file.name}"`
      },
      customMetadata: {
        sha256: sha256Hash,
        originalName: file.name,
        uploadedAt: Date.now().toString(),
        fileId: fileId,
        size: file.size.toString(),
        uploaderPubkey: uploaderPubkey || 'unknown'
      }
    });

    console.log(`✅ File successfully uploaded to R2: ${r2Key}`);

    // Create file metadata
    const metadata: FileMetadata = {
      id: fileId,
      filename: file.name,
      content_type: file.type,
      size: file.size,
      sha256: sha256Hash,
      uploaded_at: Date.now(),
      uploader_pubkey: uploaderPubkey,
      url: request ? `${new URL(request.url).origin}/media/${fileId}` : `https://api.nostrvine.com/media/${fileId}`,
      dimensions: await extractDimensions(fileData, file.type)
    };

    // Generate NIP-94 event data
    const nip94Event = generateNIP94Event(metadata, caption, altText);

    const response: NIP96UploadResponse = {
      status: 'success',
      message: 'File uploaded successfully',
      nip94_event
    };

    return new Response(JSON.stringify(response), {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      }
    });

  } catch (error) {
    console.error('Direct upload error:', error);
    return createErrorResponse(
      NIP96ErrorCode.SERVER_ERROR,
      'Failed to upload file to storage'
    );
  }
}

/**
 * Handle preflight OPTIONS requests
 */
export async function handleUploadOptions(): Promise<Response> {
  return new Response(null, {
    status: 204,
    headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
      'Access-Control-Max-Age': '86400'
    }
  });
}

/**
 * Create standardized error response
 */
function createErrorResponse(
  error: NIP96ErrorCode, 
  message: string,
  status: number = 400
): Response {
  const errorResponse: NIP96ErrorResponse = {
    status: 'error',
    error,
    message
  };

  return new Response(JSON.stringify(errorResponse), {
    status,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*'
    }
  });
}

/**
 * Get upload job status
 */
export async function handleJobStatus(
  jobId: string,
  env: Env
): Promise<Response> {
  try {
    // TODO: Implement Durable Object lookup for job status
    // For now, return placeholder
    const jobStatus: UploadJobStatus = {
      job_id: jobId,
      status: 'processing',
      progress: 75,
      message: 'Video transcoding in progress',
      created_at: Date.now() - 30000,
      updated_at: Date.now()
    };

    return new Response(JSON.stringify(jobStatus), {
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      }
    });

  } catch (error) {
    return createErrorResponse(
      NIP96ErrorCode.SERVER_ERROR,
      'Failed to get job status'
    );
  }
}

/**
 * Validate file against security policies
 */
function validateFileContent(fileData: ArrayBuffer, contentType: string): boolean {
  // Basic validation - in production, add comprehensive security checks
  
  // Check file signatures/magic numbers
  const header = new Uint8Array(fileData.slice(0, 16));
  
  if (contentType.startsWith('image/')) {
    // Validate image file signatures
    const jpegSignature = [0xFF, 0xD8, 0xFF];
    const pngSignature = [0x89, 0x50, 0x4E, 0x47];
    
    if (contentType === 'image/jpeg') {
      return header.slice(0, 3).every((byte, i) => byte === jpegSignature[i]);
    }
    if (contentType === 'image/png') {
      return header.slice(0, 4).every((byte, i) => byte === pngSignature[i]);
    }
  }
  
  // For video files, basic size and structure validation
  if (contentType.startsWith('video/')) {
    // Ensure file is not empty and has reasonable size
    return fileData.byteLength > 1024 && fileData.byteLength < 1073741824; // 1KB - 1GB
  }
  
  return true;
}

/**
 * Handle media serving from R2 storage
 */
export async function handleMediaServing(
  fileId: string,
  request: Request,
  env: Env
): Promise<Response> {
  try {
    if (!fileId) {
      return new Response('File ID required', {
        status: 400,
        headers: { 'Access-Control-Allow-Origin': '*' }
      });
    }

    if (!env.MEDIA_BUCKET) {
      return new Response('Storage not configured', {
        status: 503,
        headers: { 'Access-Control-Allow-Origin': '*' }
      });
    }

    // Find the file in R2 by scanning uploads/ prefix for this fileId
    const listResult = await env.MEDIA_BUCKET.list({
      prefix: `uploads/${fileId}-`
    });

    if (!listResult.objects || listResult.objects.length === 0) {
      return new Response('File not found', {
        status: 404,
        headers: { 'Access-Control-Allow-Origin': '*' }
      });
    }

    // Get the first matching file
    const r2Object = await env.MEDIA_BUCKET.get(listResult.objects[0].key);

    if (!r2Object) {
      return new Response('File not found', {
        status: 404,
        headers: { 'Access-Control-Allow-Origin': '*' }
      });
    }

    // Extract metadata
    const contentType = r2Object.httpMetadata?.contentType || 'application/octet-stream';
    const originalName = r2Object.customMetadata?.originalName || 'unknown';
    const size = r2Object.size;

    // Handle range requests for video streaming
    const range = request.headers.get('range');
    if (range && contentType.startsWith('video/')) {
      const ranges = range.replace(/bytes=/, '').split('-');
      const start = parseInt(ranges[0], 10);
      const end = ranges[1] ? parseInt(ranges[1], 10) : size - 1;
      const chunksize = (end - start) + 1;

      const partialObject = await env.MEDIA_BUCKET.get(listResult.objects[0].key, {
        range: { offset: start, length: chunksize }
      });

      if (!partialObject) {
        return new Response('Range not satisfiable', { status: 416 });
      }

      return new Response(partialObject.body, {
        status: 206,
        headers: {
          'Content-Range': `bytes ${start}-${end}/${size}`,
          'Accept-Ranges': 'bytes',
          'Content-Length': chunksize.toString(),
          'Content-Type': contentType,
          'Cache-Control': 'public, max-age=31536000',
          'Access-Control-Allow-Origin': '*',
          'Content-Disposition': `inline; filename="${originalName}"`
        }
      });
    }

    // Standard response for complete file
    return new Response(r2Object.body, {
      headers: {
        'Content-Type': contentType,
        'Content-Length': size.toString(),
        'Cache-Control': 'public, max-age=31536000',
        'Access-Control-Allow-Origin': '*',
        'Content-Disposition': `inline; filename="${originalName}"`,
        'ETag': r2Object.etag,
        'Last-Modified': r2Object.uploaded?.toUTCString() || new Date().toUTCString()
      }
    });

  } catch (error) {
    console.error('Media serving error:', error);
    return new Response('Internal server error', {
      status: 500,
      headers: { 'Access-Control-Allow-Origin': '*' }
    });
  }
}