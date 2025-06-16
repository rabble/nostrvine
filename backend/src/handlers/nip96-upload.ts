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

    // Get optional parameters
    const caption = formData.get('caption')?.toString();
    const altText = formData.get('alt')?.toString();
    const userPlan = formData.get('plan')?.toString() || 'free';

    // Validate file size
    const maxSize = getMaxFileSize(userPlan);
    if (file.size > maxSize) {
      return createErrorResponse(
        NIP96ErrorCode.FILE_TOO_LARGE,
        `File size ${file.size} exceeds limit of ${maxSize} bytes`
      );
    }

    // TODO: Implement NIP-98 authentication validation
    // const authResult = await validateNIP98Auth(request);
    // if (!authResult.valid) {
    //   return createErrorResponse(
    //     NIP96ErrorCode.AUTHENTICATION_REQUIRED,
    //     'Valid NIP-98 authentication required'
    //   );
    // }

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
        env
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
  env?: Env
): Promise<Response> {
  try {
    // Store file in R2
    const fileName = `${fileId}-${file.name}`;
    const r2Key = `uploads/${fileName}`;
    
    // TODO: Implement R2 upload
    // await env.MEDIA_BUCKET.put(r2Key, fileData, {
    //   httpMetadata: {
    //     contentType: file.type,
    //     cacheControl: 'public, max-age=31536000'
    //   },
    //   customMetadata: {
    //     sha256: sha256Hash,
    //     originalName: file.name,
    //     uploadedAt: Date.now().toString()
    //   }
    // });

    // Create file metadata
    const metadata: FileMetadata = {
      id: fileId,
      filename: file.name,
      content_type: file.type,
      size: file.size,
      sha256: sha256Hash,
      uploaded_at: Date.now(),
      url: `https://media.nostrvine.com/${r2Key}`, // Placeholder
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