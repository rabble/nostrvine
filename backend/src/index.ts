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

// Export Durable Object
export { UploadJobManager } from './services/upload-job-manager';

export default {
	async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
		const url = new URL(request.url);
		const { pathname, method } = url;

		// CORS preflight handling
		if (method === 'OPTIONS') {
			return new Response(null, {
				status: 204,
				headers: {
					'Access-Control-Allow-Origin': '*',
					'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
					'Access-Control-Allow-Headers': 'Content-Type, Authorization',
					'Access-Control-Max-Age': '86400'
				}
			});
		}

		// Route handling
		try {
			// NIP-96 server information endpoint
			if (pathname === '/.well-known/nostr/nip96.json' && method === 'GET') {
				return handleNIP96Info(request, env);
			}

			// Cloudinary signed upload endpoint (new flow)
			if (pathname === '/v1/media/request-upload') {
				if (method === 'POST') {
					return handleCloudinarySignedUpload(request, env);
				}
				if (method === 'OPTIONS') {
					return handleCloudinaryUploadOptions();
				}
			}

			// Cloudinary webhook endpoint
			if (pathname === '/v1/media/webhook') {
				if (method === 'POST') {
					return handleCloudinaryWebhook(request, env);
				}
				if (method === 'OPTIONS') {
					return handleCloudinaryWebhookOptions();
				}
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
						stream_api: 'active'
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
					'/v1/media/request-upload',
					'/v1/media/webhook',
					'/v1/media/list',
					'/v1/media/metadata/{publicId}',
					'/api/upload',
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
			console.error('Request handling error:', error);
			
			return new Response(JSON.stringify({
				error: 'Internal Server Error',
				message: 'An unexpected error occurred',
				timestamp: new Date().toISOString()
			}), {
				status: 500,
				headers: {
					'Content-Type': 'application/json',
					'Access-Control-Allow-Origin': '*'
				}
			});
		}
	},
} satisfies ExportedHandler<Env>;
