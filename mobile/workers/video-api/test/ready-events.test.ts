// ABOUTME: Test suite for ready events endpoint handling
// ABOUTME: Tests NIP-98 auth, event retrieval, and deletion

import { describe, it, expect, beforeEach, vi } from 'vitest';
import { ReadyEventsHandler } from '../src/handlers/ready-events';
import { Env, ExecutionContext } from '../src/types';
import * as nostrTools from 'nostr-tools';
import { validateNIP98Event } from '../src/lib/auth';

// Mock KV namespace
const mockKV = {
  put: vi.fn(),
  get: vi.fn(),
  delete: vi.fn(),
  list: vi.fn()
};

// Mock execution context
const mockCtx: ExecutionContext = {
  waitUntil: vi.fn(),
  passThroughOnException: vi.fn()
};

// Mock environment
const mockEnv: Env = {
  VIDEO_STATUS: mockKV as any,
  CLOUDINARY_CLOUD_NAME: 'test-cloud',
  CLOUDINARY_API_KEY: 'test-api-key',
  CLOUDINARY_API_SECRET: 'test-secret',
  STREAM_CUSTOMER_ID: '',
  STREAM_API_TOKEN: '',
  CLOUDFLARE_ACCOUNT_ID: '',
  CF_STREAM_BASE_URL: '',
  ENABLE_PERFORMANCE_MODE: false
};

// Mock validateNIP98Event
vi.mock('../src/lib/auth', () => ({
  validateNIP98Event: vi.fn(),
  NIP98AuthError: class NIP98AuthError extends Error {
    constructor(message: string) {
      super(message);
      this.name = 'NIP98AuthError';
    }
  }
}));

