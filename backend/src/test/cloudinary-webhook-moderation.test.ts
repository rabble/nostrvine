// ABOUTME: Tests for Cloudinary webhook moderation pipeline
// ABOUTME: Verifies video moderation state transitions and security logging

import { describe, it, expect, beforeEach, vi } from 'vitest';
import { handleCloudinaryWebhook } from '../handlers/cloudinary-webhook';
import type { ProcessedVideoMetadata } from '../handlers/cloudinary-webhook';
import * as webhookValidation from '../utils/webhook-validation';

// Mock environment for testing
const mockEnv: Env = {
  CLOUDINARY_CLOUD_NAME: 'dswu0ugmo',
  CLOUDINARY_API_KEY: 'test_api_key',
  CLOUDINARY_API_SECRET: 'test_api_secret',
  ENVIRONMENT: 'development',
  BASE_URL: 'http://localhost:8787',
  MAX_FILE_SIZE_FREE: '104857600',
  MAX_FILE_SIZE_PRO: '1073741824',
  WEBHOOK_SECRET: 'test-webhook-secret',
  METADATA_CACHE: new Map() as any // Mock KV store
} as any;

// Mock KV store implementation
const createMockKV = () => {
  const storage = new Map<string, string>();
  return {
    get: async (key: string) => storage.get(key) || null,
    put: async (key: string, value: string, options?: any) => {
      storage.set(key, value);
    },
    clear: () => storage.clear()
  };
};

