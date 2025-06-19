// ABOUTME: Tests for Cloudinary webhook processing functionality
// ABOUTME: Verifies signature validation and metadata storage for video processing events

import { describe, it, expect, beforeEach } from 'vitest';
import { handleCloudinaryWebhook } from '../handlers/cloudinary-webhook';

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
  METADATA_CACHE: {
    put: async (key: string, value: string, options?: any) => {
      console.log(`Mock KV PUT: ${key} = ${value}`);
    },
    get: async (key: string) => {
      console.log(`Mock KV GET: ${key}`);
      return null; // Default empty response
    }
  } as any
} as any;

describe('Cloudinary Webhook Handler', () => {
  it('should reject requests without signature', async () => {
    const payload = JSON.stringify({
      notification_type: 'upload',
      public_id: 'test_video',
      secure_url: 'https://res.cloudinary.com/test/video/upload/test_video.mp4'
    });

    const request = new Request('http://localhost:8787/v1/media/webhook', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: payload
    });

    const response = await handleCloudinaryWebhook(request, mockEnv);
    
    expect(response.status).toBe(400);
    const body = await response.text();
    expect(body).toBe('Missing webhook signature');
  });

  it('should reject requests with invalid signature', async () => {
    const payload = JSON.stringify({
      notification_type: 'upload',
      public_id: 'test_video',
      secure_url: 'https://res.cloudinary.com/test/video/upload/test_video.mp4'
    });

    const request = new Request('http://localhost:8787/v1/media/webhook', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Cld-Signature': 'sha256=invalid_signature'
      },
      body: payload
    });

    const response = await handleCloudinaryWebhook(request, mockEnv);
    
    expect(response.status).toBe(401);
    const body = await response.text();
    expect(body).toBe('Invalid webhook signature');
  });

  it('should reject malformed JSON payload', async () => {
    // Generate a valid signature for malformed payload
    const malformedPayload = '{"invalid_json":}';
    const validSignature = await generateTestSignature(malformedPayload, mockEnv.WEBHOOK_SECRET);

    const request = new Request('http://localhost:8787/v1/media/webhook', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Cld-Signature': validSignature
      },
      body: malformedPayload
    });

    const response = await handleCloudinaryWebhook(request, mockEnv);
    
    expect(response.status).toBe(400);
    const body = await response.text();
    expect(body).toBe('Invalid JSON payload');
  });

  it('should handle upload completion webhook', async () => {
    const payload = {
      notification_type: 'upload',
      timestamp: Math.floor(Date.now() / 1000),
      public_id: 'nostrvine/test_user/123456_abc',
      secure_url: 'https://res.cloudinary.com/dswu0ugmo/video/upload/nostrvine/test_user/123456_abc.mp4',
      format: 'mp4',
      width: 720,
      height: 1280,
      bytes: 1024000,
      resource_type: 'video',
      created_at: '2024-06-17T12:00:00Z',
      context: {
        custom: {
          pubkey: 'abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890',
          app: 'nostrvine',
          version: '1.0'
        }
      }
    };

    const payloadString = JSON.stringify(payload);
    const validSignature = await generateTestSignature(payloadString, mockEnv.WEBHOOK_SECRET);

    const request = new Request('http://localhost:8787/v1/media/webhook', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Cld-Signature': validSignature
      },
      body: payloadString
    });

    const response = await handleCloudinaryWebhook(request, mockEnv);
    
    expect(response.status).toBe(200);
    const body = await response.text();
    expect(body).toBe('Upload received, pending moderation');
  });

  it('should handle eager transformation completion', async () => {
    // Mock existing metadata in KV store
    const existingMetadata = {
      public_id: 'nostrvine/test_user/123456_abc',
      secure_url: 'https://res.cloudinary.com/dswu0ugmo/video/upload/nostrvine/test_user/123456_abc.mp4',
      user_pubkey: 'abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890',
      processing_status: 'completed'
    };

    // Mock KV get to return existing metadata
    mockEnv.METADATA_CACHE.get = async (key: string) => {
      if (key === 'video_metadata:nostrvine/test_user/123456_abc') {
        return JSON.stringify(existingMetadata);
      }
      return null;
    };

    const payload = {
      notification_type: 'eager',
      public_id: 'nostrvine/test_user/123456_abc',
      eager: [
        {
          transformation: 'w_480,h_854,c_fill',
          width: 480,
          height: 854,
          bytes: 512000,
          format: 'mp4',
          url: 'https://res.cloudinary.com/dswu0ugmo/video/upload/w_480,h_854,c_fill/nostrvine/test_user/123456_abc.mp4',
          secure_url: 'https://res.cloudinary.com/dswu0ugmo/video/upload/w_480,h_854,c_fill/nostrvine/test_user/123456_abc.mp4'
        }
      ]
    };

    const payloadString = JSON.stringify(payload);
    const validSignature = await generateTestSignature(payloadString, mockEnv.WEBHOOK_SECRET);

    const request = new Request('http://localhost:8787/v1/media/webhook', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Cld-Signature': validSignature
      },
      body: payloadString
    });

    const response = await handleCloudinaryWebhook(request, mockEnv);
    
    expect(response.status).toBe(200);
    const body = await response.text();
    expect(body).toBe('Eager transformations processed');
  });

  it('should handle processing error notifications', async () => {
    const payload = {
      notification_type: 'error',
      public_id: 'nostrvine/test_user/123456_abc',
      format: 'mp4',
      resource_type: 'video',
      created_at: '2024-06-17T12:00:00Z',
      context: {
        custom: {
          pubkey: 'abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890'
        }
      }
    };

    const payloadString = JSON.stringify(payload);
    const validSignature = await generateTestSignature(payloadString, mockEnv.WEBHOOK_SECRET);

    const request = new Request('http://localhost:8787/v1/media/webhook', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Cld-Signature': validSignature
      },
      body: payloadString
    });

    const response = await handleCloudinaryWebhook(request, mockEnv);
    
    expect(response.status).toBe(200);
    const body = await response.text();
    expect(body).toBe('Error processed');
  });

  it('should ignore unknown notification types', async () => {
    const payload = {
      notification_type: 'unknown_type',
      public_id: 'test_video'
    };

    const payloadString = JSON.stringify(payload);
    const validSignature = await generateTestSignature(payloadString, mockEnv.WEBHOOK_SECRET);

    const request = new Request('http://localhost:8787/v1/media/webhook', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Cld-Signature': validSignature
      },
      body: payloadString
    });

    const response = await handleCloudinaryWebhook(request, mockEnv);
    
    expect(response.status).toBe(200);
    const body = await response.text();
    expect(body).toBe('OK');
  });
});

/**
 * Generate a valid test signature for webhook payload
 */
async function generateTestSignature(payload: string, secret: string): Promise<string> {
  const encoder = new TextEncoder();
  const keyData = encoder.encode(secret);
  const messageData = encoder.encode(payload);

  // Import secret as HMAC key
  const key = await crypto.subtle.importKey(
    'raw',
    keyData,
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign']
  );

  // Generate signature
  const signatureBuffer = await crypto.subtle.sign('HMAC', key, messageData);
  const signatureArray = new Uint8Array(signatureBuffer);
  
  // Convert to hex string and add sha256= prefix
  const hash = Array.from(signatureArray)
    .map(b => b.toString(16).padStart(2, '0'))
    .join('');

  return `sha256=${hash}`;
}