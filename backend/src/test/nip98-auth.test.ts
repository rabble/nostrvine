// ABOUTME: Tests for NIP-98 HTTP authentication implementation
// ABOUTME: Validates signature verification and request authentication security

import { describe, it, expect, beforeEach } from 'vitest';
import { validateNIP98Auth, createAuthErrorResponse, NIP98AuthResult } from '../utils/nip98-auth';
import { NIP96ErrorCode } from '../types/nip96';
import { generateTestNIP98Event, generateTestEventWithInvalidSignature } from './nip98-test-utils';

const testPubkey = 'a'.repeat(64); // 64-character hex string
const testSignature = 'b'.repeat(128); // 128-character hex string

describe('NIP-98 Authentication', () => {
  let mockRequest: Request;
  const baseUrl = 'https://api.nostrvine.com/v1/media/request-upload';
  
  beforeEach(() => {
    mockRequest = new Request(baseUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      }
    });
  });

  describe('Request Structure Validation', () => {
    it('should fail when no Authorization header is present', async () => {
      const result = await validateNIP98Auth(mockRequest);
      
      expect(result.valid).toBe(false);
      expect(result.error).toContain('Missing Authorization header');
      expect(result.errorCode).toBe(NIP96ErrorCode.AUTHENTICATION_REQUIRED);
    });

    it('should fail with invalid Authorization header format', async () => {
      const requestWithBadAuth = new Request(baseUrl, {
        method: 'POST',
        headers: {
          'Authorization': 'Bearer invalid-token'
        }
      });

      const result = await validateNIP98Auth(requestWithBadAuth);
      
      expect(result.valid).toBe(false);
      expect(result.error).toContain('Invalid Authorization header format');
      expect(result.errorCode).toBe(NIP96ErrorCode.AUTHENTICATION_REQUIRED);
    });

    it('should fail with invalid base64 in Authorization header', async () => {
      const requestWithBadBase64 = new Request(baseUrl, {
        method: 'POST',
        headers: {
          'Authorization': 'Nostr invalid-base64!'
        }
      });

      const result = await validateNIP98Auth(requestWithBadBase64);
      
      expect(result.valid).toBe(false);
      expect(result.error).toContain('Invalid base64 encoding');
      expect(result.errorCode).toBe(NIP96ErrorCode.AUTHENTICATION_REQUIRED);
    });
  });

  describe('Event Structure Validation', () => {
    it('should fail with missing required fields', async () => {
      const incompleteEvent = {
        id: 'a'.repeat(64),
        pubkey: testPubkey,
        // missing other required fields
      };
      
      const eventBase64 = btoa(JSON.stringify(incompleteEvent));
      const requestWithIncompleteEvent = new Request(baseUrl, {
        method: 'POST',
        headers: {
          'Authorization': `Nostr ${eventBase64}`
        }
      });

      const result = await validateNIP98Auth(requestWithIncompleteEvent);
      
      expect(result.valid).toBe(false);
      expect(result.error).toContain('Missing required field');
      expect(result.errorCode).toBe(NIP96ErrorCode.AUTHENTICATION_REQUIRED);
    });

    it('should fail with invalid event kind', async () => {
      const eventWithWrongKind = createValidNIP98Event({
        kind: 1, // Should be 27235
        url: baseUrl,
        method: 'POST'
      });
      
      const eventBase64 = btoa(JSON.stringify(eventWithWrongKind));
      const requestWithWrongKind = new Request(baseUrl, {
        method: 'POST',
        headers: {
          'Authorization': `Nostr ${eventBase64}`
        }
      });

      const result = await validateNIP98Auth(requestWithWrongKind);
      
      expect(result.valid).toBe(false);
      expect(result.error).toContain('Invalid event kind');
      expect(result.errorCode).toBe(NIP96ErrorCode.AUTHENTICATION_REQUIRED);
    });
  });

  describe('Timestamp Validation', () => {
    it('should fail with expired timestamp', async () => {
      const expiredEvent = createValidNIP98Event({
        kind: 27235,
        url: baseUrl,
        method: 'POST',
        created_at: Math.floor(Date.now() / 1000) - 120 // 2 minutes ago
      });
      
      const eventBase64 = btoa(JSON.stringify(expiredEvent));
      const requestWithExpiredEvent = new Request(baseUrl, {
        method: 'POST',
        headers: {
          'Authorization': `Nostr ${eventBase64}`
        }
      });

      const result = await validateNIP98Auth(requestWithExpiredEvent, 60000); // 60 second max age
      
      expect(result.valid).toBe(false);
      expect(result.error).toContain('Event too old');
      expect(result.errorCode).toBe(NIP96ErrorCode.AUTHENTICATION_REQUIRED);
    });

    it('should fail with future timestamp', async () => {
      const futureEvent = createValidNIP98Event({
        kind: 27235,
        url: baseUrl,
        method: 'POST',
        created_at: Math.floor(Date.now() / 1000) + 600 // 10 minutes in future
      });
      
      const eventBase64 = btoa(JSON.stringify(futureEvent));
      const requestWithFutureEvent = new Request(baseUrl, {
        method: 'POST',
        headers: {
          'Authorization': `Nostr ${eventBase64}`
        }
      });

      const result = await validateNIP98Auth(requestWithFutureEvent);
      
      expect(result.valid).toBe(false);
      expect(result.error).toContain('too far in the future');
      expect(result.errorCode).toBe(NIP96ErrorCode.AUTHENTICATION_REQUIRED);
    });
  });

  describe('Request Validation', () => {
    it('should fail with method mismatch', async () => {
      const eventWithWrongMethod = createValidNIP98Event({
        kind: 27235,
        url: baseUrl,
        method: 'GET' // Request is POST
      });
      
      const eventBase64 = btoa(JSON.stringify(eventWithWrongMethod));
      const requestWithWrongMethod = new Request(baseUrl, {
        method: 'POST',
        headers: {
          'Authorization': `Nostr ${eventBase64}`
        }
      });

      const result = await validateNIP98Auth(requestWithWrongMethod);
      
      expect(result.valid).toBe(false);
      expect(result.error).toContain('Method mismatch');
      expect(result.errorCode).toBe(NIP96ErrorCode.AUTHENTICATION_REQUIRED);
    });

    it('should fail with URL mismatch', async () => {
      const eventWithWrongUrl = createValidNIP98Event({
        kind: 27235,
        url: 'https://different.com/api/upload',
        method: 'POST'
      });
      
      const eventBase64 = btoa(JSON.stringify(eventWithWrongUrl));
      const requestWithWrongUrl = new Request(baseUrl, {
        method: 'POST',
        headers: {
          'Authorization': `Nostr ${eventBase64}`
        }
      });

      const result = await validateNIP98Auth(requestWithWrongUrl);
      
      expect(result.valid).toBe(false);
      expect(result.error).toContain('URL mismatch');
      expect(result.errorCode).toBe(NIP96ErrorCode.AUTHENTICATION_REQUIRED);
    });
  });

  describe('Signature Validation', () => {
    it('should fail with invalid signature (CRITICAL TEST)', async () => {
      // Generate a properly formed event but with invalid signature
      const eventWithInvalidSig = generateTestEventWithInvalidSignature({
        url: baseUrl,
        method: 'POST'
      });
      
      const eventBase64 = btoa(JSON.stringify(eventWithInvalidSig));
      const requestWithInvalidSig = new Request(baseUrl, {
        method: 'POST',
        headers: {
          'Authorization': `Nostr ${eventBase64}`
        }
      });

      const result = await validateNIP98Auth(requestWithInvalidSig);
      
      // CRITICAL: This should fail - if it passes, signature verification is broken
      expect(result.valid).toBe(false);
      expect(result.error).toContain('Invalid event signature');
      expect(result.errorCode).toBe(NIP96ErrorCode.AUTHENTICATION_REQUIRED);
    });

    it('should pass with valid signature from real Nostr event', async () => {
      // Generate a properly formed and signed event
      const validEvent = generateTestNIP98Event({
        url: baseUrl,
        method: 'POST'
      });
      
      const eventBase64 = btoa(JSON.stringify(validEvent));
      const requestWithValidSig = new Request(baseUrl, {
        method: 'POST',
        headers: {
          'Authorization': `Nostr ${eventBase64}`
        }
      });

      const result = await validateNIP98Auth(requestWithValidSig);
      
      expect(result.valid).toBe(true);
      expect(result.pubkey).toBe(validEvent.pubkey);
    });
  });

  describe('Error Response Creation', () => {
    it('should create proper error response', () => {
      const errorResponse = createAuthErrorResponse(
        'Test error message',
        NIP96ErrorCode.AUTHENTICATION_REQUIRED
      );

      expect(errorResponse.status).toBe(401);
      expect(errorResponse.headers.get('Content-Type')).toBe('application/json');
      expect(errorResponse.headers.get('WWW-Authenticate')).toBe('Nostr');
      expect(errorResponse.headers.get('Access-Control-Allow-Origin')).toBe('*');
    });
  });
});

/**
 * Helper function to create valid NIP-98 event structure for testing
 */
function createValidNIP98Event(options: {
  kind: number;
  url: string;
  method: string;
  created_at?: number;
  sig?: string;
  pubkey?: string;
}) {
  const now = Math.floor(Date.now() / 1000);
  const event = {
    id: 'a'.repeat(64), // Will be calculated in real implementation
    pubkey: options.pubkey || testPubkey,
    created_at: options.created_at || now,
    kind: options.kind,
    tags: [
      ['u', options.url],
      ['method', options.method]
    ],
    content: '',
    sig: options.sig || testSignature
  };
  
  return event;
}