describe('Cloudinary Webhook Moderation Pipeline', () => {
  let mockKV: any;

  beforeEach(() => {
    mockKV = createMockKV();
    mockEnv.METADATA_CACHE = mockKV;
    vi.clearAllMocks();
  });

  describe('Upload Received (Pre-Moderation)', () => {
    it('should set initial status to pending_moderation on upload', async () => {
      const uploadPayload = {
        notification_type: 'upload',
        public_id: 'test_video_001',
        secure_url: 'https://res.cloudinary.com/dswu0ugmo/video/upload/test_video_001.mp4',
        format: 'mp4',
        width: 1920,
        height: 1080,
        bytes: 5242880,
        resource_type: 'video',
        created_at: '2024-01-01T12:00:00Z',
        context: {
          custom: {
            pubkey: 'abcd1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef'
          }
        },
        signature: 'test_signature'
      };

      const request = new Request('http://localhost:8787/webhook', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Cld-Signature': 'valid_signature'
        },
        body: JSON.stringify(uploadPayload)
      });

      // Mock webhook signature validation
      vi.spyOn(webhookValidation, 'validateWebhookSignature').mockResolvedValue(true);

      const response = await handleCloudinaryWebhook(request, mockEnv);
      
      expect(response.status).toBe(200);
      
      // Verify metadata was stored with pending_moderation status
      const storedMetadata = await mockKV.get('video_metadata:test_video_001');
      expect(storedMetadata).toBeTruthy();
      
      const metadata: ProcessedVideoMetadata = JSON.parse(storedMetadata);
      expect(metadata.processing_status).toBe('pending_moderation');
      expect(metadata.public_id).toBe('test_video_001');
      expect(metadata.user_pubkey).toBe('abcd1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef');

      // Restore original validation
      vi.restoreAllMocks();
    });
  });

  describe('Moderation Completion', () => {
    beforeEach(async () => {
      // Set up initial metadata in pending_moderation state
      const initialMetadata: ProcessedVideoMetadata = {
        public_id: 'test_video_001',
        secure_url: 'https://res.cloudinary.com/dswu0ugmo/video/upload/test_video_001.mp4',
        format: 'mp4',
        width: 1920,
        height: 1080,
        bytes: 5242880,
        resource_type: 'video',
        created_at: '2024-01-01T12:00:00Z',
        user_pubkey: 'abcd1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
        processing_status: 'pending_moderation'
      };
      
      await mockKV.put('video_metadata:test_video_001', JSON.stringify(initialMetadata));
    });

    it('should approve video when moderation passes', async () => {
      const moderationPayload = {
        notification_type: 'moderation',
        public_id: 'test_video_001',
        moderation_status: 'approved',
        moderation_kind: 'aws_rek_video',
        moderation_response: {
          moderation_confidence: 'VERY_UNLIKELY'
        },
        signature: 'test_signature'
      };

      const request = new Request('http://localhost:8787/webhook', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Cld-Signature': 'valid_signature'
        },
        body: JSON.stringify(moderationPayload)
      });

      // Mock webhook signature validation
      vi.spyOn(webhookValidation, 'validateWebhookSignature').mockResolvedValue(true);

      const response = await handleCloudinaryWebhook(request, mockEnv);
      
      expect(response.status).toBe(200);
      
      // Verify metadata was updated to approved
      const storedMetadata = await mockKV.get('video_metadata:test_video_001');
      const metadata: ProcessedVideoMetadata = JSON.parse(storedMetadata);
      
      expect(metadata.processing_status).toBe('approved');
      expect(metadata.moderation_details?.status).toBe('approved');
      expect(metadata.moderation_details?.kind).toBe('aws_rek_video');
      expect(metadata.moderation_details?.response.moderation_confidence).toBe('VERY_UNLIKELY');
    });

    it('should reject video when moderation fails and log security event', async () => {
      const moderationPayload = {
        notification_type: 'moderation',
        public_id: 'test_video_001',
        moderation_status: 'rejected',
        moderation_kind: 'aws_rek_video',
        moderation_response: {
          moderation_confidence: 'VERY_LIKELY',
          frames: [
            {
              pornography_likelihood: 'VERY_LIKELY',
              time_offset: 2.5
            }
          ]
        },
        signature: 'test_signature'
      };

      const request = new Request('http://localhost:8787/webhook', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Cld-Signature': 'valid_signature'
        },
        body: JSON.stringify(moderationPayload)
      });

      // Mock webhook signature validation
      vi.spyOn(webhookValidation, 'validateWebhookSignature').mockResolvedValue(true);

      // Capture console logs to verify security logging
      const originalConsoleLog = console.log;
      const logMessages: string[] = [];
      console.log = (...args: any[]) => {
        logMessages.push(args.join(' '));
        originalConsoleLog(...args);
      };

      const response = await handleCloudinaryWebhook(request, mockEnv);
      
      expect(response.status).toBe(200);
      
      // Verify metadata was updated to rejected
      const storedMetadata = await mockKV.get('video_metadata:test_video_001');
      const metadata: ProcessedVideoMetadata = JSON.parse(storedMetadata);
      
      expect(metadata.processing_status).toBe('rejected');
      expect(metadata.moderation_details?.status).toBe('rejected');
      expect(metadata.moderation_details?.kind).toBe('aws_rek_video');
      expect(metadata.moderation_details?.quarantined_at).toBeTruthy();
      
      // Verify security logging occurred
      const securityLogs = logMessages.filter(msg => msg.includes('🚨 SECURITY'));
      expect(securityLogs.length).toBe(1);
      expect(securityLogs[0]).toContain('test_video_001');
      expect(securityLogs[0]).toContain('rejected');

      // Restore console.log
      console.log = originalConsoleLog;
    });

    it('should handle duplicate moderation webhooks idempotently', async () => {
      // First, approve the video
      const moderationPayload = {
        notification_type: 'moderation',
        public_id: 'test_video_001',
        moderation_status: 'approved',
        moderation_kind: 'aws_rek_video',
        signature: 'test_signature'
      };

      const request1 = new Request('http://localhost:8787/webhook', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Cld-Signature': 'valid_signature'
        },
        body: JSON.stringify(moderationPayload)
      });

      vi.spyOn(webhookValidation, 'validateWebhookSignature').mockResolvedValue(true);

      const response1 = await handleCloudinaryWebhook(request1, mockEnv);
      expect(response1.status).toBe(200);

      // Send the same webhook again
      const request2 = new Request('http://localhost:8787/webhook', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Cld-Signature': 'valid_signature'
        },
        body: JSON.stringify(moderationPayload)
      });

      const response2 = await handleCloudinaryWebhook(request2, mockEnv);
      expect(response2.status).toBe(200);
      
      const responseText = await response2.text();
      expect(responseText).toBe('Already processed');
      
      // Verify metadata wasn't changed
      const storedMetadata = await mockKV.get('video_metadata:test_video_001');
      const metadata: ProcessedVideoMetadata = JSON.parse(storedMetadata);
      expect(metadata.processing_status).toBe('approved');
    });

    it('should handle moderation webhook for non-existent video', async () => {
      const moderationPayload = {
        notification_type: 'moderation',
        public_id: 'non_existent_video',
        moderation_status: 'approved',
        signature: 'test_signature'
      };

      const request = new Request('http://localhost:8787/webhook', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Cld-Signature': 'valid_signature'
        },
        body: JSON.stringify(moderationPayload)
      });

      vi.spyOn(webhookValidation, 'validateWebhookSignature').mockResolvedValue(true);

      const response = await handleCloudinaryWebhook(request, mockEnv);
      
      expect(response.status).toBe(404);
      const responseText = await response.text();
      expect(responseText).toBe('Metadata not found');
    });

    it('should handle unknown moderation status', async () => {
      const moderationPayload = {
        notification_type: 'moderation',
        public_id: 'test_video_001',
        moderation_status: 'unknown_status',
        signature: 'test_signature'
      };

      const request = new Request('http://localhost:8787/webhook', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Cld-Signature': 'valid_signature'
        },
        body: JSON.stringify(moderationPayload)
      });

      vi.spyOn(webhookValidation, 'validateWebhookSignature').mockResolvedValue(true);

      const response = await handleCloudinaryWebhook(request, mockEnv);
      
      expect(response.status).toBe(400);
      const responseText = await response.text();
      expect(responseText).toBe('Unknown moderation status');
    });
  });

  describe('Google Video Moderation Integration', () => {
    beforeEach(async () => {
      const initialMetadata: ProcessedVideoMetadata = {
        public_id: 'google_test_video',
        secure_url: 'https://res.cloudinary.com/dswu0ugmo/video/upload/google_test_video.mp4',
        format: 'mp4',
        width: 1920,
        height: 1080,
        bytes: 5242880,
        resource_type: 'video',
        created_at: '2024-01-01T12:00:00Z',
        user_pubkey: 'test_pubkey_google',
        processing_status: 'pending_moderation'
      };
      
      await mockKV.put('video_metadata:google_test_video', JSON.stringify(initialMetadata));
    });

    it('should handle Google AI video moderation results with frame analysis', async () => {
      const googleModerationPayload = {
        notification_type: 'moderation',
        public_id: 'google_test_video',
        moderation_status: 'rejected',
        moderation_kind: 'google_video_moderation',
        moderation_response: {
          moderation_confidence: 'LIKELY',
          frames: [
            {
              pornography_likelihood: 'LIKELY',
              time_offset: 1.23
            },
            {
              pornography_likelihood: 'VERY_LIKELY', 
              time_offset: 5.67
            }
          ]
        },
        signature: 'test_signature'
      };

      const request = new Request('http://localhost:8787/webhook', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Cld-Signature': 'valid_signature'
        },
        body: JSON.stringify(googleModerationPayload)
      });

      vi.spyOn(webhookValidation, 'validateWebhookSignature').mockResolvedValue(true);

      const response = await handleCloudinaryWebhook(request, mockEnv);
      
      expect(response.status).toBe(200);
      
      const storedMetadata = await mockKV.get('video_metadata:google_test_video');
      const metadata: ProcessedVideoMetadata = JSON.parse(storedMetadata);
      
      expect(metadata.processing_status).toBe('rejected');
      expect(metadata.moderation_details?.kind).toBe('google_video_moderation');
      expect(metadata.moderation_details?.response.frames).toHaveLength(2);
      expect(metadata.moderation_details?.response.frames[0].pornography_likelihood).toBe('LIKELY');
      expect(metadata.moderation_details?.response.frames[1].pornography_likelihood).toBe('VERY_LIKELY');
    });
  });
});