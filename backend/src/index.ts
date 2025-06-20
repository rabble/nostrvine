/**
 * NostrVine Backend - Cloudflare Workers
 * 
 * NIP-96 compliant file storage server with Cloudflare Stream integration
 * Supports vine-style video uploads, GIF conversion, and Nostr metadata broadcasting
 */

import { handleNIP96Info } from './handlers/nip96-info';
import { handleNIP96Upload, handleUploadOptions, handleJobStatus, handleMediaServing } from './handlers/nip96-upload';
import { handleCloudinarySignedUpload, handleCloudinaryUploadOptions } from './handlers/cloudinary-upload';
import { handleCloudinaryWebhook, handleCloudinaryWebhookOptions } from './handlers/cloudinary-webhook';
import { handleVideoMetadata, handleVideoList, handleVideoMetadataOptions } from './handlers/video-metadata';

// New Cloudflare Stream handlers
import { handleStreamUploadRequest, handleStreamUploadOptions } from './handlers/stream-upload';
import { handleStreamWebhook, handleStreamWebhookOptions } from './handlers/stream-webhook';
import { handleVideoStatus, handleVideoStatusOptions } from './handlers/stream-status';

// Video caching API
import { handleVideoMetadata as handleVideoCacheMetadata, handleVideoMetadataOptions as handleVideoCacheOptions } from './handlers/video-cache-api';
import { handleBatchVideoLookup, handleBatchVideoOptions } from './handlers/batch-video-api';

// Export Durable Object
export { UploadJobManager } from './services/upload-job-manager';

