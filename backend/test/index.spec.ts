import { env, createExecutionContext, waitOnExecutionContext, SELF } from 'cloudflare:test';
import { describe, it, expect } from 'vitest';
import worker from '../src/index';

// For now, you'll need to do something like this to get a correctly-typed
// `Request` to pass to `worker.fetch()`.
const IncomingRequest = Request<unknown, IncomingRequestCfProperties>;

describe('NostrVine Backend API', () => {
	it('responds with 404 for unknown endpoints (unit style)', async () => {
		const request = new IncomingRequest('http://example.com');
		// Create an empty context to pass to `worker.fetch()`.
		const ctx = createExecutionContext();
		const response = await worker.fetch(request, env, ctx);
		// Wait for all `Promise`s passed to `ctx.waitUntil()` to settle before running test assertions
		await waitOnExecutionContext(ctx);
		
		expect(response.status).toBe(404);
		const responseData = await response.json();
		expect(responseData.error).toBe('Not Found');
		expect(responseData.available_endpoints).toContain('/.well-known/nostr/nip96.json');
	});

	it('serves NIP-96 server info (integration style)', async () => {
		const response = await SELF.fetch('https://example.com/.well-known/nostr/nip96.json');
		expect(response.status).toBe(200);
		
		const serverInfo = await response.json();
		expect(serverInfo.api_url).toBe('https://example.com/api/upload');
		expect(serverInfo.supported_nips).toContain(96);
		expect(serverInfo.content_types).toContain('video/mp4');
	});

	it('returns health status', async () => {
		const response = await SELF.fetch('https://example.com/health');
		expect(response.status).toBe(200);
		
		const health = await response.json();
		expect(health.status).toBe('healthy');
		expect(health.services.nip96).toBe('active');
	});
});
