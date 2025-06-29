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

// Analytics service
import { VideoAnalyticsService } from './services/analytics';

// Thumbnail service
import { ThumbnailService } from './services/ThumbnailService';

// Feature flags
import {
  handleListFeatureFlags,
  handleGetFeatureFlag,
  handleCheckFeatureFlag,
  handleUpdateFeatureFlag,
  handleGradualRollout,
  handleRolloutHealth,
  handleRollback,
  handleFeatureFlagsOptions
} from './handlers/feature-flags-api';

// Moderation API
import { 
  handleReportSubmission, 
  handleModerationStatus, 
  handleModerationQueue, 
  handleModerationAction, 
  handleModerationOptions 
} from './handlers/moderation-api';

// NIP-05 Verification
import {
  handleNIP05Verification,
  handleNIP05Registration,
  handleNIP05Options
} from './handlers/nip05-verification';

// Cleanup script
import { handleCleanupRequest } from './scripts/cleanup-duplicates';

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

			// NIP-05 verification endpoint
			if (pathname === '/.well-known/nostr.json' && method === 'GET') {
				return wrapResponse(handleNIP05Verification(request, env));
			}

			// NIP-05 registration endpoint
			if (pathname === '/api/nip05/register' && method === 'POST') {
				return wrapResponse(handleNIP05Registration(request, env));
			}

			if ((pathname === '/.well-known/nostr.json' || pathname === '/api/nip05/register') && method === 'OPTIONS') {
				return wrapResponse(Promise.resolve(handleNIP05Options()));
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

			// Ready events endpoint (for VideoEventPublisher)
			if (pathname === '/v1/media/ready-events' && method === 'GET') {
				// For now, return empty list - this endpoint would poll for processed videos
				// In a full implementation, this would check for videos ready to publish to Nostr
				return new Response(JSON.stringify({
					events: [],
					timestamp: new Date().toISOString()
				}), {
					headers: {
						'Content-Type': 'application/json',
						'Access-Control-Allow-Origin': '*'
					}
				});
			}

			if (pathname === '/v1/media/ready-events' && method === 'OPTIONS') {
				return new Response(null, {
					status: 200,
					headers: {
						'Access-Control-Allow-Origin': '*',
						'Access-Control-Allow-Methods': 'GET, OPTIONS',
						'Access-Control-Allow-Headers': 'Content-Type, Authorization'
					}
				});
			}

			// Video caching API endpoint
			if (pathname.startsWith('/api/video/') && method === 'GET') {
				const videoId = pathname.split('/api/video/')[1];
				return wrapResponse(handleVideoCacheMetadata(videoId, request, env, ctx));
			}

			if (pathname.startsWith('/api/video/') && method === 'OPTIONS') {
				return wrapResponse(Promise.resolve(handleVideoCacheOptions()));
			}

			// Batch video lookup endpoint
			if (pathname === '/api/videos/batch' && method === 'POST') {
				return wrapResponse(handleBatchVideoLookup(request, env, ctx));
			}

			if (pathname === '/api/videos/batch' && method === 'OPTIONS') {
				return wrapResponse(Promise.resolve(handleBatchVideoOptions()));
			}

			// Analytics endpoints
			if (pathname === '/api/analytics/popular' && method === 'GET') {
				try {
					const analytics = new VideoAnalyticsService(env, ctx);
					const url = new URL(request.url);
					const timeframe = url.searchParams.get('window') as '1h' | '24h' | '7d' || '24h';
					const limit = parseInt(url.searchParams.get('limit') || '10');
					
					const popularVideos = await analytics.getPopularVideos(timeframe, limit);
					
					return new Response(JSON.stringify({
						timeframe,
						videos: popularVideos,
						timestamp: new Date().toISOString()
					}), {
						headers: {
							'Content-Type': 'application/json',
							'Access-Control-Allow-Origin': '*',
							'Cache-Control': 'public, max-age=300'
						}
					});
				} catch (error) {
					return new Response(JSON.stringify({ error: 'Failed to fetch popular videos' }), {
						status: 500,
						headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' }
					});
				}
			}

			if (pathname === '/api/analytics/dashboard' && method === 'GET') {
				try {
					const analytics = new VideoAnalyticsService(env, ctx);
					const [healthStatus, currentMetrics, popular24h] = await Promise.all([
						analytics.getHealthStatus(),
						analytics.getCurrentMetrics(),
						analytics.getPopularVideos('24h', 5)
					]);
					
					return new Response(JSON.stringify({
						health: healthStatus,
						metrics: currentMetrics,
						popularVideos: popular24h,
						timestamp: new Date().toISOString()
					}), {
						headers: {
							'Content-Type': 'application/json',
							'Access-Control-Allow-Origin': '*',
							'Cache-Control': 'public, max-age=60'
						}
					});
				} catch (error) {
					return new Response(JSON.stringify({ error: 'Failed to fetch dashboard data' }), {
						status: 500,
						headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' }
					});
				}
			}

			// Feature flag endpoints
			if (pathname === '/api/feature-flags' && method === 'GET') {
				return wrapResponse(handleListFeatureFlags(request, env, ctx));
			}

			if (pathname.startsWith('/api/feature-flags/') && pathname.endsWith('/check') && method === 'POST') {
				const flagName = pathname.split('/')[3];
				return wrapResponse(handleCheckFeatureFlag(flagName, request, env, ctx));
			}

			if (pathname.startsWith('/api/feature-flags/') && pathname.endsWith('/rollout') && method === 'POST') {
				const flagName = pathname.split('/')[3];
				return wrapResponse(handleGradualRollout(flagName, request, env, ctx));
			}

			if (pathname.startsWith('/api/feature-flags/') && pathname.endsWith('/health') && method === 'GET') {
				const flagName = pathname.split('/')[3];
				return wrapResponse(handleRolloutHealth(flagName, request, env, ctx));
			}

			if (pathname.startsWith('/api/feature-flags/') && pathname.endsWith('/rollback') && method === 'POST') {
				const flagName = pathname.split('/')[3];
				return wrapResponse(handleRollback(flagName, request, env, ctx));
			}

			if (pathname.startsWith('/api/feature-flags/') && !pathname.includes('/check') && !pathname.includes('/rollout') && !pathname.includes('/health') && !pathname.includes('/rollback')) {
				const flagName = pathname.split('/')[3];
				if (method === 'GET') {
					return wrapResponse(handleGetFeatureFlag(flagName, request, env, ctx));
				} else if (method === 'PUT') {
					return wrapResponse(handleUpdateFeatureFlag(flagName, request, env, ctx));
				}
			}

			if (pathname.startsWith('/api/feature-flags') && method === 'OPTIONS') {
				return wrapResponse(Promise.resolve(handleFeatureFlagsOptions()));
			}

			// Thumbnail endpoints
			if (pathname.startsWith('/thumbnail/') && method === 'GET') {
				const videoId = pathname.split('/thumbnail/')[1].split('?')[0];
				const thumbnailService = new ThumbnailService(env);
				
				// Parse query parameters
				const url = new URL(request.url);
				const options = {
					size: url.searchParams.get('size') as 'small' | 'medium' | 'large' | undefined,
					timestamp: parseInt(url.searchParams.get('t') || '1'),
					format: url.searchParams.get('format') as 'jpg' | 'webp' | undefined
				};
				
				return thumbnailService.getThumbnail(videoId, options);
			}

			if (pathname.startsWith('/thumbnail/') && pathname.endsWith('/upload') && method === 'POST') {
				const videoId = pathname.split('/thumbnail/')[1].split('/upload')[0];
				const thumbnailService = new ThumbnailService(env);
				
				// Get thumbnail data from request
				const formData = await request.formData();
				const thumbnailFile = formData.get('thumbnail');
				
				if (!thumbnailFile || !(thumbnailFile instanceof File)) {
					return new Response(JSON.stringify({ error: 'No thumbnail file provided' }), {
						status: 400,
						headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' }
					});
				}
				
				const thumbnailBuffer = await thumbnailFile.arrayBuffer();
				const format = thumbnailFile.type === 'image/webp' ? 'webp' : 'jpg';
				
				const thumbnailUrl = await thumbnailService.uploadCustomThumbnail(videoId, thumbnailBuffer, format);
				
				return new Response(JSON.stringify({ 
					success: true,
					thumbnailUrl 
				}), {
					headers: { 
						'Content-Type': 'application/json',
						'Access-Control-Allow-Origin': '*'
					}
				});
			}

			if (pathname.startsWith('/thumbnail/') && pathname.endsWith('/list') && method === 'GET') {
				const videoId = pathname.split('/thumbnail/')[1].split('/list')[0];
				const thumbnailService = new ThumbnailService(env);
				const thumbnails = await thumbnailService.listThumbnails(videoId);
				
				return new Response(JSON.stringify({
					videoId,
					thumbnails,
					count: thumbnails.length
				}), {
					headers: { 
						'Content-Type': 'application/json',
						'Access-Control-Allow-Origin': '*',
						'Cache-Control': 'public, max-age=300' // 5 minutes
					}
				});
			}

			if (pathname.startsWith('/thumbnail/') && method === 'OPTIONS') {
				return new Response(null, {
					status: 200,
					headers: {
						'Access-Control-Allow-Origin': '*',
						'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
						'Access-Control-Allow-Headers': 'Content-Type, Authorization'
					}
				});
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

			// Media serving endpoint
			if (pathname.startsWith('/media/')) {
				if (method === 'GET') {
					return wrapResponse(handleMediaServing(pathname.substring(7), request, env));
				}
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

			// Cleanup duplicates endpoint (admin only)
			if (pathname === '/admin/cleanup-duplicates' && method === 'POST') {
				return wrapResponse(handleCleanupRequest(request, env));
			}

			// Health check endpoint with analytics
			if (pathname === '/health' && method === 'GET') {
				const analytics = new VideoAnalyticsService(env, ctx);
				const healthStatus = await analytics.getHealthStatus();
				
				return wrapResponse(Promise.resolve(new Response(JSON.stringify({
					...healthStatus,
					version: '1.0.0',
					services: {
						nip96: 'active',
						r2_storage: healthStatus.dependencies.r2,
						stream_api: 'active',
						video_cache_api: 'active',
						kv_storage: healthStatus.dependencies.kv,
						rate_limiter: healthStatus.dependencies.rateLimiter
					}
				}), {
					headers: {
						'Content-Type': 'application/json',
						'Access-Control-Allow-Origin': '*'
					}
				})));
			}

			// Media serving endpoint
			if (pathname.startsWith('/media/') && method === 'GET') {
				const fileId = pathname.split('/media/')[1];
				return handleMediaServing(fileId, request, env);
			}

			// Moderation API endpoints
			if (pathname === '/api/moderation/report' && method === 'POST') {
				return wrapResponse(handleReportSubmission(request, env, ctx));
			}

			if (pathname === '/api/moderation/report' && method === 'OPTIONS') {
				return wrapResponse(Promise.resolve(handleModerationOptions()));
			}

			if (pathname.startsWith('/api/moderation/status/') && method === 'GET') {
				const videoId = pathname.split('/api/moderation/status/')[1];
				return wrapResponse(handleModerationStatus(videoId, request, env));
			}

			if (pathname.startsWith('/api/moderation/status/') && method === 'OPTIONS') {
				return wrapResponse(Promise.resolve(handleModerationOptions()));
			}

			if (pathname === '/api/moderation/queue' && method === 'GET') {
				return wrapResponse(handleModerationQueue(request, env));
			}

			if (pathname === '/api/moderation/queue' && method === 'OPTIONS') {
				return wrapResponse(Promise.resolve(handleModerationOptions()));
			}

			if (pathname === '/api/moderation/action' && method === 'POST') {
				return wrapResponse(handleModerationAction(request, env, ctx));
			}

			if (pathname === '/api/moderation/action' && method === 'OPTIONS') {
				return wrapResponse(Promise.resolve(handleModerationOptions()));
			}

			// Default 404 response
			return new Response(JSON.stringify({
				error: 'Not Found',
				message: `Endpoint ${pathname} not found`,
				available_endpoints: [
					'/.well-known/nostr/nip96.json',
					'/.well-known/nostr.json?name=username (NIP-05 verification)',
					'/api/nip05/register (NIP-05 username registration)',
					'/v1/media/request-upload (Stream CDN)',
					'/v1/webhooks/stream-complete',
					'/v1/media/status/{videoId}',
					'/v1/media/list',
					'/v1/media/metadata/{publicId}',
					'/api/video/{videoId} (Video Cache API)',
					'/api/videos/batch (Batch Video Lookup)',
					'/api/analytics/popular (Popular Videos)',
					'/api/analytics/dashboard (Analytics Dashboard)',
					'/api/feature-flags (Feature Flag Management)',
					'/api/feature-flags/{flagName}/check (Check Feature Flag)',
					'/api/moderation/report (Report content)',
					'/api/moderation/status/{videoId} (Check moderation status)',
					'/api/moderation/queue (Admin: View moderation queue)',
					'/api/moderation/action (Admin: Take moderation action)',
					'/v1/media/cloudinary-upload (Legacy)',
					'/v1/media/webhook (Legacy)',
					'/api/upload (NIP-96)',
					'/api/status/{jobId}',
					'/thumbnail/{videoId} (Get/generate thumbnail)',
					'/thumbnail/{videoId}/upload (Upload custom thumbnail)',
					'/thumbnail/{videoId}/list (List available thumbnails)',
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