export default {
	async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
		const url = new URL(request.url);
		const pathname = url.pathname;
		const method = request.method;
		
		// Request logging
		const startTime = Date.now();
		console.log(`🔍 ${method} ${pathname} from ${request.headers.get('origin') || 'unknown'}`);

		// Note: CORS preflight handling moved to individual endpoint handlers for proper functionality

		// Helper to wrap response with timing
		const wrapResponse = async (responsePromise: Promise<Response>): Promise<Response> => {
			const response = await responsePromise;
			const duration = Date.now() - startTime;
			console.log(`✅ ${method} ${pathname} - ${response.status} (${duration}ms)`);
			return response;
		};

		// Route handling
		try {
			// NIP-96 server information endpoint
			if (pathname === '/.well-known/nostr/nip96.json' && method === 'GET') {
				return wrapResponse(handleNIP96Info(request, env));
			}

			// Cloudflare Stream upload request endpoint (CDN implementation)
			if (pathname === '/v1/media/request-upload') {
				if (method === 'POST') {
					return handleStreamUploadRequest(request, env);
				}
				if (method === 'OPTIONS') {
					return handleStreamUploadOptions();
				}
			}

			// Cloudflare Stream webhook endpoint (CDN implementation)
			if (pathname === '/v1/webhooks/stream-complete') {
				if (method === 'POST') {
					return handleStreamWebhook(request, env, ctx);
				}
				if (method === 'OPTIONS') {
					return handleStreamWebhookOptions();
				}
			}

			// Video status polling endpoint
			if (pathname.startsWith('/v1/media/status/') && method === 'GET') {
				const videoId = pathname.split('/v1/media/status/')[1];
				return handleVideoStatus(videoId, request, env);
			}

			if (pathname.startsWith('/v1/media/status/') && method === 'OPTIONS') {
				return handleVideoStatusOptions();
			}

			// Video caching API endpoint
			if (pathname.startsWith('/api/video/') && method === 'GET') {
				const videoId = pathname.split('/api/video/')[1];
				return wrapResponse(handleVideoCacheMetadata(videoId, request, env));
			}

			if (pathname.startsWith('/api/video/') && method === 'OPTIONS') {
				return wrapResponse(Promise.resolve(handleVideoCacheOptions()));
			}

			// Batch video lookup endpoint
			if (pathname === '/api/videos/batch' && method === 'POST') {
				return wrapResponse(handleBatchVideoLookup(request, env));
			}

			if (pathname === '/api/videos/batch' && method === 'OPTIONS') {
				return wrapResponse(Promise.resolve(handleBatchVideoOptions()));
			}


			// Video metadata endpoints
			if (pathname === '/v1/media/list' && method === 'GET') {
				return handleVideoList(request, env);
			}

			if (pathname.startsWith('/v1/media/metadata/') && method === 'GET') {
				const publicId = pathname.split('/v1/media/metadata/')[1];
				return handleVideoMetadata(publicId, request, env);
			}

			if (pathname === '/v1/media/list' && method === 'OPTIONS') {
				return handleVideoMetadataOptions();
			}

			if (pathname.startsWith('/v1/media/metadata/') && method === 'OPTIONS') {
				return handleVideoMetadataOptions();
			}

			// NIP-96 upload endpoint (compatibility)
			if (pathname === '/api/upload') {
				if (method === 'POST') {
					return handleNIP96Upload(request, env, ctx);
				}
				if (method === 'OPTIONS') {
					return handleUploadOptions();
				}
			}

			// Upload job status endpoint
			if (pathname.startsWith('/api/status/') && method === 'GET') {
				const jobId = pathname.split('/api/status/')[1];
				return handleJobStatus(jobId, env);
			}

			// Health check endpoint
			if (pathname === '/health' && method === 'GET') {
				return new Response(JSON.stringify({
					status: 'healthy',
					timestamp: new Date().toISOString(),
					version: '1.0.0',
					services: {
						nip96: 'active',
						r2_storage: 'active',
						stream_api: 'active',
						video_cache_api: 'active'
					}
				}), {
					headers: {
						'Content-Type': 'application/json',
						'Access-Control-Allow-Origin': '*'
					}
				});
			}

			// Media serving endpoint
			if (pathname.startsWith('/media/') && method === 'GET') {
				const fileId = pathname.split('/media/')[1];
				return handleMediaServing(fileId, request, env);
			}

			// Default 404 response
			return new Response(JSON.stringify({
				error: 'Not Found',
				message: `Endpoint ${pathname} not found`,
				available_endpoints: [
					'/.well-known/nostr/nip96.json',
					'/v1/media/request-upload (Stream CDN)',
					'/v1/webhooks/stream-complete',
					'/v1/media/status/{videoId}',
					'/v1/media/list',
					'/v1/media/metadata/{publicId}',
					'/api/video/{videoId} (Video Cache API)',
					'/api/videos/batch (Batch Video Lookup)',
					'/v1/media/cloudinary-upload (Legacy)',
					'/v1/media/webhook (Legacy)',
					'/api/upload (NIP-96)',
					'/api/status/{jobId}',
					'/health',
					'/media/{fileId}'
				]
			}), {
				status: 404,
				headers: {
					'Content-Type': 'application/json',
					'Access-Control-Allow-Origin': '*'
				}
			});

		} catch (error) {
			const duration = Date.now() - startTime;
			console.error(`❌ ${method} ${pathname} - Error after ${duration}ms:`, error);
			
			// Structured error response
			const errorResponse = {
				error: 'Internal Server Error',
				message: error instanceof Error ? error.message : 'An unexpected error occurred',
				timestamp: new Date().toISOString(),
				path: pathname,
				method: method
			};

			if (env.ENVIRONMENT === 'development') {
				// Include stack trace in development
				errorResponse['stack'] = error instanceof Error ? error.stack : undefined;
			}
			
			return new Response(JSON.stringify(errorResponse), {
				status: 500,
				headers: {
					'Content-Type': 'application/json',
					'Access-Control-Allow-Origin': '*',
					'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
					'Access-Control-Allow-Headers': 'Content-Type, Authorization'
				}
			});
		}
	},
} satisfies ExportedHandler<Env>;