describe('ReadyEventsHandler', () => {
  let handler: ReadyEventsHandler;
  let sk: Uint8Array;
  let pk: string;

  beforeEach(() => {
    handler = new ReadyEventsHandler(mockEnv);
    vi.clearAllMocks();
    
    // Generate test keypair
    sk = nostrTools.generateSecretKey();
    pk = nostrTools.getPublicKey(sk);
  });

  describe('handleGetReadyEvents', () => {
    it('should reject requests without authorization header', async () => {
      const request = new Request('http://localhost:8787/v1/media/ready-events', {
        method: 'GET'
      });

      const response = await handler.handleGetReadyEvents(request, mockCtx);
      
      expect(response.status).toBe(401);
      const body = await response.json();
      expect(body.error.message).toBe('Missing Authorization header');
    });

    it('should return empty array when no events exist', async () => {
      const mockEvent = {
        id: 'test-id',
        pubkey: pk,
        created_at: Math.floor(Date.now() / 1000),
        kind: 27235,
        tags: [],
        content: '',
        sig: 'test-sig'
      };

      vi.mocked(validateNIP98Event).mockResolvedValue(mockEvent);
      mockKV.list.mockResolvedValue({ keys: [] });

      const request = new Request('http://localhost:8787/v1/media/ready-events', {
        method: 'GET',
        headers: {
          'Authorization': 'Nostr base64-encoded-event'
        }
      });

      const response = await handler.handleGetReadyEvents(request, mockCtx);
      
      expect(response.status).toBe(200);
      const body = await response.json();
      expect(body.events).toEqual([]);
      expect(body.count).toBe(0);
    });

    it('should return ready events for authenticated user', async () => {
      const mockEvent = {
        id: 'test-id',
        pubkey: pk,
        created_at: Math.floor(Date.now() / 1000),
        kind: 27235,
        tags: [],
        content: '',
        sig: 'test-sig'
      };

      const readyEvent1 = {
        public_id: 'video-123',
        tags: [
          ['url', 'https://example.com/video.mp4'],
          ['m', 'video/mp4'],
          ['size', '10485760']
        ],
        content_suggestion: '🎬 Shared a video',
        formats: {
          mp4: 'https://example.com/video.mp4',
          webp: 'https://example.com/video.webp'
        },
        metadata: {
          width: 1920,
          height: 1080,
          size_bytes: 10485760
        },
        timestamp: '2024-01-01T12:00:00Z'
      };

      const readyEvent2 = {
        public_id: 'video-456',
        tags: [
          ['url', 'https://example.com/video2.mp4'],
          ['m', 'video/mp4'],
          ['size', '5242880']
        ],
        content_suggestion: '🎬 Shared a video',
        formats: {
          mp4: 'https://example.com/video2.mp4'
        },
        metadata: {
          width: 1280,
          height: 720,
          size_bytes: 5242880
        },
        timestamp: '2024-01-01T11:00:00Z'
      };

      vi.mocked(validateNIP98Event).mockResolvedValue(mockEvent);
      mockKV.list.mockResolvedValue({
        keys: [
          { name: `ready:${pk}:video-123` },
          { name: `ready:${pk}:video-456` }
        ]
      });
      mockKV.get
        .mockResolvedValueOnce(JSON.stringify(readyEvent1))
        .mockResolvedValueOnce(JSON.stringify(readyEvent2));

      const request = new Request('http://localhost:8787/v1/media/ready-events', {
        method: 'GET',
        headers: {
          'Authorization': 'Nostr base64-encoded-event'
        }
      });

      const response = await handler.handleGetReadyEvents(request, mockCtx);
      
      expect(response.status).toBe(200);
      const body = await response.json();
      expect(body.count).toBe(2);
      expect(body.events).toHaveLength(2);
      // Should be sorted by timestamp (newest first)
      expect(body.events[0].public_id).toBe('video-123');
      expect(body.events[1].public_id).toBe('video-456');
    });
  });

  describe('handleDeleteReadyEvent', () => {
    it('should delete a ready event', async () => {
      const mockEvent = {
        id: 'test-id',
        pubkey: pk,
        created_at: Math.floor(Date.now() / 1000),
        kind: 27235,
        tags: [],
        content: '',
        sig: 'test-sig'
      };

      vi.mocked(validateNIP98Event).mockResolvedValue(mockEvent);
      mockKV.delete.mockResolvedValue(undefined);

      const request = new Request('http://localhost:8787/v1/media/ready-events', {
        method: 'DELETE',
        headers: {
          'Authorization': 'Nostr base64-encoded-event',
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ public_id: 'video-123' })
      });

      const response = await handler.handleDeleteReadyEvent(request, mockCtx);
      
      expect(response.status).toBe(200);
      const body = await response.json();
      expect(body.success).toBe(true);
      expect(mockKV.delete).toHaveBeenCalledWith(`ready:${pk}:video-123`);
    });

    it('should reject delete without public_id', async () => {
      const mockEvent = {
        id: 'test-id',
        pubkey: pk,
        created_at: Math.floor(Date.now() / 1000),
        kind: 27235,
        tags: [],
        content: '',
        sig: 'test-sig'
      };

      vi.mocked(validateNIP98Event).mockResolvedValue(mockEvent);

      const request = new Request('http://localhost:8787/v1/media/ready-events', {
        method: 'DELETE',
        headers: {
          'Authorization': 'Nostr base64-encoded-event',
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({})
      });

      const response = await handler.handleDeleteReadyEvent(request, mockCtx);
      
      expect(response.status).toBe(400);
      const body = await response.json();
      expect(body.error.message).toBe('Missing public_id in request body');
    });
  });

  describe('handleGetSpecificEvent', () => {
    it('should return a specific ready event', async () => {
      const mockEvent = {
        id: 'test-id',
        pubkey: pk,
        created_at: Math.floor(Date.now() / 1000),
        kind: 27235,
        tags: [],
        content: '',
        sig: 'test-sig'
      };

      const readyEvent = {
        public_id: 'video-123',
        tags: [
          ['url', 'https://example.com/video.mp4'],
          ['m', 'video/mp4'],
          ['size', '10485760']
        ],
        content_suggestion: '🎬 Shared a video',
        formats: {
          mp4: 'https://example.com/video.mp4'
        },
        metadata: {
          width: 1920,
          height: 1080,
          size_bytes: 10485760
        },
        timestamp: '2024-01-01T12:00:00Z'
      };

      vi.mocked(validateNIP98Event).mockResolvedValue(mockEvent);
      mockKV.get.mockResolvedValue(JSON.stringify(readyEvent));

      const request = new Request('http://localhost:8787/v1/media/ready-events/video-123', {
        method: 'GET',
        headers: {
          'Authorization': 'Nostr base64-encoded-event'
        }
      });

      const response = await handler.handleGetSpecificEvent(request, 'video-123', mockCtx);
      
      expect(response.status).toBe(200);
      const body = await response.json();
      expect(body.public_id).toBe('video-123');
      expect(body.tags).toEqual(readyEvent.tags);
    });

    it('should return 404 for non-existent event', async () => {
      const mockEvent = {
        id: 'test-id',
        pubkey: pk,
        created_at: Math.floor(Date.now() / 1000),
        kind: 27235,
        tags: [],
        content: '',
        sig: 'test-sig'
      };

      vi.mocked(validateNIP98Event).mockResolvedValue(mockEvent);
      mockKV.get.mockResolvedValue(null);

      const request = new Request('http://localhost:8787/v1/media/ready-events/non-existent', {
        method: 'GET',
        headers: {
          'Authorization': 'Nostr base64-encoded-event'
        }
      });

      const response = await handler.handleGetSpecificEvent(request, 'non-existent', mockCtx);
      
      expect(response.status).toBe(404);
      const body = await response.json();
      expect(body.error.message).toBe('Event not found');
    });
  });
});