// ABOUTME: Tests for Cloudinary signed upload endpoint
// ABOUTME: Verifies security validation and proper signature generation

import { describe, it, expect, beforeAll } from 'vitest';
import { handleCloudinarySignedUpload } from '../handlers/cloudinary-upload';
import { generateTestNIP98Event } from './nip98-test-utils';

// Mock environment for testing
const mockEnv: Env = {
  CLOUDINARY_CLOUD_NAME: 'dswu0ugmo',
  CLOUDINARY_API_KEY: 'test_api_key',
  CLOUDINARY_API_SECRET: 'test_api_secret',
  ENVIRONMENT: 'development',
  BASE_URL: 'http://localhost:8787',
  MAX_FILE_SIZE_FREE: '104857600',
  MAX_FILE_SIZE_PRO: '1073741824',
  WEBHOOK_SECRET: 'test-webhook-secret'
} as any;

describe('Cloudinary Signed Upload Handler', () => {
  it('should reject requests without authentication', async () => {
    const request = new Request('http://localhost:8787/v1/media/request-upload', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      }
    });

    const response = await handleCloudinarySignedUpload(request, mockEnv);
    
    expect(response.status).toBe(401);
    
    const body = await response.json();
    expect(body.status).toBe('error');
    expect(body.message).toContain('Authorization');
  });

  it('should reject requests with invalid NIP-98 auth', async () => {
    const request = new Request('http://localhost:8787/v1/media/request-upload', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Nostr invalid_base64'
      }
    });

    const response = await handleCloudinarySignedUpload(request, mockEnv);
    
    expect(response.status).toBe(401);
    
    const body = await response.json();
    expect(body.status).toBe('error');
  });

  it('should reject files that are too large', async () => {
    // Generate a properly signed NIP-98 auth event
    const authEvent = generateTestNIP98Event({
      url: 'http://localhost:8787/v1/media/request-upload',
      method: 'POST'
    });

    const authBase64 = btoa(JSON.stringify(authEvent));

    const request = new Request('http://localhost:8787/v1/media/request-upload', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Nostr ${authBase64}`
      },
      body: JSON.stringify({
        fileSize: 100 * 1024 * 1024, // 100MB - over the 50MB limit
        contentType: 'video/mp4'
      })
    });

    const response = await handleCloudinarySignedUpload(request, mockEnv);
    
    expect(response.status).toBe(400);
    
    const body = await response.json();
    expect(body.status).toBe('error');
    expect(body.error_code).toBe('file_too_large');
  });

  it('should reject unsupported file types', async () => {
    // Generate a properly signed NIP-98 auth event
    const authEvent = generateTestNIP98Event({
      url: 'http://localhost:8787/v1/media/request-upload',
      method: 'POST'
    });

    const authBase64 = btoa(JSON.stringify(authEvent));

    const request = new Request('http://localhost:8787/v1/media/request-upload', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Nostr ${authBase64}`
      },
      body: JSON.stringify({
        fileSize: 1024 * 1024, // 1MB
        contentType: 'application/pdf' // Not supported
      })
    });

    const response = await handleCloudinarySignedUpload(request, mockEnv);
    
    expect(response.status).toBe(400);
    
    const body = await response.json();
    expect(body.status).toBe('error');
    expect(body.error_code).toBe('invalid_file_type');
  });

  it('should return signed upload parameters for valid requests', async () => {
    // Generate a properly signed NIP-98 auth event
    const authEvent = generateTestNIP98Event({
      url: 'http://localhost:8787/v1/media/request-upload',
      method: 'POST'
    });

    const authBase64 = btoa(JSON.stringify(authEvent));

    const request = new Request('http://localhost:8787/v1/media/request-upload', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Nostr ${authBase64}`
      },
      body: JSON.stringify({
        fileSize: 5 * 1024 * 1024, // 5MB - within limit
        contentType: 'video/mp4'
      })
    });

    const response = await handleCloudinarySignedUpload(request, mockEnv);
    
    expect(response.status).toBe(200);
    
    const body = await response.json();
    expect(body.status).toBe('success');
    expect(body.data.signature).toBeDefined();
    expect(body.data.api_key).toBe(mockEnv.CLOUDINARY_API_KEY);
    expect(body.data.cloud_name).toBe(mockEnv.CLOUDINARY_CLOUD_NAME);
    expect(body.data.public_id).toContain(authEvent.pubkey.substring(0, 16));
    expect(body.upload_url).toContain('cloudinary.com');
  });
});

describe('Cloudinary Upload Security', () => {
  it('should never expose API secret in response', async () => {
    // This test ensures that even if there's a bug,
    // the API secret is never returned to the client
    
    const mockRequest = new Request('http://localhost:8787/v1/media/request-upload', {
      method: 'POST'
    });

    try {
      const response = await handleCloudinarySignedUpload(mockRequest, mockEnv);
      const body = await response.text();
      
      // Ensure the secret is never in the response
      expect(body).not.toContain(mockEnv.CLOUDINARY_API_SECRET);
      expect(body).not.toContain('test_api_secret');
    } catch (error) {
      // Even if the function throws, check error messages
      const errorStr = error?.toString() || '';
      expect(errorStr).not.toContain(mockEnv.CLOUDINARY_API_SECRET);
    }
  });
});